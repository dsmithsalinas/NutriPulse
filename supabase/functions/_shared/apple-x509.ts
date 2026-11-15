import { X509Certificate, type KeyObject } from 'node:crypto'
import { Buffer } from 'node:buffer'
import { X509, KEYUTIL } from 'npm:jsrsasign@11.1.0'

// Supabase's hosted Node compatibility omits raw/toString/verify/infoAccess.
// Retain the original DER and use the same pinned X509 parser Apple's library
// already uses for extensions/OCSP. Native issuer, subject, CA, validity and
// public-key parsing remain in use. Never replace verification with a boolean.
export class EdgeX509Certificate {
  private readonly native: X509Certificate
  private readonly der: Buffer
  private readonly certificate: InstanceType<typeof X509>
  constructor(der: Buffer) {
    this.native = new X509Certificate(der)
    this.der = Buffer.from(der)
    this.certificate = new X509()
    this.certificate.readCertHex(this.der.toString('hex'))
  }
  get issuer(): string { return this.native.issuer }
  get subject(): string { return this.native.subject }
  get ca(): boolean { return this.native.ca }
  get validFrom(): string { return this.native.validFrom }
  get validTo(): string { return this.native.validTo }
  get publicKey(): KeyObject { return this.native.publicKey }
  get raw(): Buffer { return Buffer.from(this.der) }
  toString(): string {
    return `-----BEGIN CERTIFICATE-----\n${this.der.toString('base64').match(/.{1,64}/g)!.join('\n')}\n-----END CERTIFICATE-----\n`
  }
  verify(publicKey: KeyObject): boolean {
    try {
      return this.certificate.verifySignature(KEYUTIL.getKey(publicKey.export({ type: 'spki', format: 'pem' }).toString()))
    } catch { return false } // A wrong key/algorithm is a failed signature, never a grant.
  }
  get infoAccess(): string | undefined {
    const info = this.certificate.getExtAIAInfo()
    return info?.ocsp?.map((uri: string) => `OCSP - URI:${uri}`).join('\n') || undefined
  }
}
