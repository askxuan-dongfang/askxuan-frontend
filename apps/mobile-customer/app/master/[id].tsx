// 师傅主页：顶部背景+头像+法号+简介 + 5 Tab + 底部双按钮操作栏
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import { getMaster } from '../../src/api/master';
import { DFSecondaryButton } from '../../src/components/DFSecondaryButton';
import { DFPrimaryButton } from '../../src/components/DFPrimaryButton';
import { colors, radius, spacing, fontFamilies } from '../../src/theme/tokens';

const TABS = ['资质', '预约', '文创', '视频', '咨询'];

export default function MasterProfileScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const [activeTab, setActiveTab] = useState('资质');

  const { data: master, isLoading } = useQuery({
    queryKey: ['master', id],
    queryFn: () => getMaster(id),
    enabled: !!id,
  });

  if (isLoading) {
    return (
      <View style={styles.container}>
        <View style={[styles.center, { marginTop: 200 }]}>
          <ActivityIndicator size="large" color={colors.accent.default} />
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* 顶部背景区 + 头像 */}
        <LinearGradient
          colors={['#5B4A6A', '#3A2C25', '#1C1210']}
          start={{ x: 0, y: 0 }}
          end={{ x: 0, y: 1 }}
          style={styles.header}
        >
          {/* 返回按钮 */}
          <TouchableOpacity
            style={[styles.backBtn, { top: insets.top + 8 }]}
            onPress={() => router.back()}
          >
            <Ionicons name="chevron-back" size={22} color={colors.text.primary} />
          </TouchableOpacity>

          {/* 头像 80px */}
          <LinearGradient
            colors={['#C8A96E', '#A88A50']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.avatar}
          >
            <Text style={styles.avatarText}>
              {master?.dharmaName.slice(0, 1)}
            </Text>
          </LinearGradient>
          <Text style={styles.dharmaName}>{master?.dharmaName}</Text>
          <Text style={styles.templeName}>
            {master?.templeName} · {master?.position}
          </Text>
          <View style={styles.statRow}>
            <Text style={styles.statText}>★ {master?.rating.toFixed(1)}</Text>
            <Text style={styles.statDivider}>|</Text>
            <Text style={styles.statText}>{master?.sect}</Text>
            <Text style={styles.statDivider}>|</Text>
            <Text style={styles.statText}>已认证</Text>
          </View>
        </LinearGradient>

        {/* 简介 */}
        <View style={styles.introSection}>
          <Text style={styles.introTitle}>简介</Text>
          <Text style={styles.introText}>
            {master?.dharmaName}，现驻{master?.templeName}，担任{master?.position}，
            擅长{master?.specialties.join('、')}。多年修行，深谙佛法道法，可为善信祈福消灾。
          </Text>
          {/* 擅长标签 */}
          <View style={styles.tagRow}>
            {master?.specialties.map((s: string) => (
              <View key={s} style={styles.tag}>
                <Text style={styles.tagText}>{s}</Text>
              </View>
            ))}
          </View>
        </View>

        {/* 5 Tab */}
        <View style={styles.tabBar}>
          {TABS.map((tab) => (
            <TouchableOpacity
              key={tab}
              style={styles.tabItem}
              onPress={() => setActiveTab(tab)}
            >
              <Text
                style={[styles.tabText, activeTab === tab && styles.tabTextActive]}
              >
                {tab}
              </Text>
              {activeTab === tab && <View style={styles.tabIndicator} />}
            </TouchableOpacity>
          ))}
        </View>

        {/* Tab 内容区 */}
        <View style={styles.tabContent}>
          {activeTab === '资质' && (
            <View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>法号</Text>
                <Text style={styles.infoValue}>{master?.dharmaName}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>所属寺院</Text>
                <Text style={styles.infoValue}>{master?.templeName}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>宗派</Text>
                <Text style={styles.infoValue}>{master?.sect}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>职位</Text>
                <Text style={styles.infoValue}>{master?.position}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>认证状态</Text>
                <Text style={styles.infoValue}>{master?.authStatus}</Text>
              </View>
            </View>
          )}
          {activeTab === '预约' && (
            <View style={styles.emptyTab}>
              <Text style={styles.emptyText}>点击底部"预约服务"立即预约</Text>
            </View>
          )}
          {(activeTab === '文创' || activeTab === '视频' || activeTab === '咨询') && (
            <View style={styles.emptyTab}>
              <Text style={styles.emptyText}>敬请期待</Text>
            </View>
          )}
        </View>
        <View style={{ height: 100 }} />
      </ScrollView>

      {/* 底部固定操作栏：立即咨询（描边）+ 预约服务（实心） */}
      <View style={[styles.bottomBar, { paddingBottom: insets.bottom + 8 }]}>
        <DFSecondaryButton
          title="立即咨询"
          onPress={() => {}}
          style={{ flex: 1, marginRight: spacing.sm }}
        />
        <DFPrimaryButton
          title="预约服务"
          onPress={() =>
            router.push({ pathname: '/booking', params: { masterId: id } })
          }
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
  center: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  header: {
    alignItems: 'center',
    paddingTop: 60,
    paddingBottom: spacing.xl,
    position: 'relative',
  },
  backBtn: {
    position: 'absolute',
    left: spacing.lg,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(28, 18, 16, 0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 3,
    borderColor: colors.accent.default,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontSize: 28,
    fontWeight: '600',
    color: colors.bg.primary,
    fontFamily: fontFamilies.serif,
  },
  dharmaName: {
    fontSize: 20,
    fontWeight: '700',
    color: colors.text.primary,
    fontFamily: fontFamilies.serif,
    marginTop: spacing.md,
  },
  templeName: {
    fontSize: 13,
    color: colors.text.secondary,
    marginTop: 4,
  },
  statRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  statText: {
    fontSize: 12,
    color: colors.accent.default,
  },
  statDivider: {
    color: colors.border.strong,
  },
  introSection: {
    padding: spacing.lg,
  },
  introTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: colors.text.primary,
    marginBottom: spacing.sm,
  },
  introText: {
    fontSize: 14,
    color: colors.text.secondary,
    lineHeight: 22,
  },
  tagRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginTop: spacing.md,
  },
  tag: {
    backgroundColor: 'rgba(200, 169, 110, 0.08)',
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  tagText: {
    fontSize: 11,
    color: colors.accent.default,
  },
  tabBar: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: colors.border.divider,
    paddingHorizontal: spacing.sm,
  },
  tabItem: {
    flex: 1,
    paddingVertical: spacing.md,
    alignItems: 'center',
  },
  tabText: {
    fontSize: 13,
    color: colors.text.tertiary,
  },
  tabTextActive: {
    color: colors.accent.default,
    fontWeight: '600',
  },
  tabIndicator: {
    position: 'absolute',
    bottom: 0,
    width: 20,
    height: 2,
    backgroundColor: colors.brand.default,
  },
  tabContent: {
    padding: spacing.lg,
    minHeight: 200,
  },
  infoRow: {
    flexDirection: 'row',
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border.divider,
  },
  infoLabel: {
    width: 90,
    fontSize: 13,
    color: colors.text.tertiary,
  },
  infoValue: {
    flex: 1,
    fontSize: 13,
    color: colors.text.secondary,
  },
  emptyTab: {
    alignItems: 'center',
    paddingVertical: spacing.xl,
  },
  emptyText: {
    color: colors.text.tertiary,
    fontSize: 14,
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: colors.bg.secondary,
    borderTopColor: colors.border.divider,
    borderTopWidth: 1,
    padding: spacing.lg,
    flexDirection: 'row',
  },
});
