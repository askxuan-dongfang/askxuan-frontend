# 问玄管理台 · Mac

一个 macOS 应用，切换运营后台与寺院后台。最低 macOS 14；页面由现有生产站点提供，Web 的页面、功能、主题、响应式布局与动画发布后直接同步。

- `⌘1` 运营后台、`⌘2` 寺院后台；两个后台使用独立持久 WebKit 数据仓库，分别登录，切换保留当前页面。
- `⌘[` / `⌘]` 后退/前进，`⌘R` 刷新，`⇧⌘H` 返回首页。
- `⌘+` / `⌘-` / `⌘0` 调整缩放，`⌘P` 打印。
- 文件选择使用系统打开面板；下载和报表导出使用系统保存面板。网页弹窗、取消、错误重试均有原生承接。
- HTTPS 走系统证书验证，未放宽证书校验。管理员账号、验证码、权限与两个 Web 后台一致。

构建：

```sh
xcodegen generate --spec apps/macos-admin/project.yml
bash apps/macos-admin/build.sh /absolute/output-directory
```

构建时使用临时输出目录；验收后将 App、ZIP、签名记录和必要测试结果归入工作区 `artifacts/native/YYYY-MM/<task>-YYYYMMDD/`，并更新 `artifacts/native/README.md`。不要在 `artifacts/` 顶层新建日期目录。现有交付位于 `artifacts/native/2026-10/native-parity-mac-20261015/`；完整归档规则见文档仓库的 `docs/guides/本地项目目录与维护.md`。

生产地址通过工程 `INFOPLIST_KEY_ASKXUAN_WEB_BASE_URL` 构建设置配置。Debug 构建可使用仅允许 localhost / 127.0.0.1 的 `ASKXUAN_MAC_TEST_ORIGIN` 环境变量做本地测试；Release 不读取该测试地址。

构建脚本默认生成 Universal（Apple Silicon + Intel）本机签名测试包。正式分发需要 Developer ID Application 证书及 Apple 公证；本机 ad-hoc 签名不等于公证，也不等于 App Store 发布。不要以关闭 Gatekeeper 或绕过 TLS 作为安装/连接步骤。

实现依据：[Apple WKWebsiteDataStore 文档](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)。
