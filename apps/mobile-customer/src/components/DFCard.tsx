// 卡片组件：深色背景 + 金色边框 + 12px 圆角
import React from 'react';
import { View, StyleSheet, type ViewProps } from 'react-native';
import { colors, radius, spacing } from '../theme/tokens';

interface DFCardProps extends ViewProps {
  children: React.ReactNode;
  bordered?: boolean;
  padding?: number;
}

export const DFCard = ({
  children,
  bordered = true,
  padding = spacing.md,
  style,
  ...rest
}: DFCardProps) => (
  <View style={[styles.card, bordered && styles.bordered, { padding }, style]} {...rest}>
    {children}
  </View>
);

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.bg.secondary, // #2A1E1A
    borderRadius: radius.lg, // 12px
  },
  bordered: {
    borderWidth: 1,
    borderColor: colors.border.default, // 金色半透明边框
  },
});
