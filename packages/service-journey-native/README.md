# 原生服务进度与回执

信众端：主页当前服务入口、个人页固定入口、集中进度／回执档案、心愿、时间线、私有图片／视频、回执核对与补充申请、确认归档。
大师端：工作台入口、状态筛选、接单、开始执行、阶段图片／视频、最终回执。最终完成由信众核对确认，保留原预约详情。

三份 Swift 文件由两端 XcodeGen 工程直接引用；各 App 的 `JourneyHost` 提供角色与原订单详情入口。网络统一使用现有 APIClient 的会话恢复逻辑。上传最多 8 个文件、单文件 20 MB，媒体按需加载，视频不自动播放；确认完成仅一次轻反馈，尊重系统减少动态效果设置。

## 构建

从仓库根目录，分别进入 `apps/ios-customer`、`apps/ios-master`，执行 `xcodegen generate` 和 `pod install`，然后打开对应 `.xcworkspace`（不是 `.xcodeproj`）。要求 Xcode、iOS 17+ SDK、XcodeGen 与 CocoaPods。项目保留现有线上 API/OpenIM 配置；签名使用开发者自己的配置。

示例：

```sh
xcodebuild -workspace apps/ios-customer/DongFangApp.xcworkspace -scheme DongFangApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apps/ios-master/MasterApp.xcworkspace -scheme MasterApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

仅 Debug 支持 `ASKXUAN_JOURNEY_API_URL`（限定 localhost/127.0.0.1）及 `ASKXUAN_JOURNEY_BOOKING`，用于配合现有 smoke-token 参数验证隔离测试订单。Release 不接受这些测试覆盖项。未包含任何测试凭据。
