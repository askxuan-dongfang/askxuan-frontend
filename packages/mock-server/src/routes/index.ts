// 路由定义 - 所有 API 路由统一挂载于此
// 统一响应格式：{ code: 0, message: "success", data: ... }

import { Router, Request, Response } from 'express';
import { temples } from '../data/temples.js';
import { masters } from '../data/masters.js';
import { services, blessingServices } from '../data/services.js';
import { materials } from '../data/materials.js';
import { bookings, meritMoneyTiers, type Booking } from '../data/bookings.js';

const router = Router();

const diyDesigns = [
  {
    id: 1,
    designNo: 'D20260709001',
    userId: 'U001',
    name: '平安祈福手串',
    designData: JSON.stringify([
      { materialId: 1, materialName: '星月菩提', spec: '8mm', unitPrice: 3.5, quantity: 18, subtype: 'main_bead' },
      { materialId: 3, materialName: '南红玛瑙', spec: '6mm', unitPrice: 15, quantity: 2, subtype: 'spacer' },
      { materialId: 5, materialName: '蜜蜡佛头', spec: '12mm', unitPrice: 188, quantity: 1, subtype: 'buddha_head' }
    ]),
    totalPrice: 281,
    status: 'public',
    blessServiceCode: 'E001',
    createTime: '2026-07-09 10:00:00'
  }
];

const communityPosts = [
  {
    id: 'P001',
    type: 'video',
    sect: '禅宗',
    masterId: 'M001',
    masterName: '智海法师',
    title: '三分钟观呼吸入门',
    coverUrl: '/assets/temple-card-lingyinsi.jpg',
    videoUrl: '',
    likeCount: 23000,
    commentCount: 186,
    auditStatus: 'approved',
    createTime: '2026-07-09 09:30:00'
  },
  {
    id: 'P002',
    type: 'article',
    sect: '全真派',
    masterId: 'M002',
    masterName: '清风道长',
    title: '化太岁前需要准备什么',
    coverUrl: '/assets/temple-card-qingyanggong.jpg',
    videoUrl: '',
    likeCount: 9686,
    commentCount: 156,
    auditStatus: 'approved',
    createTime: '2026-07-08 18:20:00'
  }
];

const intentionItems = [
  { code: 'peace', title: '求平安', serviceCode: 'S001', productTags: ['开光', '平安'], sects: ['禅宗', '格鲁派'] },
  { code: 'wealth', title: '求财运', serviceCode: 'S009', productTags: ['招财', '供香'], sects: ['全真派', '正一派'] },
  { code: 'love', title: '求姻缘', serviceCode: 'S008', productTags: ['姻缘', '供灯'], sects: ['禅宗'] },
  { code: 'taisui', title: '化太岁', serviceCode: 'S007', productTags: ['太岁', '符牌'], sects: ['全真派', '正一派'] }
];

const aiSkills = [
  { id: 1, code: 'bazi', name: '八字命理', description: '依据生辰八字推演命格运势', icon: '/icons/bazi.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 2, code: 'marriage', name: '姻缘测算', description: '测算姻缘婚恋走势', icon: '/icons/marriage.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 3, code: 'tarot', name: '塔罗牌', description: '塔罗牌占卜指引', icon: '/icons/tarot.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 4, code: 'fengshui', name: '风水分析', description: '居家风水布局建议', icon: '/icons/fengshui.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 5, code: 'qimen', name: '奇门遁甲', description: '奇门遁甲预测决策', icon: '/icons/qimen.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 6, code: 'ziwei', name: '紫微斗数', description: '紫微斗数命盘解析', icon: '/icons/ziwei.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 7, code: 'liuyao', name: '六爻梅花', description: '六爻梅花易数占断', icon: '/icons/liuyao.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' }
];

function mapDiyCategory(material: { name: string; category: string }) {
  if (material.category === '主珠') return 'main_bead';
  if (material.name.includes('佛头')) return 'buddha_head';
  if (material.name.includes('三通')) return 'three_way';
  if (material.name.includes('吊坠') || material.name.includes('流苏')) return 'pendant';
  if (material.name.includes('隔片')) return 'spacer';
  if (material.name.includes('绳')) return 'cord';
  return 'accessory';
}

