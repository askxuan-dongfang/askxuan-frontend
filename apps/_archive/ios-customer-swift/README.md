# 问玄东方 C端 iOS App

> SwiftUI + MVVM + async/await，最低支持 iOS 16，深色禅意国潮风格。

## 工程结构

```
apps/ios-customer/
├── project.yml                       # XcodeGen 配置
├── README.md
└── DongFangApp/
    ├── App/
    │   ├── DongFangApp.swift          # @main 入口
    │   ├── Configuration.swift        # 环境与配置
    │   └── MainTabView.swift          # 主 TabView 容器
    ├── Info.plist
    ├── Core/
    │   └── Network/
    │       ├── APIResponse.swift
    │       ├── Endpoint.swift
    │       └── APIClient.swift
    ├── DesignSystem/
    │   ├── Tokens.swift               # Design Token（色彩/字体/圆角/间距）
    │   └── Components/                # 通用组件
    ├── Models/                        # 数据模型
    └── Features/                      # 功能模块（Home/Temple/Master/Booking）
```

## 环境准备

1. macOS + Xcode 15+（需从 Mac App Store 安装）
2. 安装 XcodeGen：

```bash
brew install xcodegen
```

3. 安装 Node.js（用于运行 Mock Server）

## 生成 Xcode 工程

在 `apps/ios-customer/` 目录下执行：

```bash
cd /Users/gaofeng/develop/DongFang/apps/ios-customer
xcodegen generate
```

执行后会生成 `DongFangApp.xcodeproj`，双击即可用 Xcode 打开：

```bash
open DongFangApp.xcodeproj
```

## 启动 Mock Server

C端 App 在 DEBUG 模式下默认连接 `http://localhost:3001/api/v1`，需要先启动 Mock Server：

```bash
cd /Users/gaofeng/develop/DongFang/packages/mock-server
npm install
npm run dev
```

Mock Server 启动后控制台会输出：

```
[问玄东方 Mock Server] API 基路径：http://localhost:3001/api/v1
```

> 模拟器可直接用 `localhost` 访问 Mac 本机服务；真机联调需把 `Configuration.swift` 中的 BaseURL 改为 Mac 局域网 IP。

## 运行 App

1. 在 Xcode 顶部选择模拟器（推荐 iPhone 15 Pro）
2. 按 `Cmd + R` 编译并运行
3. App 启动后首页会自动加载 Banner、热门寺院、热门师傅数据

## MVP-1 范围

本次工程覆盖首页 + 寺院 + 师傅 + 预约 + 导航核心闭环：

- **首页**：Banner 轮播、找寺院/找师傅双入口、热门服务 8 宫格、热门寺院/师傅横向滚动
- **寺院**：列表（教派筛选）+ 详情（Hero 大图 + 4 Tab）
- **师傅**：列表（教派筛选）+ 主页（背景区 + 5 Tab + 底部双按钮）
- **预约**：服务选择 + 日期时段 + 功德金 + 备注 + 提交
- **导航**：5 Tab 容器（首页/对话/AI问事/商城/我的），首页走 NavigationStack

## 设计规范

- 颜色全部使用 `DesignSystem/Tokens.swift` 中的 Token（如 `Color.bgPrimary`、`Color.brandDefault`、`Color.accentDefault`）
- 字体：标题 Noto Serif SC，正文 Noto Sans SC
- 组件：DFCard / DFPrimaryButton / DFSecondaryButton / DFTagPill / DFTopNavBar / DFBottomTabBar / DFBannerCarousel
