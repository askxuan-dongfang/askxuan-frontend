// 根布局：SafeAreaProvider + QueryClientProvider + ThemeProvider + Stack
import React from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ThemeProvider } from '../src/theme/ThemeProvider';
import { colors } from '../src/theme/tokens';

// TanStack Query 客户端
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2, // 失败重试 2 次
      staleTime: 1000 * 60 * 5, // 5 分钟内不重复请求
      refetchOnWindowFocus: false,
    },
  },
});

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <ThemeProvider>
        <QueryClientProvider client={queryClient}>
          <StatusBar style="light" backgroundColor={colors.bg.primary} />
          <Stack
            screenOptions={{
              headerShown: false,
              contentStyle: { backgroundColor: colors.bg.primary },
            }}
          >
            <Stack.Screen name="(tabs)" />
            <Stack.Screen
              name="temple/index"
              options={{ animation: 'slide_from_right' }}
            />
            <Stack.Screen
              name="temple/[id]"
              options={{ animation: 'slide_from_right' }}
            />
            <Stack.Screen
              name="master/index"
              options={{ animation: 'slide_from_right' }}
            />
            <Stack.Screen
              name="master/[id]"
              options={{ animation: 'slide_from_right' }}
            />
            <Stack.Screen
              name="booking/index"
              options={{ animation: 'slide_from_bottom', presentation: 'modal' }}
            />
            <Stack.Screen
              name="booking/success"
              options={{ animation: 'slide_from_right' }}
            />
          </Stack>
        </QueryClientProvider>
      </ThemeProvider>
    </SafeAreaProvider>
  );
}
