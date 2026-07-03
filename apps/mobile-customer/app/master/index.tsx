// 师傅列表：DFTopNavBar + 教派分类横滑 + 师傅卡片列表
import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery } from '@tanstack/react-query';
import { LinearGradient } from 'expo-linear-gradient';
import { DFTopNavBar } from '../../src/components/DFTopNavBar';
import { DFTagPill } from '../../src/components/DFTagPill';
import { getMasters } from '../../src/api/master';
import { colors, radius, spacing, fontFamilies } from '../../src/theme/tokens';
import type { Master } from '../../src/types';

const CATEGORIES = ['全部', '佛教', '道教'];

export default function MasterListScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const [activeCate, setActiveCate] = useState('全部');

  const { data: masters, isLoading, refetch, isFetching } = useQuery({
    queryKey: ['masters', 'list'],
    queryFn: () => getMasters(),
  });

  const filtered = useMemo(() => {
    if (!masters) return [];
    if (activeCate === '全部') return masters;
    return masters.filter((m: Master) => m.type === activeCate);
  }, [masters, activeCate]);

  const renderItem = ({ item }: { item: Master }) => (
    <TouchableOpacity
      activeOpacity={0.85}
      onPress={() => router.push(`/master/${item.id}`)}
    >
      <View style={styles.card}>
        {/* 圆形头像 72px 金色边框 */}
        <LinearGradient
          colors={['#C8A96E', '#A88A50']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.avatar}
        >
          <Text style={styles.avatarText}>{item.dharmaName.slice(0, 1)}</Text>
          {/* 在线状态点 */}
          <View style={styles.onlineDot} />
        </LinearGradient>

        <View style={styles.body}>
          <View style={styles.headerRow}>
            <Text style={styles.name}>{item.dharmaName}</Text>
            <Text style={styles.rating}>★ {item.rating.toFixed(1)}</Text>
          </View>
          <Text style={styles.meta}>
            {item.templeName} · {item.position}
          </Text>
          {/* 擅长标签 */}
          <View style={styles.tagRow}>
            {item.specialties.slice(0, 3).map((s) => (
              <View key={s} style={styles.tag}>
                <Text style={styles.tagText}>{s}</Text>
              </View>
            ))}
          </View>
          <View style={styles.footerRow}>
            <Text style={styles.sectText}>{item.sect}</Text>
            <Text style={styles.price}>¥{(item.startPrice ?? 268)}起</Text>
          </View>
        </View>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <DFTopNavBar title="找师傅" />
      <View style={{ height: insets.top + 44 }} />

      {/* 教派分类横滑 */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.cateRow}
      >
        {CATEGORIES.map((cate) => (
          <DFTagPill
            key={cate}
            label={cate}
            active={activeCate === cate}
            onPress={() => setActiveCate(cate)}
          />
        ))}
      </ScrollView>

      {isLoading ? (
        <View style={styles.center}>
          <ActivityIndicator size="large" color={colors.accent.default} />
        </View>
      ) : (
        <FlatList
          data={filtered}
          keyExtractor={(item) => item.id}
          renderItem={renderItem}
          contentContainerStyle={{ padding: spacing.lg }}
          ItemSeparatorComponent={() => <View style={{ height: spacing.md }} />}
          refreshControl={
            <RefreshControl
              refreshing={isFetching}
              onRefresh={refetch}
              tintColor={colors.accent.default}
              colors={[colors.accent.default]}
            />
          }
          ListEmptyComponent={
            <View style={styles.center}>
              <Text style={styles.empty}>暂无师傅数据</Text>
            </View>
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  cateRow: {
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.xl,
  },
  empty: {
    color: colors.text.tertiary,
    fontSize: 14,
  },
  card: {
    flexDirection: 'row',
    backgroundColor: colors.bg.secondary,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border.default,
    padding: spacing.md,
    gap: spacing.md,
  },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 36,
    borderWidth: 2,
    borderColor: colors.accent.default,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontSize: 24,
    fontWeight: '600',
    color: colors.bg.primary,
    fontFamily: fontFamilies.serif,
  },
  onlineDot: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: colors.state.success,
    borderWidth: 2,
    borderColor: colors.bg.secondary,
  },
  body: {
    flex: 1,
    justifyContent: 'center',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  name: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.text.primary,
  },
  rating: {
    fontSize: 13,
    color: colors.accent.default,
    fontWeight: '600',
  },
  meta: {
    fontSize: 12,
    color: colors.text.tertiary,
    marginTop: 2,
  },
  tagRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginTop: 6,
  },
  tag: {
    backgroundColor: 'rgba(200, 169, 110, 0.08)',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  tagText: {
    fontSize: 10,
    color: colors.text.secondary,
  },
  footerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 8,
    paddingTop: 6,
    borderTopWidth: 1,
    borderTopColor: colors.border.divider,
  },
  sectText: {
    fontSize: 11,
    color: colors.accent.default,
  },
  price: {
    fontSize: 13,
    color: colors.brand.default,
    fontWeight: '700',
  },
});
