// Shared FatSecret OAuth 2.0 token helper.
// Credentials come from Supabase secrets:
//   supabase secrets set FATSECRET_CLIENT_ID=<id> FATSECRET_CLIENT_SECRET=<secret>

export async function getFatSecretToken(): Promise<string> {
  const clientId = Deno.env.get('FATSECRET_CLIENT_ID')!
  const clientSecret = Deno.env.get('FATSECRET_CLIENT_SECRET')!
  const credentials = btoa(`${clientId}:${clientSecret}`)

  const res = await fetch('https://oauth.fatsecret.com/connect/token', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials&scope=basic',
  })

  if (!res.ok) {
    throw new Error(`FatSecret token error: ${res.status}`)
  }

  const { access_token } = await res.json()
  return access_token as string
}

// FatSecret returns a single object instead of a 1-element array when there's
// exactly one result — a quirk inherited from their XML API.
export function asArray<T>(value: T | T[] | undefined): T[] {
  if (!value) return []
  return Array.isArray(value) ? value : [value]
}
