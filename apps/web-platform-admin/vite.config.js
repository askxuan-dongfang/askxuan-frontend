import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath, URL } from 'node:url';
// 问玄东方 P05 平台总管理台 - Vite 配置
export default defineConfig(function (_a) {
    var mode = _a.mode;
    return ({
        base: process.env.VITE_PUBLIC_BASE || (mode === 'production' ? '/admin/' : '/'),
        plugins: [vue()],
        resolve: {
            alias: {
                '@': fileURLToPath(new URL('./src', import.meta.url)),
                '@askxuan/domain-status': fileURLToPath(new URL('../../packages/domain-status/src/index.ts', import.meta.url))
            }
        },
        server: {
            port: 5210,
            proxy: {
                '/api': {
                    target: process.env.VITE_DEV_PROXY_TARGET || 'http://localhost:8080',
                    changeOrigin: true
                }
            }
        },
        build: {
            outDir: 'dist',
            sourcemap: false,
            chunkSizeWarningLimit: 1500
        }
    });
});
