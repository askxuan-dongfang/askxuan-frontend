// 胶囊标签：选中朱砂，默认灰色
import React from 'react';
import { Text, StyleSheet, TouchableOpacity } from 'react-native';
import { colors, radius, spacing } from '../theme/tokens';

interface DFTagPillProps {
  label: string;
  active?: boolean;
  onPress?: () => void;
  small?: boolean;
}

export const DFTagPill = ({
  label,
  active = false,
  onPress,
  small = false,
}: DFTagPillProps) => (
  <TouchableOpacity
    onPress={onPress}
    activeOpacity={0.7}
    style={[styles.pill, small && styles.pillSmall, active && styles.pillActive]}
  >
    <Text style={[styles.text, small && styles.textSmall, active && styles.textActive]}>
      {label}
    </Text>
  </TouchableOpacity>
);

const styles = StyleSheet.create({
  pill: {
    paddingHorizontal: 14,
    paddingVertical: 5,
    borderRadius: 9999,
    backgroundColor: colors.bg.tertiary,
  },
  pillSmall: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
  },
  pillActive: {
    backgroundColor: colors.brand.default, // 朱砂红
  },
  text: {
    fontSize: 12,
    color: colors.text.tertiary,
  },
  textSmall: {
    fontSize: 10,
  },
  textActive: {
    color: colors.text.primary,
  },
});
