import { SignedDataVerifier, Environment } from 'npm:@apple/app-store-server-library@3.1.0'
import { Buffer } from 'node:buffer'
import { X509Certificate } from 'node:crypto'
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
