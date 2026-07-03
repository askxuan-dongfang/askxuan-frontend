// 寺院列表：DFTopNavBar + 教派标签横滑 + FlatList 寺院卡片
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
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import { LinearGradient } from 'expo-linear-gradient';
import { DFTopNavBar } from '../../src/components/DFTopNavBar';
import { DFTagPill } from '../../src/components/DFTagPill';
import { getTemples } from '../../src/api/temple';
import { colors, radius, spacing, fontFamilies } from '../../src/theme/tokens';
import type { Temple } from '../../src/types';

// 教派分类
const CATEGORIES = ['全部', '汉传佛教', '藏传佛教', '道教'];

export default function TempleListScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const [activeCate, setActiveCate] = useState('全部');

  const { data: temples, isLoading, refetch, isFetching } = useQuery({
    queryKey: ['temples', 'list'],
    queryFn: () => getTemples(),
  });

  // 按教派分类筛选
  const filtered = useMemo(() => {
    if (!temples) return [];
    if (activeCate === '全部') return temples;
    return temples.filter((t: Temple) => t.type === activeCate);
  }, [temples, activeCate]);

  const renderItem = ({ item }: { item: Temple }) => (
    <TouchableOpacity
      activeOpacity={0.85}
      onPress={() => router.push(`/temple/${item.id}`)}
    >
      <View style={styles.card}>
        {/* 缩略图占位（渐变色块） */}
        <LinearGradient
          colors={['#5B4A6A', '#3A2C25']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.thumb}
        >
          <Text style={styles.thumbText}>{item.name}</Text>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{item.type}</Text>
          </View>
        </LinearGradient>
        <View style={styles.cardBody}>
          <View style={styles.cardHeader}>
            <Text style={styles.cardName}>{item.name}</Text>
            <Text style={styles.rating}>★ {item.rating.toFixed(1)}</Text>
          </View>
          <Text style={styles.region} numberOfLines={1}>
            {item.region} · {item.sect}
          </Text>
          <Text style={styles.desc} numberOfLines={1}>
            {item.description}
          </Text>
        </View>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <DFTopNavBar title="找寺院" />
      <View style={{ height: insets.top + 44 }} />

      {/* 教派标签横滑 */}
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

      {/* 寺院列表 */}
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
              <Text style={styles.empty}>暂无寺院数据</Text>
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
    overflow: 'hidden',
  },
  thumb: {
    width: 100,
    height: 100,
    alignItems: 'center',
    justifyContent: 'center',
  },
  thumbText: {
    color: colors.text.primary,
    fontSize: 16,
    fontWeight: '600',
    fontFamily: fontFamilies.serif,
  },
  badge: {
    position: 'absolute',
    top: 8,
    left: 8,
    backgroundColor: 'rgba(196, 90, 60, 0.85)',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  badgeText: {
    color: '#fff',
    fontSize: 10,
  },
  cardBody: {
    flex: 1,
    padding: spacing.md,
    justifyContent: 'center',
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  cardName: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.text.primary,
  },
  rating: {
    fontSize: 13,
    color: colors.accent.default,
    fontWeight: '600',
  },
  region: {
    fontSize: 12,
    color: colors.text.tertiary,
    marginBottom: 4,
  },
  desc: {
    fontSize: 12,
    color: colors.text.secondary,
  },
});
