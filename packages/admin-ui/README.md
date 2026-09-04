# @askxuan/admin-ui

三个 Vue 管理台的统一作业界面源，包括响应式主题和公共组件。

## 组件源

- `PageHeader.vue`：统一页头及 `actions` / `extra` / 默认操作插槽。
- `StatusTag.vue`：统一读取 `@askxuan/domain-status`，兼容业务域和旧 `kind` 名称。
- `StatCard.vue`：统一指标卡、金额前后缀、趋势和图标语义。
- `DataTable.vue`：统一表格、分页、空态、排序和内部横向滚动。
- `ImageUploader.vue`：统一单图/多图、上传校验、预览和 URL 回填。

三个应用目前保持独立依赖树，`vue-tsc` 无法稳定检查跨根目录 SFC，因此本目录是唯一人工维护源，应用内文件为生成镜像。修改组件后执行：

```bash
node scripts/sync-admin-ui-components.mjs --write
```

每个管理台的 `prebuild` 会执行 `--check`，镜像漂移时构建直接失败，避免三个同名组件再次产生不同 API。

三个 Vue 管理台共用的界面基础层。当前先集中管理浅色作业主题、响应式壳层、页面容器和 Element Plus 适配；组件会在 P0 页面迁移过程中逐步收敛到本包。

各应用从源码相对路径引入 `styles/index.css`，避免现阶段三个独立前端工程因没有根 workspace 而复制样式文件。
