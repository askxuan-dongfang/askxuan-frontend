export function legacyShopTarget(path: string): string {
  const clean = path.replace(/^\/shop(?:\/|$)/, '/')
  if (clean === '/login') return '/login'
  return '/commerce' + (clean === '/' || !clean ? '/dashboard' : clean)
}
