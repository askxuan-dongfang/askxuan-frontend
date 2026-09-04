import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'node:path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => ({
  base: process.env.VITE_PUBLIC_BASE || (mode === 'production' ? '/temple/' : '/'),
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src'),
      '@askxuan/domain-status': path.resolve(__dirname, '../../packages/domain-status/src/index.ts')
    }
  },
  server: {
    port: 5174,
    proxy: {
      // 网关统一入口：/api → http://localhost:8080
      '/api': {
        target: process.env.VITE_DEV_PROXY_TARGET || 'http://localhost:8080',
        changeOrigin: true
      }
    }
  },
  build: {
    target: 'es2015',
    chunkSizeWarningLimit: 1500,
    rollupOptions: {
      output: {
        manualChunks: {
          vue: ['vue', 'vue-router', 'pinia'],
          element: ['element-plus', '@element-plus/icons-vue'],
          echarts: ['echarts']
        }
      }
    }
  }
}))
