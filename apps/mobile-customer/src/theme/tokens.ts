// 设计令牌 - 从 packages/design-tokens/tokens.json 同步派生
// 严格使用，所有颜色统一从此文件引用

export const colors = {
  // 背景层级
  bg: {
    primary: '#1C1210', // 深檀木（主背景）
    secondary: '#2A1E1A', // 卡片背景
    tertiary: '#3A2C25', // 三级背景
    elevated: '#44342C', // 抬升背景
  },
  // 朱砂红（品牌主色 / 主 CTA）
  brand: {
    default: '#C45A3C',
    light: '#D4735A',
    dark: '#A64830',
  },
  // 琉璃金（强调 / 边框 / 图标）
  accent: {
    default: '#C8A96E',
    light: '#D4BC8A',
    dark: '#A88A50',
  },
  // 朱砂（备用）
  cinnabar: {
    default: '#B5453A',
    light: '#CC5A4F',
  },
  // 文字层级
  text: {
    primary: '#F0E6DA',
    secondary: '#C5B097',
    tertiary: '#8A7A6A',
  },
  // 边框
  border: {
    default: 'rgba(200, 169, 110, 0.15)',
    strong: 'rgba(200, 169, 110, 0.3)',
    divider: 'rgba(200, 169, 110, 0.08)',
  },
  // 状态色
  state: {
    success: '#5B8C5A',
    warning: '#D4A843',
    error: '#C45A3C',
  },
} as const;

export const radius = {
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
} as const;

export const spacing = {
  navTop: 44,
  navBottom: 60,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
} as const;

// 字体族：标题 serif，正文 sans
export const fontFamilies = {
  serif: 'Noto Serif SC',
  sans: 'Noto Sans SC',
} as const;

// 便捷别名（与单层 token 风格兼容）
export const c = colors;
