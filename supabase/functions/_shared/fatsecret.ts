// FatSecret REST API via OAuth 1.0a (two-legged, no user token).
// Secrets: FATSECRET_CONSUMER_KEY, FATSECRET_CONSUMER_SECRET
//
// OAuth 1.0a signs every request with HMAC-SHA1 — no IP whitelisting needed.

const BASE_URL = 'https://platform.fatsecret.com/rest/server.api'

function pct(s: string): string {
  return encodeURIComponent(s)
    .replace(/!/g, '%21').replace(/'/g, '%27')
    .replace(/\(/g, '%28').replace(/\)/g, '%29').replace(/\*/g, '%2A')
}

export async function fatSecretGet(
  params: Record<string, string>
): Promise<Record<string, unknown>> {
  const consumerKey    = Deno.env.get('FATSECRET_CONSUMER_KEY')!
  const consumerSecret = Deno.env.get('FATSECRET_CONSUMER_SECRET')!

  const oauthParams: Record<string, string> = {
    oauth_consumer_key:     consumerKey,
    oauth_nonce:            crypto.randomUUID().replace(/-/g, ''),
    oauth_signature_method: 'HMAC-SHA1',
    oauth_timestamp:        Math.floor(Date.now() / 1000).toString(),
    oauth_version:          '1.0',
  }

  // All params included in signature: request params + OAuth params + format
  const allParams: Record<string, string> = { ...params, ...oauthParams, format: 'json' }

  const paramString = Object.keys(allParams)
    .sort()
    .map(k => `${pct(k)}=${pct(allParams[k])}`)
    .join('&')

  const baseString = `GET&${pct(BASE_URL)}&${pct(paramString)}`
  const signingKey = `${pct(consumerSecret)}&`   // empty token secret for 2-legged OAuth

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(signingKey),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign']
  )
  const sigBytes = await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(baseString))
  oauthParams.oauth_signature = btoa(String.fromCharCode(...new Uint8Array(sigBytes)))

  const authHeader = 'OAuth ' + Object.entries(oauthParams)
    .map(([k, v]) => `${pct(k)}="${pct(v)}"`)
    .join(', ')

  // Request URL carries the method params (not OAuth params — those are in the header)
  const url = new URL(BASE_URL)
  Object.entries({ ...params, format: 'json' }).forEach(([k, v]) => url.searchParams.set(k, v))

  const res = await fetch(url.toString(), { headers: { Authorization: authHeader } })
  if (!res.ok) throw new Error(`FatSecret ${res.status}: ${await res.text()}`)
  return res.json()
}

// FatSecret returns a bare object instead of a 1-element array when there's
// exactly one result — a quirk inherited from their XML API.
export function asArray<T>(value: T | T[] | undefined): T[] {
  if (!value) return []
  return Array.isArray(value) ? value : [value]
}
