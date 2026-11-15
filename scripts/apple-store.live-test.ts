// Run with a private file containing Apple's TEST notification response:
// deno run --node-modules-dir=none --allow-read --allow-net scripts/apple-store.live-test.ts /secure/test.json
// Never commit signed notification files. No credentials or payloads are printed.
import { SignedDataVerifier } from '../supabase/functions/_shared/apple-signed-data-verifier.ts'
import { Environment } from 'npm:@apple/app-store-server-library@3.1.0'
import { Buffer } from 'node:buffer'
import { X509Certificate } from 'node:crypto'
import { APPLE_STORE_ROOTS } from '../supabase/functions/_shared/apple-store-roots.ts'
const file = Deno.args[0]
if (!file) throw Error('Provide a private Apple TEST notification JSON file')
const { signedPayload } = JSON.parse(await Deno.readTextFile(file))
const roots = APPLE_STORE_ROOTS.map(r => Buffer.from(r, 'base64'))
const make = (env = Environment.SANDBOX, bundle = 'com.dustin.nutripulse.app') =>
  new SignedDataVerifier(roots, true, env, bundle, 6789967509)
const descriptors = new Map<string, PropertyDescriptor | undefined>()
const originalFetch = globalThis.fetch
let keyPrototype = Object.getPrototypeOf(new X509Certificate(roots[1]).publicKey)
while (!Object.getOwnPropertyDescriptor(keyPrototype, 'asymmetricKeyDetails')) keyPrototype = Object.getPrototypeOf(keyPrototype)
const curveDescriptor = Object.getOwnPropertyDescriptor(keyPrototype, 'asymmetricKeyDetails')!
try {
  // Emulate hosted curve metadata as well as its missing certificate methods.
  Object.defineProperty(keyPrototype, 'asymmetricKeyDetails', {
    configurable:true, get() {
      const details = curveDescriptor.get!.call(this)
      const aliases: Record<string,string> = { prime256v1:'P-256',secp384r1:'P-384',secp521r1:'P-521' }
      return { ...details, namedCurve:aliases[details?.namedCurve] ?? details?.namedCurve }
    },
  })
  for (const name of ['raw', 'infoAccess', 'verify', 'toString']) {
    descriptors.set(name, Object.getOwnPropertyDescriptor(X509Certificate.prototype, name))
    const unavailable = () => { throw Error('Simulated hosted runtime missing certificate method') }
    Object.defineProperty(X509Certificate.prototype, name, {
      configurable: true, ...(name === 'verify' || name === 'toString' ? { value: unavailable } : { get: unavailable }),
    })
  }
  const notification = await make().verifyAndDecodeNotification(signedPayload)
  if (notification.notificationType !== 'TEST') throw Error('Only use an Apple TEST notification')
  const cases = [
    ['wrong app', make(Environment.SANDBOX, 'invalid.bundle'), signedPayload],
    ['wrong environment', make(Environment.PRODUCTION), signedPayload],
    ['tampered signature', make(), signedPayload.slice(0, -10) + 'AAAAAAAAAA'],
  ] as const
  for (const [name, verifier, payload] of cases) {
    let rejected = false
    try { await verifier.verifyAndDecodeNotification(payload) } catch { rejected = true }
    if (!rejected) throw Error(`Accepted ${name}`)
  }
  globalThis.fetch = async () => new Response('', { status: 503 })
  let blocked = false
  try { await make().verifyAndDecodeNotification(signedPayload) } catch { blocked = true }
  if (!blocked) throw Error('Online revocation failure must fail closed')
  console.log('Apple TEST verified; missing-runtime methods simulated; wrong app/environment, tampering and unavailable OCSP rejected.')
} finally {
  globalThis.fetch = originalFetch
  Object.defineProperty(keyPrototype, 'asymmetricKeyDetails', curveDescriptor)
  for (const [name, descriptor] of descriptors) {
    if (descriptor) Object.defineProperty(X509Certificate.prototype, name, descriptor)
    else Reflect.deleteProperty(X509Certificate.prototype, name)
  }
}
