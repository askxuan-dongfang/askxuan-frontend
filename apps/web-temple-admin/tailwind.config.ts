import type { Config } from 'tailwindcss'

// 问玄东方 Design Tokens（内联，避免构建期依赖 monorepo packages 路径）
const brandTokens = {
  brand: {
    DEFAULT: '#C45A3C',
    light: '#D4735A',
    dark: '#A64830'
  },
  accent: {
    DEFAULT: '#C8A96E',
    light: '#D4BC8A',
    dark: '#A88A50'
  },
  cinnabar: {
    DEFAULT: '#B5453A',
    light: '#CC5A4F'
  }
}

const config: Config = {
  // Element Plus 接管组件样式，Tailwind 仅提供原子化工具类
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ...brandTokens,
        // 管理台浅色画布
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
      },
      fontFamily: {
        serif: ['Noto Serif SC', 'STSong', 'SimSun', 'serif'],
        sans: ['Noto Sans SC', 'PingFang SC', 'Microsoft YaHei', 'sans-serif']
      },
      borderRadius: {
        sm: '4px',
        md: '8px',
        lg: '12px',
        xl: '16px'
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
