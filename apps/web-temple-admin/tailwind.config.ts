import type { Config } from 'tailwindcss'

// 问玄东方 Design Tokens（内联，避免构建期依赖 monorepo packages 路径）
const brandTokens = {
  brand: {
    DEFAULT: 'var(--admin-primary)',
    light: 'var(--admin-primary-hover)',
    dark: 'var(--color-brand-dark)'
  },
  accent: {
    DEFAULT: 'var(--admin-accent)',
    light: 'var(--color-accent-light)',
    dark: 'var(--color-accent-dark)'
  },
  cinnabar: {
    DEFAULT: 'var(--admin-danger)',
    light: 'var(--admin-danger)'
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
          DEFAULT: 'var(--admin-text)',
          medium: 'var(--admin-text-secondary)',
          light: 'var(--admin-text-tertiary)'
        },
        canvas: {
          DEFAULT: 'var(--admin-bg)',
          card: 'var(--admin-surface)',
          subtle: 'var(--admin-surface-muted)'
        },
        line: 'var(--admin-border)'
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
