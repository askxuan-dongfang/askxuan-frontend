// 毛玻璃顶部导航栏：BlurView + 返回 + 标题 + 右侧插槽
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Platform } from 'react-native';
import { BlurView } from 'expo-blur';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { colors, spacing } from '../theme/tokens';

interface DFTopNavBarProps {
  title: string;
  showBack?: boolean;
  onBack?: () => void;
  right?: React.ReactNode;
}

export const DFTopNavBar = ({
  title,
  showBack = true,
  onBack,
  right,
}: DFTopNavBarProps) => {
  const insets = useSafeAreaInsets();

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else if (router.canGoBack()) {
      router.back();
    }
  };

  return (
    <View style={[styles.wrapper, { paddingTop: insets.top }]}>
      <BlurView intensity={80} tint="dark" style={styles.blur}>
        <View style={styles.content}>
          {showBack ? (
            <TouchableOpacity onPress={handleBack} style={styles.sideBtn} hitSlop={8}>
              <Ionicons name="chevron-back" size={24} color={colors.accent.default} />
            </TouchableOpacity>
          ) : (
            <View style={styles.sideBtn} />
          )}
          <Text style={styles.title}>{title}</Text>
          <View style={styles.sideBtn}>{right}</View>
        </View>
      </BlurView>
    </View>
  );
};

const styles = StyleSheet.create({
  wrapper: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 10,
  },
  blur: {
    backgroundColor: Platform.select({
      ios: 'rgba(28, 18, 16, 0.6)',
      android: 'rgba(28, 18, 16, 0.92)',
      default: 'rgba(28, 18, 16, 0.92)',
    }),
  },
  content: {
    height: spacing.navTop, // 44px
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.sm,
  },
  sideBtn: {
    width: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontWeight: '600',
    color: colors.accent.default,
  },
});
