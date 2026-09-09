import { defineConfig } from 'vite'
// Compatibility entry only. Business pages now live in web-platform-admin.
export default defineConfig(({ mode }) => ({
  base: process.env.VITE_PUBLIC_BASE || (mode === 'production' ? '/shop/' : '/'),
  server: { port: 5175 },
  build: { target: 'es2015' }
}))
