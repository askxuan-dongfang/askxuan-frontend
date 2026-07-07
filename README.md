# 问玄东方前端启动

本目录包含五个主要客户端入口：

- C 端 iOS App：`apps/ios-customer/DongFangApp.xcworkspace`
- 大师端 iOS App：`apps/ios-master/MasterApp.xcworkspace`
- 寺院管理台 Web：`http://127.0.0.1:5173/login`
- 商城管理台 Web：`http://127.0.0.1:5174/login`
- 平台管理台 Web：`http://127.0.0.1:5175/login`

## 一键启动

```bash
make clients-up
```

该命令会后台启动三个 Web 管理端，并输出两个 iOS workspace 路径。需要自动打开 Xcode：

```bash
OPEN_IOS=1 make clients-up
```

## 检查与停止

```bash
make clients-check
make clients-down
make clients-logs
```

## iOS 冒烟

后端网关可用后，可以运行两个原生 iOS App 的模拟器冒烟截图：

```bash
make clients-ios-smoke
```

截图输出到 `e2e/artifacts/ios/`。
