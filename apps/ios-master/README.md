# 问玄东方 · 法师工作台 iOS App（P03）

基于原生 Swift + SwiftUI + MVVM + XcodeGen 构建的法师端工作台 App，共 14 个页面。

- Bundle ID：`com.askxuan.master`
- 最低系统：iOS 16.0
- 架构：MVVM（View + @MainActor ViewModel + APIClient）
- 网络层：URLSession + async/await，JWT 自动注入，统一解包 `{code,message,data}`
- 设计系统：复用问玄东方 Design Tokens（深色禅意主题）

## 目录结构

```
ios-master/
├── MasterApp/
│   ├── App/                     Configuration.swift, MasterApp.swift, MainTabView.swift
│   ├── Core/Network/            APIClient.swift, APIResponse.swift, Endpoint.swift, AuthStore.swift
│   ├── DesignSystem/            Tokens.swift, Components/(PrimaryButton, Card, LoadingView, EmptyState, StatusBadge, StatCard)
│   ├── Features/                7 模块 14 页
│   │   ├── Workspace/           WorkspaceView, LoginView
│   │   ├── Booking/             BookingsView, BookingDetailView
│   │   ├── Blessing/            BlessingTasksView, BlessingTaskDetailView
│   │   ├── Calendar/            CalendarView
│   │   ├── Chat/                ChatView, MessagesView
│   │   ├── Earnings/            EarningsView, PricingView
│   │   └── Profile/             ProfileView, ProfileEditView, ReviewsView, SettingsView
│   ├── Models/                  Booking, BlessingTask, MasterProfile, Earnings, Withdrawal, Message, Review
│   ├── Resources/               Info.plist（NSAllowsLocalNetworking=true）
│   └── Utils/                   DateFormatter.swift, JSONHelper.swift
├── project.yml
└── README.md
```

## 14 个页面

| # | 模块 | 页面 | 说明 |
|---|------|------|------|
| 1 | Workspace | WorkspaceView | 工作台首页（今日待办/统计） |
| 2 | Workspace | LoginView | 法师登录 |
| 3 | Booking | BookingsView | 预约列表 |
| 4 | Booking | BookingDetailView | 预约详情（确认/接单） |
| 5 | Blessing | BlessingTasksView | 加持任务列表 |
| 6 | Blessing | BlessingTaskDetailView | 加持任务详情 |
| 7 | Calendar | CalendarView | 日程日历 |
| 8 | Chat | ChatView | 对话 |
| 9 | Chat | MessagesView | 消息列表 |
| 10 | Earnings | EarningsView | 收益概览（含提现入口） |
| 11 | Earnings | PricingView | 定价管理 |
| 12 | Profile | ProfileView | 法师主页 |
| 13 | Profile | ProfileEditView | 资料编辑 |
| 14 | Profile | ReviewsView | 评价管理 |

（SettingsView 作为第 15 个辅助页面，并入 Profile 模块。）

## 后端 API 映射

BaseURL：`http://localhost:8080/api/v1`（Debug），管理台路径前缀 `/admin`。法师身份由 JWT Claims 解析获得，**禁止 URL 传参**。

| 功能 | 方法 | 路径（相对 baseURL） |
|------|------|----------------------|
| 登录 | POST | `auth/admin/login` |
| 预约列表 | GET | `admin/masters/bookings` |
| 预约详情 | GET | `admin/masters/bookings/{id}` |
| 确认预约 | PUT | `admin/masters/bookings/{id}/confirm` |
| 完成预约 | PUT | `admin/masters/bookings/{id}/complete` |
| 加持任务列表 | GET | `admin/masters/blessing-tasks` |
| 加持任务详情 | GET | `admin/masters/blessing-tasks/{id}` |
| 接单/开始/完成/拒绝 | PUT | `admin/masters/blessing-tasks/{id}/{accept\|start\|complete\|reject}` |
| 日程 | GET/PUT | `admin/masters/schedules` |
| 收益概览 | GET | `admin/masters/earnings/summary` |
| 收益明细 | GET | `admin/masters/earnings/details` |
| 法师资料 | GET/PUT | `admin/masters/profile` |
| 消息列表 | GET | `admin/messages/master` |
| 评价列表 | GET | `admin/masters/reviews` |
| 提现申请 | POST | `admin/finance/withdrawals/apply` |

## Xcode 运行指南

### 1. 启动后端基础设施

```bash
cd /Users/gaofeng/develop/DongFang/askXuan-backend
docker compose up -d        # 启动 MySQL/Redis/RabbitMQ/MinIO/etcd/MongoDB/Kafka/Zookeeper
make db-init                # 初始化数据库（首次）
make start-all              # 启动 18 个微服务 + 1 网关
```

验证网关可达：`curl http://localhost:8080/api/v1/health`

### 2. 安装 XcodeGen 和 CocoaPods

```bash
brew install xcodegen cocoapods
```

### 3. 生成 Xcode 工程

```bash
cd /Users/gaofeng/develop/DongFang/askXuan-frontend/apps/ios-master
xcodegen generate
```

执行后会生成 `MasterApp.xcodeproj`。

### 4. 安装 Pod 依赖

```bash
pod install
```

执行后会生成 `MasterApp.xcworkspace`（含 OpenIMSDK 等依赖）。

### 5. 打开并运行

```bash
open MasterApp.xcworkspace
```

> ⚠️ 务必用 `.xcworkspace` 打开（而非 `.xcodeproj`），否则 Pod 依赖不生效。

- 选择模拟器（推荐 iPhone 17 Pro），点击 ▶ Run（或 `Cmd + R`）。
- Debug 环境默认连接本地后端 `http://localhost:8080/api/v1`。
- Info.plist 已配置 `NSAllowsLocalNetworking=true`，允许 HTTP localhost 连接。

### 6. 命令行编译与运行（可选）

```bash
# 编译（使用 workspace）
xcodebuild -workspace MasterApp.xcworkspace \
  -scheme MasterApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ./build \
  build

# 安装并启动
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/MasterApp.app
xcrun simctl launch booted com.askxuan.master
```

### 7. 登录说明

使用后端管理台账号（role=master）登录，账号 + 密码方式。登录成功后 JWT 存入 Keychain（key=`df_master_token`），法师 ID 从 JWT Claims 解析。

### 8. 真机调试（可选）

- 需要 Apple Developer 账号
- USB 连接 iPhone，在 Xcode > Signing & Capabilities 配置签名
- 将 `Configuration.swift` 中 baseURL 改为 Mac 局域网 IP（如 `http://192.168.1.100:8080/api/v1`）
- 选择真机设备后 `Cmd + R`

## 关键约束

- booking 状态 `snake_case`：`pending/confirmed/in_progress/completed/cancelled/reviewed`，其中 `reviewed/cancelled` 为终态。
- 法师 ID 从 JWT 获取，禁止 URL 传参。
- `Info.plist` 配置 `NSAllowsLocalNetworking=true`，允许 HTTP 本地联调。
- 提现走 `POST /admin/finance/withdrawals/apply`（JWT 保护路由）。
