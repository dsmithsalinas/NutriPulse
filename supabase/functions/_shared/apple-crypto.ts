import { type KeyObject } from 'node:crypto'
import { KEYUTIL } from 'npm:jsrsasign@11.1.0'

// Hosted Deno omits/misnames EC curve details and cannot export JWK on all
// versions. Read the curve from the existing PEM key, then supply the equivalent
// OpenSSL name. jsonwebtoken's strict algorithm/key validation stays enabled.
export function normalizeAppleKey<T extends KeyObject>(key: T, pem?: string): T {
  if (key.asymmetricKeyType !== 'ec') return key
  const material = pem ?? key.export({ type: key.type === 'private' ? 'pkcs8' : 'spki', format: 'pem' }).toString()
  const parsed = KEYUTIL.getKey(material) as { curveName?: string }
  const aliases: Record<string, string> = {
    'P-256': 'prime256v1', secp256r1: 'prime256v1', prime256v1: 'prime256v1',
    'P-384': 'secp384r1', secp384r1: 'secp384r1',
    'P-521': 'secp521r1', secp521r1: 'secp521r1',
  }
  const canonical = aliases[parsed.curveName ?? '']
  if (!canonical) throw Error('Unsupported Apple signing curve')
  Object.defineProperty(key, 'asymmetricKeyDetails', {
    value: { ...key.asymmetricKeyDetails, namedCurve: canonical },
  })
  return key
}
