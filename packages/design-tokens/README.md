# @dongfang/design-tokens

当前产品版本：`0.0.1`。

问玄东方共享视觉数据。当前颜色、字体角色、基础间距圆角和 Web 动效以本目录 `tokens.json` 为共同源；各端按交互环境接入，不能理解成 Web px、iOS pt、圆角和动效必须逐项完全相同。

## 当前交付

- `tokens.json`：浅深语义色、字体/字号/字重/行高、基础尺寸与 Web 动效数据。
- `typography.css`、`motion.css`：由仓库根脚本生成的共享 Web 角色。
- `fonts/`：AskXuan Serif TTF、完整 WOFF2、授权和 Web unicode-range 切片。完整 WOFF2 是切片生成源，不是无用下载缓存。
- `dist/web/`：基础 CSS 变量及 Tailwind 数据，由 `scripts/gen-web-tokens.js` 生成。
- `dist/ios/`、`dist/mp/`：基础生成示例；不代表当前原生 App 或小程序已有全部接入。

浅色使用米白、松绿与暖金，深色使用深棕、朱砂与暖金。标题使用 AskXuan Serif 600，正文与控制项使用平台无衬线，金额/统计使用等宽数字。完整品牌图形由[packages/brand](../brand/README.md)负责，不能用字体令牌替代 Logo 资产。

## 生成与检查

以下命令从 `askXuan-frontend` 仓库根目录执行：

```bash
node packages/design-tokens/scripts/gen-web-tokens.js
node scripts/sync-typography.mjs --check
node scripts/sync-motion.mjs --check
```

修改 `tokens.json` 后，移除后两条的 `--check` 才会更新共享输出，并检查各应用差异。管理端 `predev/prebuild` 会生成基础 Web token，构建前检查共享资源漂移；H5 是独立仓库，相关同步副本变化需单独检查其 Git 状态。

字体切片按 `fonts/web/README.md` 的 `scripts/build-web-fonts.py` 流程重建与校验；需要 fontTools/WOFF2 工具环境。`fonts/README.md` 和 `OFL.txt` 记录来源与许可。字体与品牌正式资产已随仓库提交，普通 Web 构建不需要重新制作它们。

## 各端接入边界

- 管理 Web：基础 CSS/Tailwind 令牌叠加 `packages/admin-ui` 的主题、布局和组件。
- H5：`apps/web-h5/src/theme` 是独立仓的应用令牌与共享文字/动效镜像；品牌、字体切片保留应用本地资源，构建无需读取根工作区历史素材。
- 原生 iOS：两个 app 的 `DesignSystem/Tokens.swift` 保留 SwiftUI 语义色、Dynamic Type 与原生尺寸；字体由工程引用共享 TTF。`sync-typography` 只同步指定文字角色，**不要用 `gen:ios` 示例覆盖当前扩展的 `Tokens.swift`**。

Web 动效为 120/200/280/160ms；原生局部反馈目前是 120/200/280ms，系统 sheet/导航保留原生节奏。减少运动、焦点、圆角与响应式差异以[视觉手册](../../../askXuan-docs/docs/guides/视觉设计与交互手册.md)及各端实现为准。

`gen:all` 仍可生成基础示例，但不能替代生产应用的同步脚本、类型检查和页面验收。不要手工修改已生成的 CSS/字体二进制，以当前双主题规则和应用验证结果为准。
