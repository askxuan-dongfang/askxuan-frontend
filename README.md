# 问玄东方前端 0.0.1

本仓库维护信众/法师原生 iOS、统一运营与寺院 Web 后台、商城兼容入口及共享视觉资源。`apps/web-h5` 位于本目录内，但属于独立 Git 仓库，须单独查看状态和提交。

## 当前入口

| 目录 | 当前用途 | 入口 |
| --- | --- | --- |
| [web-h5](apps/web-h5/README.md) | 信众与法师 H5 | `/c/*`、`/m/*`；独立仓库 `main` |
| [web-platform-admin](apps/web-platform-admin/README.md) | 统一运营后台，含商城业务与权限控制 | 部署 `/admin/`，商城 `/admin/commerce/*` |
| [web-temple-admin](apps/web-temple-admin/README.md) | 寺院机构后台 | 部署 `/temple/` |
| [web-shop-admin](apps/web-shop-admin/README.md) | 旧商城地址兼容 | 部署 `/shop/`，映射并跳转到统一后台 |
| [ios-customer](apps/ios-customer/README.md) | 信众原生 SwiftUI App | `DongFangApp.xcworkspace` |
| [ios-master](apps/ios-master/README.md) | 法师原生 SwiftUI App | `MasterApp.xcworkspace` |

产品能力与验收边界以[当前产品说明](../askXuan-docs/docs/product/产品现状与能力边界.md)和[四册手册](../askXuan-docs/docs/guides/手册目录.md)为准，目录存在不代表所有客户端功能完全一致或已上架。

## Web 开发与恢复依赖

Web CI 使用 Node.js 22；每个 app 有自己的 `package.json` 与锁文件，本仓没有一次安装所有 app 的根依赖命令。首次使用或清理了 `node_modules` 后，在需要的 app 目录执行 `npm ci`。

从本仓根目录启动三个管理入口：

```bash
npm --prefix apps/web-platform-admin ci
npm --prefix apps/web-temple-admin ci
npm --prefix apps/web-shop-admin ci
make clients-up
```

脚本固定端口：寺院 `5173`、商城兼容 `5174`、统一后台 `5175`；兼容入口跳转到同批启动的统一后台。只运行某个 app 的 `npm run dev` 时，以其 README / Vite 配置端口为准，不能混用两套端口。

```bash
make clients-check
make clients-logs
make clients-down
```

`make clients-up` 不启动 H5，也不自动运行 iOS。`OPEN_IOS=1 make clients-up` 可同时打开现有两个 workspace。

H5 与管理端同时开发时单独选择空闲端口，例如：

```bash
cd apps/web-h5
npm ci
npm run dev -- --host 127.0.0.1 --port 5186
```

信众入口 `http://127.0.0.1:5186/c`，法师入口 `/m`。后端联调按[后端 README](../askXuan-backend/README.md)准备网关；前端页面可打开不等于接口已可用。

## iOS 与构建缓存

日常打开两个 `.xcworkspace`。清理 `apps/ios-*/build` 只会失去编译产物，重新在 Xcode Build/Run 或使用对应 README 的 `xcodebuild` 命令即可恢复。`Pods` 和 `Podfile.lock` 应保留；依赖缺失时在对应 app 内运行 `pod install`。不要把清缓存变成重新生成工程或更改签名。

Vite `.vite` 缓存在下次开发启动时重建；npm 下载缓存缺失时可能重新联网下载。`e2e`、`packages/mock-server` 也各自按需 `npm ci`。

`make clients-ios-smoke` 会真实构建、运行模拟器并写入 `e2e/artifacts/ios/`，不是无副作用的状态检查。

## 视觉与品牌权威源

- [packages/brand](packages/brand/README.md)：六身份标识、浅深 Logo、favicon 与 AppIcon；`generate.mjs` 是可编辑母版，`assets/` 为正式导出。
- [packages/design-tokens](packages/design-tokens/README.md)：`tokens.json`、字体、字号与动效令牌；[packages/admin-ui](packages/admin-ui/README.md) 提供管理端共享组件与主题。
- Web/iOS 构建使用已同步的应用资源；H5 的 `src/assets/brand`、后台 `public/logos`、原生 Asset Catalog 均须从正式母包同步。正式构建只依赖本仓及独立 H5 已同步的当前资源。
- 浅色使用米白、松绿与暖金，深色使用深棕、朱砂与暖金；字体、动效与各端差异见[视觉设计与交互手册](../askXuan-docs/docs/guides/视觉设计与交互手册.md)。

本仓与独立 H5 的 `VERSION` 均为 `0.0.1`，一方包与原生产品版本保持一致；iOS 构建号单独管理。本仓日常分支为 `master`；H5 为 `main`。Git 推送、Web/ECS 发布和 iOS 分发是不同动作，更新文档不代表重新部署。
