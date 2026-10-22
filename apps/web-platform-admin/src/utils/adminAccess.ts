export class StaleAuthorizationError extends Error {}

// Share only an in-flight read. A completed read is never an authorization cache.
// An old identity's response cannot restore permissions after logout or a new login.
export function createAuthorizationBootstrap<T>(load: () => Promise<T>, apply: (value: T | null) => void) {
  let epoch = 0
  let pending: Promise<T> | null = null
  return {
    invalidate() { epoch++; pending = null; apply(null) },
    ensure(): Promise<T> {
      if (pending) return pending
      const captured = epoch
      const request = load().then(value => {
        if (captured !== epoch) throw new StaleAuthorizationError('Authorization belongs to an older session')
        apply(value)
        return value
      }).finally(() => { if (pending === request) pending = null })
      pending = request
      return request
    }
  }
}
