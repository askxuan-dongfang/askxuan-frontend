# Errors

## [ERR-20260814-001] mobile-customer-build-script

**Logged**: 2026-08-14T00:48:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
The Expo fallback client has no `build` script.

### Error
`npm run build` returned `Missing script: "build"` in `apps/mobile-customer`.

### Context
The repository-wide client regression loop assumed every package used the Web build contract.

### Suggested Fix
Use `npm run lint` for the Expo TypeScript compile check and reserve `npm run build` for the Web and Mock packages.

### Metadata
- Reproducible: yes
- Related Files: apps/mobile-customer/package.json

---
