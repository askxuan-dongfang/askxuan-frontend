// 寺院详情：Hero 大图 + 寺院信息 + Tab 切换 + 底部预约按钮
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
import { getTemple } from '../../src/api/temple';
import { getMasters } from '../../src/api/master';
import { DFTopNavBar } from '../../src/components/DFTopNavBar';
import { DFPrimaryButton } from '../../src/components/DFPrimaryButton';
import { DFTagPill } from '../../src/components/DFTagPill';
import { colors, radius, spacing, fontFamilies } from '../../src/theme/tokens';
import type { Master } from '../../src/types';

const TABS = ['基础信息', '公共服务', '大师团队', '文创'];

export default function TempleDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const [activeTab, setActiveTab] = useState('基础信息');
  const [favorited, setFavorited] = useState(false);

  const { data: temple, isLoading } = useQuery({
    queryKey: ['temple', id],
    queryFn: () => getTemple(id),
    enabled: !!id,
  });

  const { data: masters } = useQuery({
    queryKey: ['masters', 'temple', id],
    queryFn: () => getMasters(),
  });

  // 该寺院的师傅
  const templeMasters: Master[] = (masters || []).filter((m: Master) => m.templeId === id);

  if (isLoading) {
    return (
      <View style={styles.container}>
        <DFTopNavBar title="寺院详情" />
        <View style={[styles.center, { marginTop: 200 }]}>
          <ActivityIndicator size="large" color={colors.accent.default} />
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false}>
        {/* Hero 大图（渐变占位） */}
        <View style={styles.hero}>
          <LinearGradient
            colors={['#5B4A6A', '#3A2C25', '#1C1210']}
            start={{ x: 0, y: 0 }}
            end={{ x: 0, y: 1 }}
            style={styles.heroGradient}
          >
            <Text style={styles.heroName}>{temple?.name}</Text>
          </LinearGradient>
          {/* 浮动返回/收藏按钮 */}
          <View style={[styles.floatBar, { top: insets.top + 8 }]}>
            <TouchableOpacity
              style={styles.floatBtn}
              onPress={() => router.back()}
            >
              <Ionicons name="chevron-back" size={22} color={colors.text.primary} />
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.floatBtn}
              onPress={() => setFavorited((v) => !v)}
            >
              <Ionicons
                name={favorited ? 'heart' : 'heart-outline'}
                size={20}
                color={favorited ? colors.brand.default : colors.text.primary}
              />
            </TouchableOpacity>
          </View>
        </View>

        {/* 寺院信息 */}
        <View style={styles.infoSection}>
          <Text style={styles.name}>{temple?.name}</Text>
          <View style={styles.metaRow}>
            <Text style={styles.metaText}>{temple?.region}</Text>
            <Text style={styles.divider}>·</Text>
            <Text style={styles.metaText}>{temple?.type}</Text>
            <Text style={styles.divider}>·</Text>
            <Text style={styles.rating}>★ {temple?.rating.toFixed(1)}</Text>
          </View>
        </View>

        {/* Tab 切换栏 */}
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
          {activeTab === '基础信息' && (
            <View>
              <Text style={styles.descTitle}>寺院简介</Text>
              <Text style={styles.descText}>{temple?.description}</Text>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>地址</Text>
                <Text style={styles.infoValue}>{temple?.address}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>宗派</Text>
                <Text style={styles.infoValue}>{temple?.sect}</Text>
              </View>
              <View style={styles.infoRow}>
                <Text style={styles.infoLabel}>状态</Text>
                <Text style={styles.infoValue}>{temple?.status}</Text>
              </View>
            </View>
          )}
          {activeTab === '公共服务' && (
            <View style={styles.emptyTab}>
              <Text style={styles.emptyText}>祈福 · 供灯 · 上香 · 开光 · 超度 · 化太岁</Text>
            </View>
          )}
          {activeTab === '大师团队' && (
            <View>
              {templeMasters.length === 0 ? (
                <Text style={styles.emptyText}>暂无驻院师傅</Text>
              ) : (
                templeMasters.map((m) => (
                  <TouchableOpacity
                    key={m.id}
                    onPress={() => router.push(`/master/${m.id}`)}
                  >
                    <View style={styles.masterRow}>
                      <LinearGradient
                        colors={['#C8A96E', '#A88A50']}
                        style={styles.masterAvatarSmall}
                      >
                        <Text style={styles.masterAvatarText}>
                          {m.dharmaName.slice(0, 1)}
                        </Text>
                      </LinearGradient>
                      <View style={{ flex: 1 }}>
                        <Text style={styles.masterName}>{m.dharmaName}</Text>
                        <Text style={styles.masterMeta}>
                          {m.position} · {m.sect}
                        </Text>
                      </View>
                      <Text style={styles.rating}>★ {m.rating.toFixed(1)}</Text>
                    </View>
                  </TouchableOpacity>
                ))
              )}
            </View>
          )}
          {activeTab === '文创' && (
            <View style={styles.emptyTab}>
              <Text style={styles.emptyText}>敬请期待</Text>
            </View>
          )}
        </View>
        <View style={{ height: 80 }} />
      </ScrollView>

      {/* 底部预约服务按钮 */}
      <View style={[styles.bottomBar, { paddingBottom: insets.bottom + 8 }]}>
        <DFPrimaryButton
          title="预约服务"
          onPress={() => router.push({ pathname: '/booking', params: { templeId: id } })}
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
  hero: {
    height: 220,
    position: 'relative',
  },
  heroGradient: {
    flex: 1,
    justifyContent: 'flex-end',
    padding: spacing.lg,
  },
  heroName: {
    fontSize: 24,
    fontWeight: '600',
    color: colors.text.primary,
    fontFamily: fontFamilies.serif,
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },
  floatBar: {
    position: 'absolute',
    left: spacing.lg,
    right: spacing.lg,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  floatBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(28, 18, 16, 0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  infoSection: {
    padding: spacing.lg,
  },
  name: {
    fontSize: 22,
    fontWeight: '700',
    color: colors.text.primary,
    fontFamily: fontFamilies.serif,
    marginBottom: spacing.xs,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  metaText: {
    fontSize: 13,
    color: colors.text.secondary,
  },
  divider: {
    color: colors.text.tertiary,
  },
  rating: {
    fontSize: 13,
    color: colors.accent.default,
    fontWeight: '600',
  },
  tabBar: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: colors.border.divider,
    paddingHorizontal: spacing.lg,
  },
  tabItem: {
    flex: 1,
    paddingVertical: spacing.md,
    alignItems: 'center',
  },
  tabText: {
    fontSize: 14,
    color: colors.text.tertiary,
  },
  tabTextActive: {
    color: colors.accent.default,
    fontWeight: '600',
  },
  tabIndicator: {
    position: 'absolute',
    bottom: 0,
    width: 24,
    height: 2,
    backgroundColor: colors.brand.default,
  },
  tabContent: {
    padding: spacing.lg,
    minHeight: 200,
  },
  descTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: colors.text.primary,
    marginBottom: spacing.sm,
  },
  descText: {
    fontSize: 14,
    color: colors.text.secondary,
    lineHeight: 22,
    marginBottom: spacing.lg,
  },
  infoRow: {
    flexDirection: 'row',
    paddingVertical: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border.divider,
  },
  infoLabel: {
    width: 60,
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
  masterRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border.divider,
    gap: spacing.md,
  },
  masterAvatarSmall: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  masterAvatarText: {
    fontSize: 18,
    fontWeight: '600',
    color: colors.bg.primary,
    fontFamily: fontFamilies.serif,
  },
  masterName: {
    fontSize: 15,
    fontWeight: '600',
    color: colors.text.primary,
  },
  masterMeta: {
    fontSize: 12,
    color: colors.text.tertiary,
    marginTop: 2,
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
  },
});
