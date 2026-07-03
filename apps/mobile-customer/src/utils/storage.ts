// Token 安全存储封装 - 基于 expo-securestore
// iOS 用 Keychain，Android 用 Keystore，避免明文存储 JWT
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

const TOKEN_KEY = 'dongfang_jwt';
const USER_KEY = 'dongfang_user';

// Web 平台 SecureStore 不可用，降级到 localStorage
const isWeb = Platform.OS === 'web';

// 获取 token
export async function getToken(): Promise<string | null> {
  if (isWeb) {
    return localStorage.getItem(TOKEN_KEY);
  }
  return SecureStore.getItemAsync(TOKEN_KEY);
}

// 保存 token
export async function setToken(token: string): Promise<void> {
  if (isWeb) {
    localStorage.setItem(TOKEN_KEY, token);
    return;
  }
  await SecureStore.setItemAsync(TOKEN_KEY, token);
}

// 删除 token
export async function removeToken(): Promise<void> {
  if (isWeb) {
    localStorage.removeItem(TOKEN_KEY);
    return;
  }
  await SecureStore.deleteItemAsync(TOKEN_KEY);
}

// 获取用户信息缓存
export async function getUserCache(): Promise<string | null> {
  if (isWeb) {
    return localStorage.getItem(USER_KEY);
  }
  return SecureStore.getItemAsync(USER_KEY);
}

// 保存用户信息缓存
export async function setUserCache(user: string): Promise<void> {
  if (isWeb) {
    localStorage.setItem(USER_KEY, user);
    return;
  }
  await SecureStore.setItemAsync(USER_KEY, user);
}

// 清除用户信息缓存
export async function removeUserCache(): Promise<void> {
  if (isWeb) {
    localStorage.removeItem(USER_KEY);
    return;
  }
  await SecureStore.deleteItemAsync(USER_KEY);
}
