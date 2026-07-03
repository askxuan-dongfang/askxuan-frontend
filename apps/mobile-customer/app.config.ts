// Expo 动态配置：透传环境变量
// 读取 .env 中 EXPO_PUBLIC_* 变量，运行时通过 process.env 访问
import type { ExpoConfig, ConfigContext } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: '问玄东方',
  slug: 'dongfang-customer',
  scheme: 'dongfang',
  version: '1.0.0',
  orientation: 'portrait',
  userInterfaceStyle: 'dark',
  extra: {
    eas: {
      projectId: 'dongfang-customer',
    },
  },
});
