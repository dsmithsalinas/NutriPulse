import { SignJWT, importPKCS8, createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'npm:jose@6.1.0'
import { AccountDeletionError, type AppleTokens } from './apple-account-deletion.ts'

const issuer = 'https://appleid.apple.com'
const appleKeys = createRemoteJWKSet(new URL(`${issuer}/auth/keys`))
export type AppleConfig = { clientId: string; teamId: string; keyId: string; privateKey: string }

export function appleConfig(env: (name: string) => string | undefined): AppleConfig {
  const config = { clientId: env('APPLE_CLIENT_ID') ?? '', teamId: env('APPLE_TEAM_ID') ?? '',
    keyId: env('APPLE_KEY_ID') ?? '', privateKey: (env('APPLE_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n') }
  if (Object.values(config).some(v => !v.trim())) throw unavailable()
  return config
}

// Generate a five-minute client secret on the server. The signing key and tokens are never
// returned to the device, persisted, logged, or sent anywhere except Apple.
export async function makeAppleClientSecret(config: AppleConfig) {
  const key = await importPKCS8(config.privateKey, 'ES256')
  return new SignJWT({}).setProtectedHeader({ alg: 'ES256', kid: config.keyId })
    .setIssuer(config.teamId).setSubject(config.clientId).setAudience(issuer)
    .setIssuedAt().setExpirationTime('5m').sign(key)
}

export async function verifyAppleIdentityToken(token: string, clientId: string, keys: JWTVerifyGetKey = appleKeys) {
  const { payload } = await jwtVerify(token, keys, {
    issuer, audience: clientId, algorithms: ['RS256'],
    requiredClaims: ['sub', 'exp', 'iat'], maxTokenAge: '10m',
  })
  if (typeof payload.sub !== 'string' || !payload.sub) throw unavailable()
  return payload.sub
}

export async function appleRevocationClient(config: AppleConfig) {
  let secret: string
  try { secret = await makeAppleClientSecret(config) } catch { throw unavailable() }
  const post = async (path: string, values: Record<string, string>) => {
    try {
      const response = await fetch(`${issuer}/auth/${path}`, {
        method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ client_id: config.clientId, client_secret: secret, ...values }),
        signal: AbortSignal.timeout(15000),
      })
      if (!response.ok) throw unavailable()
      return response
    } catch { throw unavailable() }
  }
  return {
    exchange: async (code: string): Promise<AppleTokens> => {
      const response = await post('token', { code, grant_type: 'authorization_code' })
      try {
        const result = await response.json()
        if (typeof result.id_token !== 'string' || typeof result.refresh_token !== 'string' || !result.refresh_token) throw unavailable()
        const subject = await verifyAppleIdentityToken(result.id_token, config.clientId)
        return { subject, refreshToken: result.refresh_token }
      } catch { throw unavailable() }
    },
    revoke: async (refreshToken: string) => {
      await post('revoke', { token: refreshToken, token_type_hint: 'refresh_token' })
    },
  }
}

function unavailable() {
  return new AccountDeletionError(503, 'apple_revocation_unavailable', 'Couldn’t complete Apple confirmation. Your Footing account has not been deleted. Please try again.')
}