const diyMaterials = materials.map((m) => ({
  id: Number(String(m.id).replace(/\D/g, '')),
  name: m.name,
  spec: m.spec,
  unitPrice: m.price,
  unit: m.unit,
  category: mapDiyCategory(m),
  fiveElements: '',
  image: '',
  stock: 999,
  status: 'on_shelf'
}));

// 统一成功响应
function success<T>(res: Response, data: T) {
  return res.json({ code: 0, message: 'success', data });
}

// 统一失败响应
function fail(res: Response, code: number, message: string) {
  return res.status(code).json({ code, message, data: null });
}

function page<T>(list: T[], req: Request) {
  const pageNo = Number(req.query.page || 1);
  const size = Number(req.query.size || list.length || 20);
  const start = (pageNo - 1) * size;
  return { total: list.length, list: list.slice(start, start + size), page: pageNo, size };
}

// ========== 寺院 ==========
router.get('/temples', (req: Request, res: Response) => {
  const { beliefCode, sect, type, serviceCode } = req.query;
  const list = temples.filter((t) => {
    if (typeof beliefCode === 'string' && beliefCode && t.beliefCode !== beliefCode) return false;
    if (typeof sect === 'string' && sect && t.sect !== sect) return false;
    if (typeof type === 'string' && type && t.type !== type) return false;
    if (typeof serviceCode === 'string' && serviceCode && !t.serviceCodes.includes(serviceCode)) return false;
    return true;
  });
  success(res, page(list, req));
});

router.get('/temples/:id', (req: Request, res: Response) => {
  const temple = temples.find((t) => t.id === req.params.id);
  if (!temple) return fail(res, 404, '寺院不存在');
  success(res, temple);
});

// ========== 法师 ==========
router.get('/masters', (req: Request, res: Response) => {
  const { beliefCode, sect, type, templeId } = req.query;
  const list = masters.filter((m) => {
    if (typeof beliefCode === 'string' && beliefCode && m.beliefCode !== beliefCode) return false;
    if (typeof sect === 'string' && sect && m.sect !== sect) return false;
    if (typeof type === 'string' && type && m.type !== type) return false;
    if (typeof templeId === 'string' && templeId && m.templeId !== templeId) return false;
    return true;
  });
  success(res, page(list, req));
});

const beliefs = [
  { code: 'han_buddhism', name: '汉传佛教', summary: '慈悲与智慧并行', description: '汉传佛教在中国长期发展，形成禅、净土、天台、华严等具体宗派。', coverImage: '', sort: 10 },
  { code: 'tibetan_buddhism', name: '藏传佛教', summary: '传承、修持与慈悲', description: '藏传佛教具有清晰的传承体系，包含格鲁、宁玛、噶举、萨迦等具体宗派。', coverImage: '', sort: 20 },
  { code: 'daoism', name: '道教', summary: '道法自然，清静修持', description: '道教是中国本土宗教传统，包含全真、正一等具体宗派。', coverImage: '', sort: 30 },
  { code: 'folk', name: '民间信仰', summary: '乡土传统与民俗传承', description: '民间信仰承载地域性祭祀、祈愿和文化传统。', coverImage: '', sort: 40 }
];

