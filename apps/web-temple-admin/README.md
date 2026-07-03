# 问玄东方 · 寺院管理台 (web-temple-admin)

寺院管理员使用的 Web 后台，基于 Vue 3 + TypeScript + Vite + Element Plus 构建。

## 技术栈

- **Vue 3.4** Composition API（`<script setup lang="ts">`）
- **Vite 5** 构建工具
- **Element Plus** 组件库（按需自动导入）
- **Tailwind CSS** 原子化工具类（引入 design-tokens）
- **Pinia** 状态管理
- **Vue Router 4** 路由
- **ECharts 5** 数据可视化
- **Axios** HTTP 客户端

## 目录结构

```
src/
├── api/            # 接口封装（axios 实例 + 各模块接口）
├── layouts/        # 布局组件（左侧菜单 + 顶栏）
├── router/         # 路由定义与守卫
├── stores/         # Pinia 状态（auth）
├── styles/         # 全局样式（tokens + tailwind + 禅意主题）
├── types/          # TypeScript 类型定义
├── utils/          # 工具函数（格式化、状态映射）
└── views/          # 页面视图
```

## 快速开始

```bash
# 安装依赖
npm install

# 启动开发服务器（默认端口 5174，代理 /api → localhost:3001）
npm run dev

# 构建生产包
npm run build

# 预览构建产物
npm run preview
```

## 设计规范

- 主品牌色（朱砂红）：`#C45A3C`
- 强调色（琉璃金）：`#C8A96E`
- 内容区采用浅色背景（`#F5F0EB`），侧边栏沿用禅意暗色（`#1C1210`）
- 字体：Noto Serif SC（标题）+ Noto Sans SC（正文）
- Design Tokens 来源：`packages/design-tokens/dist/web/`

## Mock API

开发环境通过 Vite proxy 代理至 `http://localhost:3001/api/v1`，
统一响应格式：`{ code: 0, message: "success", data: ... }`。
