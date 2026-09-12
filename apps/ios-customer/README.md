# 问玄东方 · 信众 iOS

当前产品版本：`0.0.1`。

当前信众原生 App，使用 Swift、SwiftUI、MVVM 与 CocoaPods。入口为 `DongFangApp.xcworkspace`。

- Bundle ID：`com.dongfang.customer`。
- 当前工程最低部署目标：iOS 17.0。
- 源码包含 iOS 26 `glassEffect` 的可用性分支，构建需要支持这些 API 的 Xcode / SDK；低版本运行时回退由源码处理。
- 页面、接口与状态以 `DongFangApp/Features`、`Core/Network` 和[产品手册](../../../askXuan-docs/docs/guides/手册目录.md)为准，不固定宣称页面总数。

## 打开与构建

在本目录操作；已有工程日常直接打开 workspace。Pods 缺失时先执行 `pod install`，并保留 `Podfile.lock`：

```bash
pod install
open DongFangApp.xcworkspace
```

使用已安装的 iOS Simulator SDK 做命令行构建：

```bash
xcodebuild -workspace DongFangApp.xcworkspace \
  -scheme DongFangApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO build
```

`build/` 清理后由上述命令或 Xcode Build/Run 重建。构建完成不等于已在模拟器或真机运行；运行时选择本机实际安装的设备。

`project.yml` 提供 XcodeGen 配置。仅在有意更新工程时使用 `xcodegen generate`，随后核对生成差异及 CocoaPods 集成；日常恢复构建缓存不需要重新生成工程。当前已提交 `.xcodeproj` 还含 API/OpenIM 构建设置，不能假设重新生成后完全等价。

## 后端联调

`App/Configuration.swift` 从 Info.plist 读取 `ASKXUAN_API_BASE_URL`、`OPENIM_API_URL`、`OPENIM_WS_URL`。当前 `.xcodeproj` 的 Debug/Release 构建设置均指向 `https://101.96.228.71` 下的 API/OpenIM 路径，不能笼统按“Debug 默认本机”使用。

本地或真机联调时在构建设置中调整这三个地址，并核对产物 Info.plist；主 API 包含 `/api/v1`。模拟器可访问本机 localhost，真机应使用可达的局域网地址。网关和即时通信准备方法见[后端 README](../../../askXuan-backend/README.md)。

真机安装需要配置签名和设备；推送、音视频及完整业务流程仍需对应设备验收。网站部署不代表原生 App 已分发或上架。

## 视觉与资源

`DesignSystem/Tokens.swift` 维护本端语义色与 Dynamic Type 文字角色，支持浅色米白松绿和深色深棕朱砂。公共设计数据来自 `packages/design-tokens`，共享衬线 TTF 通过工程资源引用；不要用基础生成示例覆盖现有扩展的 `Tokens.swift`。

登录标识与 DIY 标识位于 `Resources/Assets.xcassets` 的 `brand-logo` / `brand-atelier`，应用图标为 `AppIcon`，均从 `packages/brand` 同步。构建使用当前 Asset Catalog 中的已同步资源。
