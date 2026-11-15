"""Isolated Postgres 17 concurrency test. Uses an existing official Supabase image;
never connects to a hosted project or an existing local database."""
from pathlib import Path
import concurrent.futures
import subprocess
import time
import uuid

name = 'footing-membership-test-' + uuid.uuid4().hex[:10]
image = 'public.ecr.aws/supabase/postgres:17.11.0.004'

def sql(query, check=True):
    return subprocess.run(['docker', 'exec', '-i', name, 'psql', '-h', '/tmp', '-U', 'postgres',
                           '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At'],
                          input=query, text=True, capture_output=True, check=check)

try:
    subprocess.run(['docker', 'run', '--rm', '-d', '--name', name, '--user', 'postgres',
                    '--entrypoint', 'sh', image, '-c',
                    "initdb -D /tmp/membership-db --no-locale -A trust >/tmp/init.log && "
                    "exec postgres -D /tmp/membership-db -c unix_socket_directories=/tmp -c listen_addresses=''"],
                   capture_output=True, text=True, check=True)
    for _ in range(50):
        if sql('select 1', check=False).returncode == 0:
            break
        time.sleep(.2)
    else:
        raise RuntimeError('Isolated test database did not start')
    sql("""create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth;
      create table auth.users(id uuid primary key,email_confirmed_at timestamptz,phone_confirmed_at timestamptz);
      grant usage on schema public,auth to service_role;""")
    sql(Path(__file__).resolve().parents[1].joinpath('supabase/migrations/20261115021855_premium_membership.sql').read_text())
    owners = [str(uuid.uuid4()) for _ in range(60)]
    for owner in owners:
        sql(f"insert into auth.users values('{owner}',now(),null)")
    sql('update membership_campaign set enabled=true')
    def claim(owner):
        return sql(f"set role service_role; select claim_founding_membership('{owner}')", check=False).returncode == 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        claims = list(pool.map(claim, owners))
    assert sum(claims) == 50, sum(claims)
    assert sql('select claimed from membership_campaign').stdout.strip() == '50'
    assert sql('select count(*) from founding_memberships').stdout.strip() == '50'
    winner = owners[claims.index(True)]
    def reserve(_):
        return sql(f"set role service_role; select reserve_membership_ai('{winner}','pulse',2,100)").stdout.splitlines()[-1]
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        reservations = list(pool.map(reserve, range(24)))
    assert reservations.count('allowed') == 2, reservations
    assert reservations.count('membership_limit_reached') == 22, reservations
    print('Postgres 17: 60 concurrent claim attempts granted exactly 50 places; 24 quota attempts granted exactly 2 requests.')
finally:
    subprocess.run(['docker', 'rm', '-f', name], capture_output=True)
