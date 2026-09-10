// 主题 Provider：注入 colors 主题上下文
import React, { createContext, useContext, type ReactNode } from 'react';
import { colors } from './tokens';
import { useFonts } from 'expo-font';
import { ActivityIndicator, View } from 'react-native';

interface Theme {
  colors: typeof colors;
}

const ThemeContext = createContext<Theme>({ colors });

// 主题 Provider，包裹根布局
export const ThemeProvider = ({ children }: { children: ReactNode }) => {
  const [loaded, error] = useFonts({ 'AskXuanSerif-Semibold': require('../../../../packages/design-tokens/fonts/AskXuanSerif-Semibold.ttf') });
  if (!loaded && !error) return <View style={{ flex: 1, justifyContent: 'center', backgroundColor: colors.bg.primary }}><ActivityIndicator color={colors.accent.default} /></View>;
  return <ThemeContext.Provider value={{ colors }}>{children}</ThemeContext.Provider>;
};

// 主题 Hook
export const useTheme = () => useContext(ThemeContext);
