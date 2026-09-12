# 问玄东方 · 寺院管理台

当前产品版本：`0.0.1`。

寺院机构使用的 Web 后台，基于 Vue 3、TypeScript、Vite、Element Plus、Pinia 和 ECharts，部署基址 `/temple/`。机构信息、人员、服务、预约和加持任务按寺院权限组织；它与统一运营后台保持不同的工作入口。

## 启动与依赖恢复

在本目录执行：

```bash
npm ci
npm run dev
```

单独启动默认 `http://localhost:5174/login`。从[前端根目录](../../README.md)执行 `make clients-up` 时固定使用 `http://127.0.0.1:5173/login`。

开发 `/api` 默认代理到 `http://localhost:8080`，可通过进程环境变量 `VITE_DEV_PROXY_TARGET` 调整。API 统一响应为 `{ code: 0, message, data }`；后端未启动时页面可打开不代表数据可用。

```bash
npm run build
npm run preview
```

依赖清理后用 `npm ci` 恢复；Vite 缓存自动重建，生产包输出 `dist/`。构建前会生成基础 Web token 并检查共享组件、字体、动效及会话失效处理。

## 当前视觉与源码

- 主题：浅色米白/松绿/暖金，深色深棕/朱砂/暖金；不再固定为“浅内容配深侧栏”。
- 标题使用随应用提供的 AskXuan Serif，正文、表单和按钮使用平台无衬线。
- 共同源：`packages/design-tokens/tokens.json`、`packages/admin-ui` 和 `packages/brand`；本端 `public/logos` 是已同步的品牌资源。
- `src/api` 封装接口；`src/router` 与 `src/stores` 维护路由/会话；`src/layouts`、`src/views` 和 `src/styles` 维护页面与样式。

当前规则详见[视觉设计与交互手册](../../../askXuan-docs/docs/guides/视觉设计与交互手册.md)；此链接适用于标准 DongFang 工作区布局。
