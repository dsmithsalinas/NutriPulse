import { SignJWT, createLocalJWKSet, exportJWK, exportPKCS8, generateKeyPair, jwtVerify } from 'npm:jose@6.1.0'
import { appleConfig, makeAppleClientSecret, verifyAppleIdentityToken, appleRevocationClient } from '../supabase/functions/_shared/apple-token-revocation.ts'

function assert(value: unknown, message = 'Assertion failed'): asserts value { if (!value) throw Error(message) }
async function rejects(work: () => Promise<unknown>) { try { await work() } catch { return }; throw Error('Expected rejection') }
const clientId = 'com.dustin.nutripulse.app'
const signing = await generateKeyPair('ES256', { extractable: true })
const config = { clientId, teamId: 'TEST_TEAM', keyId: 'TEST_KEY', privateKey: await exportPKCS8(signing.privateKey) }
const appleSigning = await generateKeyPair('RS256')
const keys = createLocalJWKSet({ keys: [{ ...await exportJWK(appleSigning.publicKey), kid: 'apple-test', alg: 'RS256' }] })
const token = (overrides: Record<string, unknown> = {}) => new SignJWT({ iss: 'https://appleid.apple.com', aud: clientId,
  sub: 'apple-owner', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300, ...overrides })
  .setProtectedHeader({ alg: 'RS256', kid: 'apple-test' }).sign(appleSigning.privateKey)

Deno.test('Apple client secret is ES256, correctly scoped and short-lived', async () => {
  const secret = await makeAppleClientSecret(config)
  const { payload, protectedHeader } = await jwtVerify(secret, signing.publicKey, { issuer: config.teamId, audience: 'https://appleid.apple.com', algorithms: ['ES256'] })
  assert(payload.sub === clientId); assert(protectedHeader.kid === config.keyId)
  assert(payload.exp! - payload.iat! === 300)
})
Deno.test('Apple token verifies signature, issuer, audience, expiry, age, and required subject', async () => {
  assert(await verifyAppleIdentityToken(await token(), clientId, keys) === 'apple-owner')
  for (const bad of [{ iss: 'https://attacker.invalid' }, { aud: 'another.app' }, { exp: 1 }, { iat: 1 }, { sub: '' }]) {
    await rejects(async () => verifyAppleIdentityToken(await token(bad), clientId, keys))
  }
  const otherKey = await generateKeyPair('RS256')
  const forged = await new SignJWT({ iss: 'https://appleid.apple.com', aud: clientId, sub: 'apple-owner' })
    .setProtectedHeader({ alg: 'RS256', kid: 'apple-test' }).setIssuedAt().setExpirationTime('5m').sign(otherKey.privateKey)
  await rejects(() => verifyAppleIdentityToken(forged, clientId, keys))
})
Deno.test('missing Apple signing configuration cannot proceed', () => {
  let rejected = false
  try { appleConfig(() => undefined) } catch { rejected = true }
  assert(rejected)
})
Deno.test('failed Apple token and revoke HTTP calls are sanitized and never expose credentials', async () => {
  const original = globalThis.fetch
  try {
    globalThis.fetch = async (_url, init) => {
      const body = new URLSearchParams(String(init?.body))
      assert(body.get('client_id') === clientId); assert(body.has('client_secret'))
      return new Response('private-provider-error-body', { status: 400 })
    }
    const client = await appleRevocationClient(config)
    for (const run of [() => client.exchange('private-code'), () => client.revoke('private-token')]) {
      try { await run(); throw Error('Expected failure') } catch (error) {
        const text = String(error)
        assert(text.includes('Your Footing account has not been deleted'))
        assert(!text.includes('private-')); assert(!text.includes(config.privateKey))
      }
    }
  } finally { globalThis.fetch = original }
})
