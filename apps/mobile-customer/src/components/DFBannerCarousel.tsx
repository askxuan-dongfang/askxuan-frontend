// 轮播组件：ScrollView pagingEnabled + 自动播放 3s + 圆点指示器
import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  ScrollView,
  StyleSheet,
  Dimensions,
  type NativeSyntheticEvent,
  type NativeScrollEvent,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Text } from 'react-native';
import { colors, radius } from '../theme/tokens';
import type { Banner } from '../types';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface DFBannerCarouselProps {
  data: Banner[];
  autoPlay?: boolean;
  interval?: number; // 毫秒
  height?: number;
}

export const DFBannerCarousel = ({
  data,
  autoPlay = true,
  interval = 3000,
  height = 200,
}: DFBannerCarouselProps) => {
  const [activeIndex, setActiveIndex] = useState(0);
  const scrollRef = useRef<ScrollView>(null);
  const indexRef = useRef(0);

  // 同步 ref 与 state
  const updateIndex = (i: number) => {
    indexRef.current = i;
    setActiveIndex(i);
  };

  // 自动播放
  useEffect(() => {
    if (!autoPlay || data.length <= 1) return;
    const timer = setInterval(() => {
      const next = (indexRef.current + 1) % data.length;
      scrollRef.current?.scrollTo({ x: next * SCREEN_WIDTH, animated: true });
      updateIndex(next);
    }, interval);
    return () => clearInterval(timer);
  }, [autoPlay, data.length, interval]);

  const onScroll = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const index = Math.round(e.nativeEvent.contentOffset.x / SCREEN_WIDTH);
    if (index !== indexRef.current) {
      updateIndex(index);
    }
  };

  return (
    <View>
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={16}
      >
        {data.map((banner) => (
          <LinearGradient
            key={banner.id}
            colors={banner.gradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={[styles.slide, { height }]}
          >
            <Text style={styles.title}>{banner.title}</Text>
          </LinearGradient>
        ))}
      </ScrollView>
      {/* 指示点 */}
      <View style={styles.dots}>
        {data.map((_, i) => (
          <View
            key={i}
            style={[styles.dot, i === activeIndex && styles.dotActive]}
          />
        ))}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  slide: {
    width: SCREEN_WIDTH,
    borderRadius: radius.lg,
    justifyContent: 'flex-end',
    padding: 16,
  },
  title: {
    color: colors.text.primary,
    fontSize: 18,
    fontWeight: '600',
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },
  dots: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 10,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: colors.text.tertiary,
    marginHorizontal: 3,
  },
  dotActive: {
    backgroundColor: colors.brand.default,
    width: 18,
  },
});
