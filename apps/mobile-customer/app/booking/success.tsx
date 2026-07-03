// 预约成功页：勾选图标 + "预约成功" + 查看订单/返回首页
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { DFPrimaryButton } from '../../src/components/DFPrimaryButton';
import { DFSecondaryButton } from '../../src/components/DFSecondaryButton';
import { colors, radius, spacing, fontFamilies } from '../../src/theme/tokens';

export default function BookingSuccessScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const insets = useSafeAreaInsets();

  return (
    <View style={styles.container}>
      <View style={[styles.content, { paddingTop: insets.top + 80 }]}>
        {/* 勾选图标 */}
        <LinearGradient
          colors={['#5B8C5A', '#3A6A4A']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.checkIcon}
        >
          <Ionicons name="checkmark" size={48} color={colors.text.primary} />
        </LinearGradient>

        <Text style={styles.title}>预约成功</Text>
        <Text style={styles.subtitle}>您的预约已提交，请耐心等待确认</Text>

        {id ? <Text style={styles.orderId}>订单号：{id}</Text> : null}
      </View>

      {/* 操作按钮 */}
      <View style={[styles.actions, { paddingBottom: insets.bottom + 24 }]}>
        <DFSecondaryButton
          title="查看订单"
          onPress={() => router.replace('/(tabs)/profile')}
          style={{ flex: 1, marginRight: spacing.sm }}
        />
        <DFPrimaryButton
          title="返回首页"
          onPress={() => router.replace('/(tabs)/home')}
          style={{ flex: 1 }}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  content: {
    flex: 1,
    alignItems: 'center',
  },
  checkIcon: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.lg,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: colors.text.primary,
    fontFamily: fontFamilies.serif,
    marginBottom: spacing.sm,
  },
  subtitle: {
    fontSize: 14,
    color: colors.text.secondary,
    marginBottom: spacing.sm,
  },
  orderId: {
    fontSize: 13,
    color: colors.text.tertiary,
  },
  actions: {
    flexDirection: 'row',
    paddingHorizontal: spacing.lg,
  },
});
