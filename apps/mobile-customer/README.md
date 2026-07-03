# 问玄东方 · C 端移动端 (Expo)

Expo SDK 52 + React Native + TypeScript + expo-router 文件路由。

## 启动

```bash
cd apps/mobile-customer
npm install
npx expo start
```

其他启动方式：

```bash
npx expo start --ios       # iOS 模拟器
npx expo start --android   # Android 模拟器
npx expo start --web       # Web 预览
```

## 环境变量

复制 `.env.example` 为 `.env`，配置后端地址：

```
EXPO_PUBLIC_API_BASE_URL=http://localhost:3001/api/v1
```

> 真机调试时需改为电脑局域网 IP，例如 `http://192.168.x.x:3001/api/v1`。

## 目录结构

```
app/                 expo-router 文件路由
  _layout.tsx        根布局（Provider 注入）
  (tabs)/            底部 Tab（首页/对话/AI问事/商城/我的）
  temple/            寺院列表 + 详情
  master/            师傅列表 + 主页
  booking/           预约下单 + 成功页
src/
  theme/             设计令牌、ThemeProvider
  components/        DF* 通用组件
  api/               axios 封装 + 各模块接口
  types/             TypeScript 类型
  stores/            Zustand 客户端状态
  utils/             工具函数（token 存储等）
```

## 设计令牌

颜色与字体来自 `packages/design-tokens/tokens.json`，主色：

- 深檀木背景 `#1C1210`
- 朱砂红（主 CTA）`#C45A3C`
- 琉璃金（强调/边框/图标）`#C8A96E`

## 联调 Mock Server

```bash
# 仓库根目录启动 Mock Server（端口 3001）
cd packages/mock-server && npm run dev
```

## EAS 云端构建与热更新

### 前提

- `eas login` 登录已注册的 Expo 账号
- iOS 构建需 Apple Developer 账号（Apple ID + 付费开发者计划）
- 安装 EAS CLI：`npm install -g eas-cli`

### EAS Build（云端打包）

```bash
# iOS 预览包（internal 分发，可装到指定设备）
eas build -p ios --profile preview

# Android 预览包（internal 分发）
eas build -p android --profile preview

# 生产包（提交到 App Store / Google Play）
eas build -p ios --profile production
eas build -p android --profile production
```

构建配置见 `eas.json`，三个 profile：

| profile | 用途 | 分发方式 | channel |
|---------|------|----------|---------|
| development | 开发调试 | internal | development |
| preview | 预览体验 | internal | preview |
| production | 正式发布 | store | production |

### EAS Update（JS 热更新）

无需重新发版即可推送 JS Bundle 更新：

```bash
# 首次配置 EAS Update
eas update:configure

# 推送更新到 preview 分支
eas update --branch preview --message "update"

# 推送更新到 production 分支
eas update --branch production --message "fix: 修复首页样式"
```

> 热更新仅替换 JS 代码，不涉及原生模块变更；若新增原生依赖需走 EAS Build 重新打包。
