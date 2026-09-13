# 问玄东方 · 统一运营后台

当前产品版本：`0.0.1`。

当前平台及商城运营业务共用此 Vue 3 管理后台，部署基址 `/admin/`，商城业务位于 `/admin/commerce/*`。可见导航和操作权限由当前账号决定。

## 本地开发

在本目录执行：

```bash
npm ci
npm run dev
```

单独启动默认 `http://localhost:5210/login`；从[前端根目录](../../README.md)执行 `make clients-up` 时改用 `http://127.0.0.1:5175/login`。开发 `/api` 默认代理到 `http://localhost:8080`，可通过进程环境变量 `VITE_DEV_PROXY_TARGET` 调整。

```bash
npm run build
npm run preview
```

`build` 会运行共享资源漂移、会话失效、导航、商城模块结构和旧地址兼容测试，再完成类型检查和 Vite 打包。`node_modules` 可用 `npm ci` 恢复，`.vite` 缓存自动重建，输出为 `dist/`。

## 共享资源与入口关系

组件、主题、字体和动效来自 `packages/admin-ui`、`packages/design-tokens`；标识从 `packages/brand` 同步到本 app 的 `public/logos`。浅色为米白/松绿/暖金，深色为深棕/朱砂/暖金，按实际主题切换 Logo。

商城全部业务页面维护在本项目 `src/commerce`，17 条路由与 8 个 API 模块使用同一布局、会话和构建；寺院管理台仍为独立应用。旧商城应用已移除。

`src/compat/legacy-shop.mjs` 是 `/shop/*` 的唯一兼容源。每次构建输出自包含的 `dist/legacy/shop/index.html`，无需 Vue、字体、外部脚本或第二个构建。生产环境必须将旧 `/shop` 和 `/shop/*` 服务到该 HTML，保留原请求路径、查询与片段；不要先重定向到 `/admin`，否则会丢失旧页面意图。脚本会跳转至同源 `/admin/commerce/*` 或 `/admin/login`，迁移旧会话且优先保留已经存在的统一后台身份。

开发和 preview 服务器自带 `/shop/*` 兼容处理。例如开发访问 `http://localhost:5210/shop/orders/9` 后进入同端口 `/commerce/orders/9`。生产兼容页面始终与本次 admin dist 同步发布，不能复用独立商城旧目录。

```bash
npm run test:architecture
npm run test:compat
```

结构检查覆盖当前商城路由、API 模块、平台路由和跨应用依赖边界；纯浏览器兼容逻辑测试覆盖深链、查询/片段、登录跳转、身份优先级和存储失败。实际页面回归在 `e2e/tests/unified-admin.spec.ts`，使用两个后台构建产物与本地假数据服务。
