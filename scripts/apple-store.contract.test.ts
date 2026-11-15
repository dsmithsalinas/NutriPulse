import { Environment } from 'npm:@apple/app-store-server-library@3.1.0'
import { SignedDataVerifier } from '../supabase/functions/_shared/apple-signed-data-verifier.ts'
import { EdgeX509Certificate } from '../supabase/functions/_shared/apple-x509.ts'
import { Buffer } from 'node:buffer'
import { X509Certificate, createPublicKey } from 'node:crypto'
import { normalizeAppleKey } from '../supabase/functions/_shared/apple-crypto.ts'
import { APPLE_STORE_ROOTS } from '../supabase/functions/_shared/apple-store-roots.ts'
const roots = APPLE_STORE_ROOTS.map(root => Buffer.from(root, 'base64'))
Deno.test('pinned Apple roots are valid self-signed CA certificates', () => {
  for (const root of roots) {
    const certificate = new X509Certificate(root)
    if (!certificate.ca || !certificate.subject.includes('Apple Root CA') || !certificate.verify(certificate.publicKey)) throw Error('Invalid trust anchor')
  }
})
Deno.test('official verifier rejects forged or unsigned transactions and notifications', async () => {
  const verifier = new SignedDataVerifier(roots, true, Environment.PRODUCTION, 'com.dustin.nutripulse.app', 6789967509)
  for (const run of [() => verifier.verifyAndDecodeTransaction('eyJhbGciOiJub25lIn0.eyJwcm9kdWN0SWQiOiJmYWtlIn0.'),
    () => verifier.verifyAndDecodeNotification('not-a-signed-notification')]) {
    let rejected = false
    try { await run() } catch { rejected = true }
    if (!rejected) throw Error('Forged purchase accepted')
  }
})

Deno.test('Edge certificate adapter preserves real verification and rejects the wrong issuer key', () => {
  const certificates = roots.map(root => new EdgeX509Certificate(root))
  for (const [i, certificate] of certificates.entries()) {
    if (!certificate.verify(certificate.publicKey)) throw Error('Self-signature rejected')
    if (certificate.verify(certificates[1-i].publicKey)) throw Error('Wrong issuer key accepted')
    const native = new X509Certificate(certificate.toString())
    if (native.fingerprint256 !== new X509Certificate(roots[i]).fingerprint256) throw Error('DER changed')
    const copy = certificate.raw; copy.fill(0)
    if (certificate.raw[0] === 0) throw Error('Mutable certificate bytes leaked')
  }
})

Deno.test('equivalent hosted EC curve names normalize without disabling algorithm checks', () => {
  const key = createPublicKey(new X509Certificate(roots[1]).publicKey.export({type:'spki',format:'pem'}))
  Object.defineProperty(key, 'asymmetricKeyDetails', { value: { namedCurve:'P-256' }, configurable:true })
  if (normalizeAppleKey(key).asymmetricKeyDetails?.namedCurve !== 'secp384r1') throw Error('Alias not normalized')
  const unknown = createPublicKey(new X509Certificate(roots[1]).publicKey.export({type:'spki',format:'pem'}))
  Object.defineProperty(unknown, 'asymmetricKeyDetails', { value: { namedCurve:'unknown' }, configurable:true })
  if (normalizeAppleKey(unknown).asymmetricKeyDetails?.namedCurve !== 'secp384r1') throw Error('Curve must derive from actual key material')
})
