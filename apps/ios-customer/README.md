# 问玄东方 C端 iOS App (P01)

原生 Swift + SwiftUI + MVVM 架构，使用 XcodeGen 管理工程文件。

## 目录结构

```
ios-customer/
├── DongFangApp/
│   ├── App/                    Configuration.swift, DongFangApp.swift, MainTabView.swift
│   ├── Core/Network/           APIClient.swift, APIResponse.swift, Endpoint.swift, AuthStore.swift
│   ├── DesignSystem/           Tokens.swift, Components/
│   ├── Features/               11 个功能模块（Home/Temple/Master/Booking/Service/Diy/Shop/Chat/Profile）
│   ├── Models/                 10 个数据模型
│   ├── Resources/              Info.plist
│   └── Utils/                  DateFormatter.swift, JSONHelper.swift
├── project.yml                 XcodeGen 配置
└── README.md
```

## 环境要求

- macOS 13+
- Xcode 15+
- iOS 16.0+ 模拟器
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（可选，用于生成 .xcodeproj）
- [CocoaPods](https://cocoapods.org/)（必需，安装 OpenIMSDK 等依赖）

## 快速开始

### 1. 启动后端基础设施

```bash
cd /Users/gaofeng/develop/DongFang/askXuan-backend
docker compose up -d        # 启动 MySQL/Redis/RabbitMQ/MinIO/etcd/MongoDB/Kafka/Zookeeper
make db-init                # 初始化数据库（首次）
make start-all              # 启动 18 个微服务 + 1 网关
```

验证网关可达：`curl http://localhost:8080/api/v1/health`

### 2. 安装 XcodeGen 和 CocoaPods（如未安装）

```bash
brew install xcodegen cocoapods
```

### 3. 生成 Xcode 工程

```bash
cd /Users/gaofeng/develop/DongFang/askXuan-frontend/apps/ios-customer
xcodegen generate
```

执行后会生成 `DongFangApp.xcodeproj`。

### 4. 安装 Pod 依赖

```bash
pod install
```

执行后会生成 `DongFangApp.xcworkspace`（含 OpenIMSDK 等依赖）。

### 5. 打开并运行

```bash
open DongFangApp.xcworkspace
```

> ⚠️ 务必用 `.xcworkspace` 打开（而非 `.xcodeproj`），否则 Pod 依赖不生效。

在 Xcode 中：
- 选择模拟器（推荐 iPhone 17 Pro）
- 按 `Cmd + R` 运行
- 模拟器启动后 App 自动安装并运行

### 6. 命令行编译与运行（可选）

```bash
# 编译（使用 workspace）
xcodebuild -workspace DongFangApp.xcworkspace \
  -scheme DongFangApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ./build \
  build

# 安装并启动
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/DongFangApp.app
xcrun simctl launch booted com.dongfang.customer
```

## 后端联调

- Debug 环境 BaseURL：`http://localhost:8080/api/v1`
- 模拟器可通过 `localhost` 直接访问本机后端服务（网关 8080）
- Info.plist 已配置 `NSAppTransportSecurity` → `NSAllowsLocalNetworking=true`，允许 HTTP localhost 连接

## 真机调试（可选）

- 需要 Apple Developer 账号
- USB 连接 iPhone，在 Xcode > Signing & Capabilities 配置签名
- 将 `Configuration.swift` 中 baseURL 改为 Mac 局域网 IP（如 `http://192.168.1.100:8080/api/v1`）
- 选择真机设备后 `Cmd + R`

## 功能页面（21 页）

| 模块 | 页面 |
|------|------|
| Home | 首页 |
| Temple | 寺院列表 / 寺院详情 |
| Master | 法师列表 / 法师主页 |
| Booking | 预约下单 |
| Service | 加持 / 开光 / 敬香 / 点灯 / 法事 / 太岁 / 许愿 |
| Diy | DIY手串 / DIY设计 / DIY详情 / DIY下单 |
| Shop | 商城 |
| Chat | 对话列表 / 对话详情 |
| Profile | 我的 |

## 架构说明

- **MVVM**：每个 Feature 含 `View.swift`（UI）+ `ViewModel.swift`（状态与逻辑）
- **网络层**：`APIClient` 基于 URLSession + async/await，统一解包 `{code,message,data}` 响应
- **鉴权**：JWT Token 通过 `AuthStore` 存储于 Keychain
- **设计系统**：深色禅意主题，朱砂红 + 琉璃金配色（Tokens.swift 自动生成）
