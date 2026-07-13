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
  { id: 8, code: 'general', name: '直接问事', description: '不限定术数方向的日常问事入口', icon: '/icons/general.png', promptTemplate: '', status: 'enabled', createdAt: '2026-07-13 10:00:00' },
  { id: 1, code: 'bazi', name: '八字命理', description: '依据生辰八字推演命格运势', icon: '/icons/bazi.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 2, code: 'marriage', name: '姻缘测算', description: '测算姻缘婚恋走势', icon: '/icons/marriage.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 3, code: 'tarot', name: '塔罗牌', description: '塔罗牌占卜指引', icon: '/icons/tarot.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 4, code: 'fengshui', name: '风水分析', description: '居家风水布局建议', icon: '/icons/fengshui.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 5, code: 'qimen', name: '奇门遁甲', description: '奇门遁甲预测决策', icon: '/icons/qimen.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 6, code: 'ziwei', name: '紫微斗数', description: '紫微斗数命盘解析', icon: '/icons/ziwei.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' },
  { id: 7, code: 'liuyao', name: '六爻梅花', description: '六爻梅花易数占断', icon: '/icons/liuyao.png', promptTemplate: '', status: 'enabled', createdAt: '2026-06-28 10:00:00' }
];

type MockAiSession = {
  id: number;
  sessionNo: string;
  userId: string;
  skillCode: string;
  title: string;
  status: string;
  createdAt: string;
  updatedAt: string;
};

type MockAiMessage = {
  id: number;
  sessionId: number;
  role: 'user' | 'assistant';
  content: string;
  tokens: number;
  status: 'pending' | 'completed' | 'failed';
  errorMessage: string;
  retryable: boolean;
  createdAt: string;
};

const mockAiSessions: MockAiSession[] = [{
  id: 1,
  sessionNo: 'AI20260709001',
  userId: 'U001',
  skillCode: 'general',
  title: '最近事业如何？',
  status: 'active',
  createdAt: '2026-07-09 08:00:00',
  updatedAt: '2026-07-09 08:01:05'
}];

const mockAiMessages: MockAiMessage[] = [
  { id: 1, sessionId: 1, role: 'user', content: '最近事业如何？', tokens: 0, status: 'completed', errorMessage: '', retryable: false, createdAt: '2026-07-09 08:01:00' },
  { id: 2, sessionId: 1, role: 'assistant', content: '适合稳中求进，先整理资源，再择机推进。', tokens: 0, status: 'completed', errorMessage: '', retryable: false, createdAt: '2026-07-09 08:01:05' }
];

function mockAiSession(id: number) {
  return mockAiSessions.find((session) => session.id === id);
}

function aiOwnerMatches(session: MockAiSession, requested: unknown) {
  return typeof requested !== 'string' || requested === '' || requested === session.userId;
}

function mockAiAnswer(content: string) {
  return `[本地开发模拟] 已收到：${content}。请结合实际情况理性判断。`;
}

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

type MockDiyOrder = {
  id: number;
  orderNo: string;
  userId: string;
  designId: number;
  materialFee: number;
  blessFee: number;
  totalFee: number;
  status: string;
  paymentStatus: string;
  addressId: number;
  source: string;
  creatorId: string;
  creatorShareRate: number;
  originalMaterialFee: number;
  priceChanged: boolean;
  designSnapshot: string;
  pricingSnapshot: string;
  items: Array<Record<string, unknown>>;
  blessingTask: null;
  createTime: string;
};

type MockPayment = {
  id: number;
  paymentNo: string;
  orderType: string;
  orderNo: string;
  amount: number;
  channel: string;
  status: string;
  tradeNo: string;
  createTime: string;
};

const mockDiyOrders: MockDiyOrder[] = [];
const mockPayments: MockPayment[] = [];

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
const intentTags = [
  { code: 'peace', name: '求平安', description: '祈福、护佑与健康', icon: 'shield.lefthalf.filled', sort: 10 },
  { code: 'wealth', name: '求财运', description: '财运与供养', icon: 'banknote.fill', sort: 20 },
  { code: 'love', name: '求姻缘', description: '姻缘与家庭', icon: 'heart.fill', sort: 30 },
  { code: 'career', name: '求事业', description: '事业与开光', icon: 'briefcase.fill', sort: 40 },
  { code: 'study', name: '求学业', description: '学业与智慧', icon: 'book.fill', sort: 50 },
  { code: 'taisui', name: '化太岁', description: '本命年与化太岁', icon: 'circle.hexagongrid.fill', sort: 60 },
  { code: 'diy', name: '定手串', description: '手串材料与定制', icon: 'circle.grid.cross.fill', sort: 70 },
  { code: 'rite', name: '做法事', description: '超度等法事', icon: 'hands.sparkles.fill', sort: 80 }
];
const intentionResources = [
  { resourceType: 'product', sourceId: '1', title: '小叶紫檀108颗佛珠', subtitle: '精选小叶紫檀，手工打磨', price: 388, image: '/assets/product-xiaoyezitan.jpg', orderTarget: 'product:1', intentCodes: ['peace', 'diy'] },
  { resourceType: 'product', sourceId: '2', title: '星月菩提手串', subtitle: '顺白高密星月菩提', price: 198, image: '/assets/product-xingyueputi.jpg', orderTarget: 'product:2', intentCodes: ['diy'] },
  { resourceType: 'service', sourceId: '1', title: '灵隐寺 · 祈福', subtitle: '寺院祈福服务', price: 200, image: '/assets/temple-card-lingyinsi.jpg', orderTarget: 'service:T001:S001', templeCode: 'T001', serviceCode: 'S001', intentCodes: ['peace'] },
  { resourceType: 'service', sourceId: '2', title: '白云观 · 化太岁', subtitle: '道教科仪服务', price: 300, image: '/assets/temple-card-baimasi.jpg', orderTarget: 'service:T002:S007', templeCode: 'T002', serviceCode: 'S007', intentCodes: ['taisui'] },
  { resourceType: 'service', sourceId: '3', title: '少林寺 · 超度', subtitle: '寺院法事服务', price: 500, image: '/assets/temple-card-shaolinsi.jpg', orderTarget: 'service:T003:S005', templeCode: 'T003', serviceCode: 'S005', intentCodes: ['rite'] }
];

