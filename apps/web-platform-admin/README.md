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

`build` 会运行共享资源漂移与会话失效检查，再完成类型检查和 Vite 打包。`node_modules` 可用 `npm ci` 恢复，`.vite` 缓存自动重建，输出为 `dist/`。

## 共享资源与入口关系

组件、主题、字体和动效来自 `packages/admin-ui`、`packages/design-tokens`；标识从 `packages/brand` 同步到本 app 的 `public/logos`。浅色为米白/松绿/暖金，深色为深棕/朱砂/暖金，按实际主题切换 Logo。

旧 `web-shop-admin` 仍负责 `/shop/` 地址与旧会话的兼容跳转，不应直接移除。业务页面维护在本项目 `src/commerce`；具体路由以 `src/router` 为准。
