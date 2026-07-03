# @dongfang/mock-server

问玄东方 Mock 数据服务，基于 Node.js + Express + TypeScript，为 C 端 App、寺院管理台、法师工作台、商城管理台、平台管理台提供统一联调数据。

## 数据来源

所有数据严格依据项目根目录 `统一数据字典.md`：

- 第1节：6 座寺院
- 第2节：6 位法师
- 第3节：7 种用户端服务（祈福/供灯/上香/还愿/超度/开光/化太岁）
- 第4节：4 项 DIY 手串加持服务（价格精确匹配）
- 第5节：14 种 DIY 手串材料基准价格
- 第6节：功德金档位
- 第7节：预约订单状态流转

## 启动方式

```bash
# 安装依赖
npm install

# 开发模式（热重载，监听文件变化自动重启）
npm run dev

# 生产模式启动
npm start

# 编译构建（输出到 dist/）
npm run build
```

服务启动后监听 `http://localhost:3001`，API 基路径为 `/api/v1`。

## 接口列表

所有响应统一格式：

```json
{ "code": 0, "message": "success", "data": ... }
```

| 方法 | 路径 | 说明 |
|------|------|------|
| GET  | `/health` | 健康检查 |
| GET  | `/api/v1/temples` | 获取 6 座寺院列表 |
| GET  | `/api/v1/temples/:id` | 获取单个寺院详情 |
| GET  | `/api/v1/masters` | 获取 6 位法师列表 |
| GET  | `/api/v1/masters/:id` | 获取单个法师详情 |
| GET  | `/api/v1/services` | 获取服务列表（含 7 种用户端服务 + 4 项加持服务 + 功德金档位） |
| GET  | `/api/v1/services/:id` | 获取单个服务详情 |
| GET  | `/api/v1/materials` | 获取 14 种材料列表 |
| GET  | `/api/v1/bookings` | 获取预约订单列表 |
| GET  | `/api/v1/bookings/:id` | 获取单个订单详情 |
| POST | `/api/v1/bookings` | 创建预约订单（状态默认「待确认」） |
| POST | `/api/v1/auth/login` | 登录（接收 phone+code，返回模拟 JWT token + 用户信息） |
| GET  | `/api/v1/messages` | 获取站内消息列表 |

### 接口示例

```bash
# 获取寺院列表
curl http://localhost:3001/api/v1/temples

# 登录
curl -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"1234"}'

# 创建预约
curl -X POST http://localhost:3001/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{"userId":"U001","templeId":"T001","templeName":"灵隐寺","masterId":"M001","masterName":"智海法师","serviceId":"S001","serviceName":"祈福","bookingDate":"2026-07-10","timeSlot":"09:00-10:00","meritMoney":100,"meritMoneyTier":"中额","note":"祈求平安"}'
```

## 目录结构

```
packages/mock-server/
├── package.json
├── tsconfig.json
├── README.md
└── src/
    ├── index.ts              # 应用入口，监听 3001 端口
    ├── data/
    │   ├── temples.ts        # 6 座寺院
    │   ├── masters.ts        # 6 位法师
    │   ├── services.ts       # 7 种服务 + 4 项加持服务
    │   ├── materials.ts      # 14 种材料
    │   └── bookings.ts       # 3 条示例订单 + 功德金档位
    └── routes/
        └── index.ts          # 所有 API 路由
```

## 技术栈

- Node.js + Express 4.x
- TypeScript 5.x（target ES2022, module ESNext）
- tsx（开发热重载）
- cors（跨域支持）
