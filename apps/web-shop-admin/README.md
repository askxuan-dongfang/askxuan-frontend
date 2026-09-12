# 问玄东方 · 商城兼容入口

当前产品版本：`0.0.1`。

此项目当前是旧商城地址的兼容入口。`/shop/*` 映射到统一后台 `/admin/commerce/*` 等对应路径，保留查询参数、hash 和安全的站内重定向；已有统一后台会话优先，旧商城会话按兼容规则迁移。

商城业务维护在 `../web-platform-admin/src/commerce`。本目录仍被 Web CI、部署脚本、共享组件检查和旧地址访问使用，不能因不再独立展示业务界面而整目录删除。

## 本地开发

先启动统一后台，再在本目录执行：

```bash
npm ci
npm run dev
```

单独启动默认端口 `5175`，默认跳转到 `http://localhost:5210/` 的统一后台。统一后台在其他端口时，用进程环境变量 `VITE_UNIFIED_ADMIN_URL` 指定其带末尾 `/` 的地址。

[根目录](../../README.md)的 `make clients-up` 会固定兼容入口为 `5174`、统一后台为 `5175`，并自动设置跳转目标；这与各 app 单独启动的默认端口不同。

```bash
npm run build
npm run preview
```

生产基址为 `/shop/`，输出 `dist/`。Logo/favicon 来自共享品牌母包的应用副本 `public/logos`；保留这些兼容资源不表示存在第三套独立运营后台。依赖被清理后 `npm ci` 可恢复，`.vite` 缓存会自动重建。
