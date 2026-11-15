import { type KeyObject } from 'node:crypto'

// Hosted Deno and OpenSSL use different names for the same named curves.
// Normalize only known aliases; jsonwebtoken's strict algorithm/key checks stay on.
export function normalizeAppleKey<T extends KeyObject>(key: T): T {
  const details = key.asymmetricKeyDetails
  const aliases: Record<string, string> = {
    'P-256': 'prime256v1', secp256r1: 'prime256v1',
    'P-384': 'secp384r1', 'P-521': 'secp521r1',
  }
  // Some Edge versions omit curve details entirely; JWK derives the curve from
  // the parsed key material rather than assuming a curve from the JWT header.
  let materialCurve: string | undefined
  if (key.asymmetricKeyType === 'ec') {
    materialCurve = key.export({ format: 'jwk' }).crv
  }
  const canonical = aliases[materialCurve ?? ''] ?? aliases[details?.namedCurve ?? '']
  if (key.asymmetricKeyType === 'ec' && canonical) {
    Object.defineProperty(key, 'asymmetricKeyDetails', { value: { ...details, namedCurve: canonical } })
  }
  console.info('apple_key_curve', JSON.stringify({ kind: key.type, algorithm: key.asymmetricKeyType,
    materialCurve, normalizedCurve: key.asymmetricKeyDetails?.namedCurve }))
  return key
}
