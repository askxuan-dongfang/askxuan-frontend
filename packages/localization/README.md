# 全产品界面语言

支持 `system`、`zh-Hans`、`zh-Hant`，默认跟随系统。按系统首个受支持的中文偏好匹配：显式 Hans/Hant 优先于地区，TW/HK/MO 匹配繁体，其他中文匹配简体；系统没有中文偏好时回退简体。语言与外观独立。

Web 使用 `askxuan-language` localStorage，实时响应 `languagechange` 与 `storage`；被禁用的存储仅影响重启记忆。iOS/Mac 使用 `askxuan.language` UserDefaults，跟随系统时在回到前台和 locale 通知时刷新。偏好是设备/浏览器本地设置，退出登录不清除，不进行账号云同步。

`language.ts` 与 `zh-Hant.json` 是 Web 权威源。H5 是独立 Git 仓库，提交自身镜像，正式构建不依赖父仓新版本。Vue 使用显式 `$t`，React 使用显式文本查表与 `useLanguage`，SwiftUI 使用 `L10n.text`/`lookup` 与 Observation。没有 DOM 改写、运行时全文转码、页面 reload 或语言切换导致的根视图重建。输入值、业务状态码、API payload、用户昵称、聊天/评论原文保持原值；内容标题等仅做目录中已知界面文案查表，未知内容原样显示。

原生聊天 WKWebView 随宿主的当前语言更新；Mac 两个独立 WebKit 数据仓库与菜单通过限定同源主框架的桥接同步。Element Plus 日期与分页由 `ElConfigProvider` 切换 zh-cn/zh-tw。切换不会改变币种、时区、用户业务数据或 AI 已生成内容。

## 文案维护

1. 新增界面文案必须在显示处调用本包接口，业务值和用户原文不调用。动态文案使用模板并保留插值原值。
2. macOS 开发机先安装 `apps/web-platform-admin` 与本目录依赖，运行 `node packages/localization/scripts/generate.mjs`。生成器使用 SwiftSyntax 提取原生字串、TypeScript/Vue 解析器提取 Web 字串，再以固定版本 [OpenCC](https://github.com/nk2028/opencc-js) 生成简繁字形映射。生成结果应检查多义字和业务术语；词条可在生成器的覆盖项中维护。
3. 一并提交权威字典与 H5 镜像。构建机器只消费已提交资源，无需 Swift 或 OpenCC。新增第三种语言需要产品确认并扩充枚举，不能随意加入英文选项。
4. `node --test packages/localization/language.test.mjs` 验证解析、持久化、系统事件、跨标签和原文边界。各端仍需构建与界面验收。
