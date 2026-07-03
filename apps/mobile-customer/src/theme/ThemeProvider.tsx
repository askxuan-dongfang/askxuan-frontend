// 主题 Provider：注入 colors 主题上下文
import React, { createContext, useContext, type ReactNode } from 'react';
import { colors } from './tokens';

interface Theme {
  colors: typeof colors;
}

const ThemeContext = createContext<Theme>({ colors });

// 主题 Provider，包裹根布局
export const ThemeProvider = ({ children }: { children: ReactNode }) => {
  return <ThemeContext.Provider value={{ colors }}>{children}</ThemeContext.Provider>;
};

// 主题 Hook
export const useTheme = () => useContext(ThemeContext);
