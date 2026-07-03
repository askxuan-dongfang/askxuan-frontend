// 首页：品牌头 + 装饰搜索 + Banner 轮播 + 找寺院/找师傅入口 + 热门服务网格 + 热门寺院/师傅横滑
import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons, MaterialCommunityIcons, Entypo } from '@expo/vector-icons';
import { useQuery } from '@tanstack/react-query';
import { colors, radius, spacing, fontFamilies } from '../../src/theme/tokens';
import { getTemples } from '../../src/api/temple';
import { getMasters } from '../../src/api/master';
import { DFBannerCarousel } from '../../src/components/DFBannerCarousel';
import type { Banner, Temple, Master } from '../../src/types';

// Banner 占位数据（渐变色块）
const banners: Banner[] = [
  {
    id: 'b1',
    title: '岁末祈福大典',
    gradient: ['#A64830', '#C45A3C'],
  },
  {
    id: 'b2',
    title: '线上祈福 福泽绵长',
    gradient: ['#A88A50', '#C8A96E'],
  },
  {
    id: 'b3',
    title: '雪域修行 心灵之旅',
    gradient: ['#5B4A6A', '#3A2C25'],
  },
];

// 热门服务 4x2 网格
type IconLib = 'ion' | 'material' | 'entypo';
interface HotService {
  id: string;
  name: string;
  icon: string;
  lib: IconLib;
}
const hotServices: HotService[] = [
  { id: 'diy', name: 'DIY手串', icon: 'color-filter-outline', lib: 'ion' },
  { id: 'blessing', name: '祈福', icon: 'heart-outline', lib: 'ion' },
  { id: 'lamp', name: '供灯', icon: 'bulb-outline', lib: 'ion' },
  { id: 'incense', name: '上香', icon: 'flame-outline', lib: 'ion' },
  { id: 'vow', name: '还愿', icon: 'checkmark-done-outline', lib: 'ion' },
  { id: 'rite', name: '超度', icon: 'water-outline', lib: 'ion' },
  { id: 'consecration', name: '开光', icon: 'sparkles-outline', lib: 'ion' },
  { id: 'taisui', name: '化太岁', icon: 'shield-checkmark-outline', lib: 'ion' },
];

