// 预约订单数据 - 依据统一数据字典第7节状态流转
// 状态流转：用户提交 → 待确认 → 已确认 → 进行中 → 已完成 / 已取消
// 示例 3 条订单，覆盖：待确认、已确认、已完成

export interface Booking {
  id: string;
  userId: string;
  templeId: string;
  templeName: string;
  masterId: string;
  masterName: string;
  serviceId: string;
  serviceName: string;
  bookingDate: string;
  timeSlot: string;
  meritMoney: number;
  meritMoneyTier: string;
  status: string;
  createdAt: string;
  note: string;
}

export const bookings: Booking[] = [
  {
    id: 'B20260630001',
    userId: 'U001',
    templeId: 'T001',
    templeName: '灵隐寺',
    masterId: 'M001',
    masterName: '智海法师',
    serviceId: 'S001',
    serviceName: '祈福',
    bookingDate: '2026-07-05',
    timeSlot: '09:00-10:00',
    meritMoney: 200,
    meritMoneyTier: '大额',
    status: 'pending',
    createdAt: '2026-06-30 08:30:00',
    note: '为家人祈求平安健康。'
  },
  {
    id: 'B20260628002',
    userId: 'U002',
    templeId: 'T003',
    templeName: '少林寺',
    masterId: 'M003',
    masterName: '释延心法师',
    serviceId: 'S005',
    serviceName: '超度',
    bookingDate: '2026-07-02',
    timeSlot: '14:00-15:30',
    meritMoney: 500,
    meritMoneyTier: '不限额',
    status: 'confirmed',
    createdAt: '2026-06-28 16:20:00',
    note: '为先人超度往生，请法师主持法事。'
  },
  {
    id: 'B20260615003',
    userId: 'U001',
    templeId: 'T002',
    templeName: '白云观',
    masterId: 'M002',
    masterName: '清风道长',
    serviceId: 'S007',
    serviceName: '化太岁',
    bookingDate: '2026-06-20',
    timeSlot: '10:00-11:00',
    meritMoney: 100,
    meritMoneyTier: '中额',
    status: 'completed',
    createdAt: '2026-06-15 19:45:00',
    note: '本命年化太岁，祈求流年顺利。'
  }
];

// 功德金档位 - 依据统一数据字典第6节
export const meritMoneyTiers = [
  { tier: '随喜', amount: 0, description: '随喜功德，不限金额' },
  { tier: '小额', amount: 50, description: '小额功德金' },
  { tier: '中额', amount: 100, description: '中额功德金' },
  { tier: '大额', amount: 200, description: '大额功德金' },
  { tier: '不限额', amount: -1, description: '自定义输入金额' }
];
