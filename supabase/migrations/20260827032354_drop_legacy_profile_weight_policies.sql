-- The initial schema used colon-delimited policy names. Remove those legacy
-- policies after the explicit per-operation replacements are in place.
drop policy if exists "profiles: owner full access" on public.profiles;
drop policy if exists "weight_logs: owner full access" on public.weight_logs;