router.get('/beliefs/:code', (req: Request, res: Response) => {
  const belief = beliefs.find((item) => item.code === req.params.code);
  if (!belief) return fail(res, 404, '信仰流派不存在');
  success(res, belief);
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

// ========== DIY ==========
router.get('/diy/designs', (req: Request, res: Response) => {
  success(res, page(diyDesigns, req));
});

router.get('/diy/designs/:id', (req: Request, res: Response) => {
  const design = diyDesigns.find((d) => String(d.id) === req.params.id);
  if (!design) return fail(res, 404, '设计不存在');
  success(res, design);
});

router.post('/diy/designs/:id/order', (req: Request, res: Response) => {
  const design = diyDesigns.find((d) => String(d.id) === req.params.id);
  if (!design) return fail(res, 404, '设计不存在');
  success(res, {
    id: Date.now(),
    orderNo: `DIY${Date.now()}`,
    userId: req.body?.userId ?? 'U001',
    designId: design.id,
    materialFee: design.totalPrice,
    blessFee: req.body?.blessServiceCode ? 100 : 0,
    totalFee: design.totalPrice + (req.body?.blessServiceCode ? 100 : 0),
    status: 'pending_review',
    addressId: req.body?.addressId ?? 1,
    items: JSON.parse(design.designData),
    createTime: new Date().toISOString().replace('T', ' ').slice(0, 19)
  });
});

router.get('/diy/materials', (req: Request, res: Response) => {
  const category = typeof req.query.category === 'string' ? req.query.category : '';
  const list = category ? diyMaterials.filter((m) => m.category === category) : diyMaterials;
  success(res, page(list, req));
});

// ========== AI 问事 ==========
router.get('/ai/skills', (req: Request, res: Response) => {
  const status = typeof req.query.status === 'string' ? req.query.status : '';
  const list = status ? aiSkills.filter((skill) => skill.status === status) : aiSkills;
  success(res, { list });
});

router.get('/ai/sessions', (req: Request, res: Response) => {
  success(res, page([
    { id: 1, sessionNo: 'AI20260709001', userId: req.query.userId ?? 'U001', skillCode: 'bazi', status: 'active', createdAt: '2026-07-09 08:00:00', updatedAt: '2026-07-09 08:00:00' }
  ], req));
});

router.post('/ai/sessions', (req: Request, res: Response) => {
  success(res, { id: Date.now(), sessionNo: `AI${Date.now()}`, skillCode: req.body?.skillCode ?? 'bazi', status: 'active' });
});

router.get('/ai/sessions/:id', (req: Request, res: Response) => {
  success(res, {
    session: { id: Number(req.params.id) || 1, sessionNo: 'AI20260709001', userId: req.query.userId ?? 'U001', skillCode: 'bazi', status: 'active', createdAt: '2026-07-09 08:00:00', updatedAt: '2026-07-09 08:00:00' },
    messages: [
      { id: 1, sessionId: Number(req.params.id) || 1, role: 'user', content: '最近事业如何？', tokens: 0, createdAt: '2026-07-09 08:01:00' },
      { id: 2, sessionId: Number(req.params.id) || 1, role: 'assistant', content: '适合稳中求进，先整理资源，再择机推进。', tokens: 0, createdAt: '2026-07-09 08:01:05' }
    ]
  });
});

router.get('/ai/sessions/:id/messages', (req: Request, res: Response) => {
  success(res, page([
    { id: 1, sessionId: Number(req.params.id) || 1, role: 'user', content: '最近事业如何？', tokens: 0, createdAt: '2026-07-09 08:01:00' },
    { id: 2, sessionId: Number(req.params.id) || 1, role: 'assistant', content: '适合稳中求进，先整理资源，再择机推进。', tokens: 0, createdAt: '2026-07-09 08:01:05' }
  ], req));
});

router.post('/ai/sessions/:id/messages', (req: Request, res: Response) => {
  success(res, { sessionId: Number(req.params.id) || 1, status: 'accepted' });
});

// ========== 社区内容 / 大师广场 ==========
router.get('/community/feed', (req: Request, res: Response) => {
  const { type, sect } = req.query;
  const list = communityPosts.filter((p) => {
    if (typeof type === 'string' && type && p.type !== type) return false;
    if (typeof sect === 'string' && sect && p.sect !== sect) return false;
    return true;
  });
  success(res, page(list, req));
});

router.get('/community/posts/:id', (req: Request, res: Response) => {
  const post = communityPosts.find((p) => p.id === req.params.id);
  if (!post) return fail(res, 404, '内容不存在');
  success(res, post);
});

router.post('/community/posts/:id/like', (req: Request, res: Response) => {
  success(res, { id: req.params.id, liked: true });
});

router.get('/community/posts/:id/comments', (req: Request, res: Response) => {
  success(res, page([
    { id: 'C001', postId: req.params.id, userName: '善信弟子', content: '讲得很清楚。', createTime: '2026-07-09 11:00:00' }
  ], req));
});

// ========== 意图聚合 ==========
router.get('/intentions', (req: Request, res: Response) => {
  const code = typeof req.query.code === 'string' ? req.query.code : '';
  const list = code ? intentionItems.filter((item) => item.code === code) : intentionItems;
  success(res, page(list, req));
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
