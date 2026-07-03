// Express 应用入口
// 监听端口 3001，启用 CORS，挂载所有路由，基路径 /api/v1

import express from 'express';
import cors from 'cors';
import router from './routes/index.js';

const app = express();
const PORT = 3001;

// 中间件
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 健康检查
app.get('/health', (_req, res) => {
  res.json({ code: 0, message: 'success', data: { status: 'ok', service: '@dongfang/mock-server', time: new Date().toISOString() } });
});

// 挂载 API 路由，基路径 /api/v1
app.use('/api/v1', router);

// 404 兜底
app.use((_req, res) => {
  res.status(404).json({ code: 404, message: '接口不存在', data: null });
});

app.listen(PORT, () => {
  console.log(`[问玄东方 Mock Server] 服务已启动：http://localhost:${PORT}`);
  console.log(`[问玄东方 Mock Server] API 基路径：http://localhost:${PORT}/api/v1`);
  console.log(`[问玄东方 Mock Server] 健康检查：http://localhost:${PORT}/health`);
});