router.get('/intentions', (req: Request, res: Response) => {
  const code = typeof req.query.code === 'string' ? req.query.code : '';
  const filtered = intentionResources.filter((item) => !code || item.intentCodes.includes(code));
  const payload = page(filtered.map(({ intentCodes: _intentCodes, ...item }) => item), req);
  success(res, { tags: intentTags, ...payload });
});

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
  if (design.status !== 'public' && design.status !== 'approved') return fail(res, 40907, '作品尚未上架，无法下单');
  let snapshotItems: Array<{ materialId: number; unitPrice: number; quantity: number; spec?: string }>;
  try {
    snapshotItems = JSON.parse(design.designData);
  } catch {
    return fail(res, 40001, '设计材料快照无效');
  }
  const pricedItems: Array<Record<string, unknown>> = [];
  const requestedStock = new Map<number, number>();
  let originalMaterialFee = 0;
  let materialFee = 0;
  for (const item of snapshotItems) {
    const current = diyMaterials.find((material) => material.id === item.materialId);
    if (!current || current.status !== 'on_shelf') return fail(res, 40907, '材料已下架或规格不可用，请重新选择');
    const requested = (requestedStock.get(current.id) ?? 0) + item.quantity;
    if (item.quantity <= 0 || current.stock < requested) return fail(res, 40905, '库存不足');
    requestedStock.set(current.id, requested);
    originalMaterialFee += item.unitPrice * item.quantity;
    materialFee += current.unitPrice * item.quantity;
    pricedItems.push({
      id: Date.now() + pricedItems.length + 1,
      orderId: 0,
      materialId: current.id,
      skuId: 0,
      materialName: current.name,
      spec: item.spec || current.spec,
      unitPrice: current.unitPrice,
      quantity: item.quantity,
      subtype: current.category
    });
  }
  requestedStock.forEach((quantity, materialId) => {
    const material = diyMaterials.find((item) => item.id === materialId);
    if (material) material.stock -= quantity;
  });
  const now = Date.now();
  const blessFee = req.body?.blessServiceCode ? 100 : 0;
  const order: MockDiyOrder = {
    id: now,
    orderNo: `DIY${now}`,
    userId: req.body?.userId ?? 'U001',
    designId: design.id,
    materialFee,
    blessFee,
    totalFee: materialFee + blessFee,
    status: 'pending_review',
    paymentStatus: 'pending',
    addressId: req.body?.addressId ?? 1,
    source: 'design_square',
    creatorId: design.userId,
    creatorShareRate: 0,
    originalMaterialFee,
    priceChanged: Math.abs(originalMaterialFee - materialFee) >= 0.005,
    designSnapshot: JSON.stringify(design),
    pricingSnapshot: JSON.stringify({ originalMaterialFee, materialFee, blessFee, totalFee: materialFee + blessFee, items: pricedItems }),
    items: pricedItems,
    blessingTask: null,
    createTime: new Date().toISOString().replace('T', ' ').slice(0, 19)
  };
  order.items.forEach((item) => { item.orderId = order.id; });
  mockDiyOrders.unshift(order);
  success(res, order);
});

router.get('/diy/orders/:id', (req: Request, res: Response) => {
  const order = mockDiyOrders.find((item) => String(item.id) === req.params.id);
  if (!order) return fail(res, 404, 'DIY订单不存在');
  success(res, order);
});

router.get('/diy/orders', (req: Request, res: Response) => {
  const userId = typeof req.query.userId === 'string' ? req.query.userId : '';
  success(res, page(mockDiyOrders.filter((order) => !userId || order.userId === userId), req));
});

