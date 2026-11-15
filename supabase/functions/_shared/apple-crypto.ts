import { type KeyObject } from 'node:crypto'

// Hosted Deno and OpenSSL use different names for the same named curves.
// Normalize only known aliases; jsonwebtoken's strict algorithm/key checks stay on.
export function normalizeAppleKey<T extends KeyObject>(key: T): T {
  const details = key.asymmetricKeyDetails
  const aliases: Record<string, string> = {
    'P-256': 'prime256v1', secp256r1: 'prime256v1',
    'P-384': 'secp384r1', 'P-521': 'secp521r1',
  }
  const canonical = aliases[details?.namedCurve ?? '']
  if (key.asymmetricKeyType === 'ec' && canonical) {
    Object.defineProperty(key, 'asymmetricKeyDetails', { value: { ...details, namedCurve: canonical } })
  }
  return key
}
