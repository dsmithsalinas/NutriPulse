// Orchestration is dependency-injected so no test needs a real Apple account or deletion.
export class AccountDeletionError extends Error {
  status: number
  code: string
  constructor(status: number, code: string, message: string) { super(message); this.status = status; this.code = code }
}
export type AppleIdentity = { provider: string; identity_data?: { sub?: unknown } }
export type DeletionUser = { id: string; identities?: AppleIdentity[] }
export type AppleTokens = { subject: string; refreshToken: string }

export async function deleteAccountWithApple(
  user: DeletionUser, code: unknown,
  actions: {
    exchange: (code: string) => Promise<AppleTokens>
    revoke: (refreshToken: string) => Promise<void>
    deleteUser: (id: string) => Promise<void>
  },
  manualAppleRevocation = false,
) {
  if (!Array.isArray(user.identities)) throw new AccountDeletionError(503, 'identity_unavailable', 'Couldn’t verify sign-in methods. Please try again.')
  const apple = user.identities.filter(i => i.provider === 'apple')
  if (apple.length && manualAppleRevocation && code != null) {
    throw new AccountDeletionError(400, 'invalid_request', 'Choose automatic or manual Apple disconnection, not both.')
  }
  // Apple's documented fallback: deletion remains available when no Apple token/code can
  // be obtained. The authenticated user explicitly chooses to disconnect Apple manually.
  if (apple.length && !manualAppleRevocation) {
    if (typeof code !== 'string' || !code.trim() || code.length > 4096) {
      throw new AccountDeletionError(409, 'apple_confirmation_required', 'Confirm with Apple in the updated Footing app before deleting your account.')
    }
    const subjects = apple.map(i => i.identity_data?.sub).filter((s): s is string => typeof s === 'string' && s.length > 0)
    if (subjects.length !== apple.length) throw new AccountDeletionError(503, 'identity_unavailable', 'Couldn’t verify the linked Apple account. Please try again.')
    const tokens = await actions.exchange(code)
    if (!subjects.includes(tokens.subject)) {
      throw new AccountDeletionError(403, 'apple_account_mismatch', 'Confirm with the Apple account linked to this Footing account. Your account has not been deleted.')
    }
    // Never delete the Footing account if Apple exchange, validation, or revocation fails.
    await actions.revoke(tokens.refreshToken)
  }
  await actions.deleteUser(user.id)
  return { appleRevocationRequired: apple.length > 0 && manualAppleRevocation }
}
