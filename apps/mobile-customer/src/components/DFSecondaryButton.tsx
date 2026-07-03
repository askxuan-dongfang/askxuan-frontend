// 描边金色次按钮
import React from 'react';
import {
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  type ViewStyle,
} from 'react-native';
import { colors, radius } from '../theme/tokens';

interface DFSecondaryButtonProps {
  title: string;
  onPress?: () => void;
  loading?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
}

export const DFSecondaryButton = ({
  title,
  onPress,
  loading = false,
  disabled = false,
  style,
}: DFSecondaryButtonProps) => (
  <TouchableOpacity
    onPress={onPress}
    disabled={disabled || loading}
    activeOpacity={0.85}
    style={[styles.button, disabled && styles.disabled, style]}
  >
    {loading ? (
      <ActivityIndicator color={colors.accent.default} />
    ) : (
      <Text style={styles.text}>{title}</Text>
    )}
  </TouchableOpacity>
);

const styles = StyleSheet.create({
  button: {
    paddingVertical: 13,
    paddingHorizontal: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.accent.default, // 琉璃金描边
    backgroundColor: 'transparent',
  },
  disabled: {
    opacity: 0.5,
  },
  text: {
    color: colors.accent.default,
    fontSize: 16,
    fontWeight: '600',
  },
});