router.post('/payments', (req: Request, res: Response) => {
  const order = mockDiyOrders.find((item) => item.orderNo === req.body?.orderNo);
  if (!order) return fail(res, 404, '订单不存在');
  if (order.userId !== req.body?.userId) return fail(res, 40301, '无权支付该DIY订单');
  if (order.status !== 'pending_review' || order.paymentStatus === 'success') return fail(res, 40906, 'DIY订单当前状态不可支付');
  if (Number(req.body?.amount) !== order.totalFee) return fail(res, 40906, '支付金额与订单不一致');
  const now = Date.now();
  const payment: MockPayment = {
    id: now,
    paymentNo: `PAY${now}`,
    orderType: req.body?.orderType ?? 'diy_order',
    orderNo: order.orderNo,
    amount: order.totalFee,
    channel: req.body?.channel ?? 'wechat',
    status: 'pending',
    tradeNo: '',
    createTime: new Date().toISOString().replace('T', ' ').slice(0, 19)
  };
  mockPayments.unshift(payment);
  success(res, { id: payment.id, paymentNo: payment.paymentNo, payUrl: `https://mock-pay.example.com/pay/${payment.paymentNo}` });
});

router.get('/payments/:id', (req: Request, res: Response) => {
  const payment = mockPayments.find((item) => String(item.id) === req.params.id);
  if (!payment) return fail(res, 404, '支付单不存在');
  if (payment.status === 'pending') {
    payment.status = 'success';
    payment.tradeNo = `MOCK${Date.now()}`;
    const order = mockDiyOrders.find((item) => item.orderNo === payment.orderNo);
    if (order) order.paymentStatus = 'success';
  }
  success(res, payment);
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
  const userId = typeof req.query.userId === 'string' ? req.query.userId : 'U001';
  success(res, page(mockAiSessions.filter((session) => session.userId === userId), req));
});

router.post('/ai/sessions', (req: Request, res: Response) => {
  const now = Date.now();
  const question = typeof req.body?.question === 'string' ? req.body.question.trim() : '';
  const session: MockAiSession = {
    id: now,
    sessionNo: `AI${now}`,
    userId: req.body?.userId ?? 'U001',
    skillCode: req.body?.skillCode || 'general',
    title: question || '新对话',
    status: 'active',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
  mockAiSessions.unshift(session);
  if (question) {
    mockAiMessages.push(
      { id: now + 1, sessionId: now, role: 'user', content: question, tokens: 0, status: 'completed', errorMessage: '', retryable: false, createdAt: session.createdAt },
      { id: now + 2, sessionId: now, role: 'assistant', content: mockAiAnswer(question), tokens: 0, status: 'completed', errorMessage: '', retryable: false, createdAt: session.createdAt }
    );
  }
  success(res, { id: session.id, sessionNo: session.sessionNo, skillCode: session.skillCode, status: session.status });
});

router.get('/ai/sessions/:id', (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const session = mockAiSession(id);
  if (!session) return fail(res, 404, '会话不存在');
  if (!aiOwnerMatches(session, req.query.userId)) return fail(res, 403, '无权限访问');
  success(res, { session, messages: mockAiMessages.filter((message) => message.sessionId === id) });
});

router.get('/ai/sessions/:id/messages', (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const session = mockAiSession(id);
  if (!session) return fail(res, 404, '会话不存在');
  if (!aiOwnerMatches(session, req.query.userId)) return fail(res, 403, '无权限访问');
  success(res, page(mockAiMessages.filter((message) => message.sessionId === id), req));
});

router.post('/ai/sessions/:id/messages', (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const session = mockAiSession(id);
  if (!session) return fail(res, 404, '会话不存在');
  if (!aiOwnerMatches(session, req.body?.userId)) return fail(res, 403, '无权限访问');
  const content = typeof req.body?.content === 'string' ? req.body.content.trim() : '';
  if (!content) return fail(res, 400, '消息不能为空');
  const messageId = Date.now() + 1;
  mockAiMessages.push(
    { id: messageId - 1, sessionId: id, role: 'user', content, tokens: 0, status: 'completed', errorMessage: '', retryable: false, createdAt: new Date().toISOString() },
    { id: messageId, sessionId: id, role: 'assistant', content: mockAiAnswer(content), tokens: 0, status: 'completed', errorMessage: '', retryable: false, createdAt: new Date().toISOString() }
  );
  success(res, { sessionId: id, messageId, status: 'completed' });
});

router.post('/ai/sessions/:id/messages/:messageId/retry', (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const session = mockAiSession(id);
  if (!session) return fail(res, 404, '会话不存在');
  if (!aiOwnerMatches(session, req.body?.userId)) return fail(res, 403, '无权限访问');
  const message = mockAiMessages.find((item) => item.id === Number(req.params.messageId) && item.sessionId === id);
  if (!message || message.role !== 'assistant' || message.status !== 'failed') return fail(res, 400, '消息不可重试');
  const userMessage = [...mockAiMessages].reverse().find((item) => item.sessionId === id && item.role === 'user' && item.id < message.id);
  message.status = 'completed';
  message.errorMessage = '';
  message.retryable = false;
  message.content = mockAiAnswer(userMessage?.content ?? '请继续回答');
  success(res, { sessionId: id, messageId: message.id, status: message.status });
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
