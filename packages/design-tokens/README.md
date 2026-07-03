# @dongfang/design-tokens

问玄东方App 跨端共享 Design Token 系统。以单一数据源 `tokens.json` 为基准，自动生成 iOS（Swift）、Web（CSS / Tailwind）与小程序（uni.scss / JS）各端所需的样式常量，确保多端色彩、字体、圆角、间距完全一致。

## 目录结构

```
packages/design-tokens/
├── tokens.json              # 统一 Design Token 数据源（唯一编辑入口）
├── package.json
├── scripts/
│   ├── gen-ios-tokens.js    # 生成 Swift
│   ├── gen-web-tokens.js    # 生成 CSS + Tailwind
│   └── gen-mp-tokens.js     # 生成 uni.scss + JS
└── dist/                    # 生成产物（自动创建，请勿手动编辑）
    ├── ios/Tokens.swift
    ├── web/tokens.css
    ├── web/tailwind-tokens.js
    ├── mp/uni.scss
    └── mp/tokens.js
```

## 数据源

`tokens.json` 的色值取自 `问玄东方App/colors_and_type.css`，包含：

- 21 个色彩令牌：背景（bg）、品牌（brand）、点缀金（accent）、朱砂（cinnabar）、文本（text）、边框（border）、状态（state）
- 衬线 / 无衬线字体栈
- 圆角：sm / md / lg / xl
- 导航间距：navTop / navBottom

## 运行生成脚本

```bash
cd packages/design-tokens

# 单端生成
npm run gen:ios
npm run gen:web
npm run gen:mp

# 一键生成全部
npm run gen:all
# 或
npm run build
```

所有脚本仅依赖 Node 内置 `fs` / `path` 模块，无需安装任何第三方包。

## 各端接入

### iOS（Swift / SwiftUI）

将 `dist/ios/Tokens.swift` 拖入 Xcode 工程。使用示例：

```swift
import SwiftUI

struct CardView: View {
    var body: some View {
        Text("问玄东方")
            .foregroundColor(.textPrimary)
            .padding(16)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
    }
}
```

可用常量：

- 颜色：`Color.bgPrimary`、`Color.brandDefault`、`Color.brandLight`、`Color.accentDefault`、`Color.cinnabarDefault`、`Color.textPrimary`、`Color.borderDefault`、`Color.stateSuccess` …（含 light/dark/strong/divider 等全部变体）
- 字体：`AppFont.serif`、`AppFont.sans`（字体名数组）
- 圆角：`AppRadius.sm/md/lg/xl`（CGFloat）
- 间距：`AppSpacing.navTop/navBottom`（CGFloat）

边框等带透明度的颜色使用 `Color(.sRGB, red:green:blue:opacity:)` 构造，无需手动换算。

### Web

将 `dist/web/tokens.css` 引入项目根样式：

```css
@import "./tokens.css";
```

使用 CSS 变量：

```css
.card {
  background: var(--color-bg-secondary);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  color: var(--color-text-primary);
}
```

> `default` 变体同时输出短别名，例如 `--color-brand-default` 与 `--color-brand` 指向同一色值，与原 `colors_and_type.css` 兼容。

Tailwind 接入（`tailwind.config.js`）：

```js
const tokens = require("./dist/web/tailwind-tokens");

module.exports = {
  theme: {
    extend: tokens,
  },
};
```

随后即可使用 `bg-bg-secondary`、`text-text-primary`、`border-border`、`rounded-lg`、`font-serif` 等类名。

### 小程序（uni-app）

将 `dist/mp/uni.scss` 配置为 uni-app 的 `uni.scss`（或在项目 `uni.scss` 中 `@import`）。使用 SCSS 变量：

```scss
.card {
  background: $color-bg-secondary;
  border: 1rpx solid $color-border;
  border-radius: $radius-lg;
  color: $color-text-primary;
}
```

JS 端使用 `dist/mp/tokens.js`：

```js
const tokens = require("./dist/mp/tokens");

Page({
  data: {
    brandColor: tokens.color.brand.default, // 结构化
    flatBrand: tokens.flat.brand,           // 扁平化
  },
});
```

## 维护说明

- 修改令牌请编辑 `tokens.json`，再运行 `npm run gen:all` 重新生成各端产物。
- `dist/` 目录为自动生成，请勿手动编辑。
- 色值以 `问玄东方App/colors_and_type.css` 为权威来源，保持完全一致。
