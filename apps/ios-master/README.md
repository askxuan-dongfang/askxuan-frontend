# 问玄东方 · 法师工作台 iOS

当前产品版本：`0.0.1`。

当前法师原生 App，使用 Swift、SwiftUI、MVVM 与 CocoaPods。入口为 `MasterApp.xcworkspace`，提供工作台、预约、消息、加持任务、日程、收益和资料等功能；具体入口以 `MasterApp/Features` 为准。

- Bundle ID：`com.askxuan.master`。
- 当前工程最低部署目标：iOS 17.0。
- 源码包含 iOS 26 `glassEffect` 可用性分支，构建需要支持这些 API 的 Xcode / SDK；低版本运行时使用回退。
- 使用具有法师角色的账号登录；业务身份和权限由后端会话确认，不由页面参数授予。

## 打开与构建

在本目录操作，Pods 缺失时先执行 `pod install`，保留 `Podfile.lock`，然后打开已有 workspace：

```bash
pod install
open MasterApp.xcworkspace
```

```bash
xcodebuild -workspace MasterApp.xcworkspace \
  -scheme MasterApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO build
```

清理 `build/` 后重新构建即可。需要运行时在 Xcode 选择本机实际安装的模拟器；真机运行另需签名与设备配置，不能把无签名构建视为实机验收。

`project.yml` 是 XcodeGen 工程配置。只有主动更新工程时才需要 `xcodegen generate`，并核对差异、API/OpenIM 构建设置与 CocoaPods 集成；恢复缓存不需要重建 `.xcodeproj`。

## 后端联调

`App/Configuration.swift` 优先读取 Info.plist 的 `ASKXUAN_API_BASE_URL`、`OPENIM_API_URL`、`OPENIM_WS_URL`。当前已提交工程的 Debug/Release 构建设置均使用 `https://101.96.228.71` 下的 API/OpenIM 路径，并非统一默认 localhost。

本地联调应在构建设置中调整地址，并核对产物 Info.plist；主 API 带 `/api/v1`。后端准备与接口契约分别见[后端 README](../../../askXuan-backend/README.md)及[法师手册](../../../askXuan-docs/docs/guides/manual/法师与后台操作.md)。以实际接口实现为准，不保留已过时的固定页面数或手抄路由清单。

## 视觉与资源

当前支持浅色米白/松绿/暖金与深色深棕/朱砂/暖金；标题为 AskXuan Serif，正文与控制项为系统语义字体，支持 Dynamic Type。共用母版位于 `packages/design-tokens`、`packages/brand`，本端文字与交互实现位于 `DesignSystem`。

`Resources/Assets.xcassets/brand-logo` 和 `AppIcon` 为已同步资源，随 App 打包。`Tokens.swift` 已包含原生扩展，不能被旧基础生成示例直接覆盖。构建、真机功能验收、推送配置和 App 分发需分别核验。
