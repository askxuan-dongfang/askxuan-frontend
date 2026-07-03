import type { Config } from 'tailwindcss'
// 引入问玄东方 Design Tokens（与 C 端 App 保持一致的品牌色/字体/圆角）
// 来源：monorepo 根目录 packages/design-tokens/dist/web/tailwind-tokens.js
import tokens from '../../packages/design-tokens/dist/web/tailwind-tokens.js'

const config: Config = {
  // Element Plus 组件已接管大部分样式，Tailwind 仅提供原子化工具类
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      ...tokens,
      // 管理台浅色背景补充色板
      colors: {
        ...tokens.colors,
        ink: {
          DEFAULT: '#2A1E1A',
          medium: '#6A5A4A',
          light: '#9A8A7A'
        },
        canvas: {
          DEFAULT: '#F5F0EB',
          card: '#FFFFFF',
          subtle: '#FAFAF8'
        },
        line: '#E8E0D8'
      }
    }
  },
  corePlugins: {
    // 避免与 Element Plus 的 base reset 冲突
    preflight: false
  },
  plugins: []
}

export default config
