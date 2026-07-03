// 路由定义 - 所有 API 路由统一挂载于此
// 统一响应格式：{ code: 0, message: "success", data: ... }

import { Router, Request, Response } from 'express';
import { temples } from '../data/temples.js';
import { masters } from '../data/masters.js';
import { services, blessingServices } from '../data/services.js';
import { materials } from '../data/materials.js';
import { bookings, meritMoneyTiers, type Booking } from '../data/bookings.js';

const router = Router();

// 统一成功响应
function success<T>(res: Response, data: T) {
  return res.json({ code: 0, message: 'success', data });
}

// 统一失败响应
function fail(res: Response, code: number, message: string) {
  return res.status(code).json({ code, message, data: null });
}

// ========== 寺院 ==========
router.get('/temples', (_req: Request, res: Response) => {
  success(res, temples);
});

router.get('/temples/:id', (req: Request, res: Response) => {
  const temple = temples.find((t) => t.id === req.params.id);
  if (!temple) return fail(res, 404, '寺院不存在');
  success(res, temple);
});

// ========== 法师 ==========
router.get('/masters', (_req: Request, res: Response) => {
  success(res, masters);
});

router.get('/masters/:id', (req: Request, res: Response) => {
  const master = masters.find((m) => m.id === req.params.id);
  if (!master) return fail(res, 404, '法师不存在');
  success(res, master);
});

// ========== 服务 ==========
// GET /services 返回用户端服务 + 加持服务
router.get('/services', (_req: Request, res: Response) => {
  success(res, { services, blessingServices, meritMoneyTiers });
});

router.get('/services/:id', (req: Request, res: Response) => {
  const svc = services.find((s) => s.id === req.params.id);
  if (svc) return success(res, svc);
  const blessing = blessingServices.find((s) => s.id === req.params.id);
  if (blessing) return success(res, blessing);
  return fail(res, 404, '服务不存在');
});

// ========== 材料 ==========
router.get('/materials', (_req: Request, res: Response) => {
  success(res, materials);
});

// ========== 预约订单 ==========
router.get('/bookings', (_req: Request, res: Response) => {
  success(res, bookings);
});

router.get('/bookings/:id', (req: Request, res: Response) => {
  const booking = bookings.find((b) => b.id === req.params.id);
  if (!booking) return fail(res, 404, '订单不存在');
  success(res, booking);
});

router.post('/bookings', (req: Request, res: Response) => {
  const body = req.body ?? {};
  const now = new Date();
  const dateStr = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}`;
  const newBooking: Booking = {
    id: `B${dateStr}${String(bookings.length + 1).padStart(3, '0')}`,
    userId: body.userId ?? 'U001',
    templeId: body.templeId ?? '',
    templeName: body.templeName ?? '',
    masterId: body.masterId ?? '',
    masterName: body.masterName ?? '',
    serviceId: body.serviceId ?? '',
    serviceName: body.serviceName ?? '',
    bookingDate: body.bookingDate ?? '',
    timeSlot: body.timeSlot ?? '',
    meritMoney: body.meritMoney ?? 0,
    meritMoneyTier: body.meritMoneyTier ?? '随喜',
    status: '待确认',
    createdAt: now.toISOString().replace('T', ' ').slice(0, 19),
    note: body.note ?? ''
  };
  bookings.push(newBooking);
  success(res, newBooking);
});

// ========== 认证 ==========
router.post('/auth/login', (req: Request, res: Response) => {
  const { phone, code } = req.body ?? {};
  if (!phone || !code) {
    return fail(res, 400, 'phone 与 code 必填');
  }
  // 模拟 JWT token（仅用于联调，非真实签名）
  const token = `mock.${Buffer.from(JSON.stringify({ phone, ts: Date.now() })).toString('base64')}.signature`;
  const user = {
    userId: 'U001',
    phone,
    nickname: '善信弟子',
    avatar: '/assets/master-avatar-zhihai.jpg',
    createdAt: '2026-01-01 00:00:00'
  };
  success(res, { token, user });
});

// ========== 站内消息 ==========
router.get('/messages', (_req: Request, res: Response) => {
  const messages = [
    {
      id: 'MSG001',
      userId: 'U001',
      title: '预约已确认',
      content: '您于灵隐寺的祈福预约已由智海法师确认，请准时到达。',
      type: '预约通知',
      isRead: false,
      createdAt: '2026-06-30 09:15:00'
    },
    {
      id: 'MSG002',
      userId: 'U001',
      title: '法会预告',
      content: '少林寺将于农历六月十九举行观音法会，欢迎随喜参加。',
      type: '活动通知',
      isRead: false,
      createdAt: '2026-06-28 10:00:00'
    },
    {
      id: 'MSG003',
      userId: 'U001',
      title: '功德回向',
      content: '您在白云观化太岁法事的功德已回向，愿流年顺利。',
      type: '功德通知',
      isRead: true,
      createdAt: '2026-06-20 12:30:00'
    }
  ];
  success(res, messages);
});

export default router;