export default function HomeScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();

  // 拉取寺院与师傅列表
  const { data: temples, isLoading: templesLoading } = useQuery({
    queryKey: ['temples', 'home'],
    queryFn: () => getTemples(),
  });
  const { data: masters, isLoading: mastersLoading } = useQuery({
    queryKey: ['masters', 'home'],
    queryFn: () => getMasters(),
  });

  return (
    <View style={styles.container}>
      {/* 顶部品牌名 + 装饰搜索框 */}
      <View style={[styles.header, { paddingTop: insets.top + spacing.sm }]}>
        <Text style={styles.brand}>问玄东方</Text>
        <View style={styles.searchFake}>
          <Ionicons name="search" size={16} color={colors.text.tertiary} />
          <Text style={styles.searchPlaceholder}>搜索寺院 · 师傅 · 法事</Text>
        </View>
      </View>

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: spacing.xl }}
      >
        {/* Banner 轮播 */}
        <View style={styles.section}>
          <DFBannerCarousel data={banners} height={200} />
        </View>

        {/* 找寺院 / 找师傅 双入口 */}
        <View style={styles.entryRow}>
          <TouchableOpacity
            activeOpacity={0.85}
            onPress={() => router.push('/temple')}
            style={styles.entryCard}
          >
            <LinearGradient
              colors={['#3A2C25', '#2A1E1A']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.entryGradient}
            >
              <Ionicons name="home" size={28} color={colors.accent.default} />
              <Text style={styles.entryText}>找寺院</Text>
            </LinearGradient>
          </TouchableOpacity>
          <TouchableOpacity
            activeOpacity={0.85}
            onPress={() => router.push('/master')}
            style={styles.entryCard}
          >
            <LinearGradient
              colors={['#44342C', '#2A1E1A']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.entryGradient}
            >
              <Ionicons name="person" size={28} color={colors.accent.default} />
              <Text style={styles.entryText}>找师傅</Text>
            </LinearGradient>
          </TouchableOpacity>
        </View>

        {/* 热门服务 4x2 网格 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>热门服务</Text>
          <View style={styles.serviceGrid}>
            {hotServices.map((svc) => (
              <TouchableOpacity
                key={svc.id}
                style={styles.serviceItem}
                activeOpacity={0.7}
                onPress={() => router.push('/temple')}
              >
                <View style={styles.serviceIconWrap}>
                  {svc.lib === 'ion' && (
                    <Ionicons
                      name={svc.icon as React.ComponentProps<typeof Ionicons>['name']}
                      size={20}
                      color={colors.brand.default}
                    />
                  )}
                  {svc.lib === 'material' && (
                    <MaterialCommunityIcons
                      name={svc.icon as React.ComponentProps<typeof MaterialCommunityIcons>['name']}
                      size={20}
                      color={colors.accent.default}
                    />
                  )}
                  {svc.lib === 'entypo' && (
                    <Entypo
                      name={svc.icon as React.ComponentProps<typeof Entypo>['name']}
                      size={20}
                      color={colors.brand.default}
                    />
                  )}
                </View>
                <Text style={styles.serviceName}>{svc.name}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* 热门寺院横向滚动 */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>热门寺院</Text>
            <TouchableOpacity onPress={() => router.push('/temple')}>
              <Text style={styles.more}>更多 ›</Text>
            </TouchableOpacity>
          </View>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ paddingHorizontal: spacing.lg, gap: spacing.md }}
          >
            {templesLoading ? (
              <ActivityIndicator color={colors.accent.default} style={{ padding: 20 }} />
            ) : (
              (temples || []).slice(0, 6).map((temple: Temple) => (
                <TouchableOpacity
                  key={temple.id}
                  activeOpacity={0.85}
                  onPress={() => router.push(`/temple/${temple.id}`)}
                >
                  <View style={styles.templeCard}>
                    {/* 渐变色块占位图 */}
                    <LinearGradient
                      colors={['#5B4A6A', '#3A2C25']}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.templeImg}
                    >
                      <Text style={styles.templeImgText}>{temple.name}</Text>
                    </LinearGradient>
                    <View style={styles.templeBody}>
                      <View style={styles.templeRow}>
                        <Text style={styles.templeName} numberOfLines={1}>
                          {temple.name}
                        </Text>
                        <Text style={styles.templeRating}>★ {temple.rating.toFixed(1)}</Text>
                      </View>
                      <Text style={styles.templeCity} numberOfLines={1}>
                        {temple.region}
                      </Text>
                    </View>
                  </View>
                </TouchableOpacity>
              ))
            )}
          </ScrollView>
        </View>

        {/* 热门师傅横向滚动 */}
        <View style={[styles.section, { marginTop: spacing.lg }]}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>热门师傅</Text>
            <TouchableOpacity onPress={() => router.push('/master')}>
              <Text style={styles.more}>更多 ›</Text>
            </TouchableOpacity>
          </View>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ paddingHorizontal: spacing.lg, gap: spacing.md }}
          >
            {mastersLoading ? (
              <ActivityIndicator color={colors.accent.default} style={{ padding: 20 }} />
            ) : (
              (masters || []).slice(0, 6).map((master: Master) => (
                <TouchableOpacity
                  key={master.id}
                  activeOpacity={0.85}
                  onPress={() => router.push(`/master/${master.id}`)}
                >
                  <View style={styles.masterCard}>
                    {/* 圆形头像占位（渐变） */}
                    <LinearGradient
                      colors={['#C8A96E', '#A88A50']}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.masterAvatar}
                    >
                      <Text style={styles.masterAvatarText}>
                        {master.dharmaName.slice(0, 1)}
                      </Text>
                    </LinearGradient>
                    <Text style={styles.masterName} numberOfLines={1}>
                      {master.dharmaName}
                    </Text>
                    <Text style={styles.masterTemple} numberOfLines={1}>
                      {master.templeName}
                    </Text>
                    <Text style={styles.masterRating}>★ {master.rating.toFixed(1)}</Text>
                  </View>
                </TouchableOpacity>
              ))
            )}
          </ScrollView>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  header: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.md,
    backgroundColor: colors.bg.primary,
  },
  brand: {
    fontSize: 24,
    fontWeight: '600',
    color: colors.accent.default,
    fontFamily: fontFamilies.serif,
    marginBottom: spacing.sm,
  },
  searchFake: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.bg.secondary,
    borderRadius: radius.lg,
    paddingHorizontal: spacing.md,
    height: 36,
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  searchPlaceholder: {
    marginLeft: spacing.sm,
    fontSize: 13,
    color: colors.text.tertiary,
  },
  section: {
    paddingHorizontal: spacing.lg,
    marginTop: spacing.lg,
  },
  entryRow: {
    flexDirection: 'row',
    paddingHorizontal: spacing.lg,
    marginTop: spacing.lg,
    gap: spacing.md,
  },
  entryCard: {
    flex: 1,
    height: 120,
    borderRadius: radius.lg,
    overflow: 'hidden',
  },
  entryGradient: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
  },
  entryText: {
    fontSize: 16,
    fontWeight: '600',
    color: colors.accent.default,
    fontFamily: fontFamilies.serif,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: colors.text.primary,
  },
  more: {
    fontSize: 13,
    color: colors.accent.default,
  },
  serviceGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  serviceItem: {
    width: '24%',
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  serviceIconWrap: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.bg.secondary,
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  serviceName: {
    fontSize: 11,
    color: colors.text.primary,
    marginTop: spacing.xs,
  },
  // 寺院横滑卡片
  templeCard: {
    width: 180,
    borderRadius: radius.lg,
    overflow: 'hidden',
    backgroundColor: colors.bg.secondary,
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  templeImg: {
    width: 180,
    height: 110,
    alignItems: 'center',
    justifyContent: 'center',
  },
  templeImgText: {
    color: colors.text.primary,
    fontSize: 18,
    fontWeight: '600',
    fontFamily: fontFamilies.serif,
  },
  templeBody: {
    padding: spacing.sm,
  },
  templeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  templeName: {
    fontSize: 14,
    fontWeight: '600',
    color: colors.text.primary,
    flex: 1,
  },
  templeRating: {
    fontSize: 11,
    color: colors.accent.default,
    fontWeight: '500',
  },
  templeCity: {
    fontSize: 11,
    color: colors.text.tertiary,
    marginTop: 2,
  },
  // 师傅横滑卡片
  masterCard: {
    width: 100,
    alignItems: 'center',
    padding: spacing.sm,
  },
  masterAvatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    borderWidth: 2,
    borderColor: colors.accent.default,
    alignItems: 'center',
    justifyContent: 'center',
  },
  masterAvatarText: {
    fontSize: 20,
    fontWeight: '600',
    color: colors.bg.primary,
    fontFamily: fontFamilies.serif,
  },
  masterName: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.text.primary,
    marginTop: spacing.xs,
  },
  masterTemple: {
    fontSize: 10,
    color: colors.text.tertiary,
    marginTop: 1,
  },
  masterRating: {
    fontSize: 11,
    color: colors.accent.default,
    marginTop: 2,
  },
});
