// 服务数据 - 依据统一数据字典第3节（用户端7种服务）和第4节（4项加持服务）

// 用户端服务（依据第3节）
export interface Service {
  id: string;
  name: string;
  type: string;
  priceRange: string;
  masterIds: string[];
  description: string;
}

// 加持服务（依据第4节，价格必须精确匹配）
export interface BlessingService {
  id: string;
  name: string;
  templeId: string;
  templeName: string;
  masterId: string;
  masterName: string;
  price: number;
  description: string;
}

// 用户端服务
export const services: Service[] = [
  {
    id: 'S001',
    name: '祈福',
    type: '法事',
    priceRange: '¥100-500',
    masterIds: ['M001', 'M002', 'M004', 'M005'],
    description: '祈求平安顺遂、消灾纳福，可由法师主持祈福法事。'
  },
  {
    id: 'S002',
    name: '供灯',
    type: '供养',
    priceRange: '¥50-300',
    masterIds: ['M001', 'M003', 'M004'],
    description: '供灯供养，象征智慧光明，祈福消灾。'
  },
  {
    id: 'S003',
    name: '上香',
    type: '供养',
    priceRange: '¥30-200',
    masterIds: ['M001', 'M003', 'M004'],
    description: '上香礼佛供养，表达虔诚敬意。'
  },
  {
    id: 'S004',
    name: '还愿',
    type: '法事',
    priceRange: '¥100-500',
    masterIds: ['M001', 'M003', 'M004'],
    description: '心愿达成后回寺还愿答谢，感恩神佛庇佑。'
  },
  {
    id: 'S005',
    name: '超度',
    type: '法事',
    priceRange: '¥300-1000',
    masterIds: ['M001', 'M003', 'M004'],
    description: '超度亡灵、追荐先人，助其往生善道。'
  },
  {
    id: 'S006',
    name: '开光',
    type: '法事',
    priceRange: '¥168-500',
    masterIds: ['M001', 'M003'],
    description: '为法器、佛像、手串等开光加持，赋予灵性。'
  },
  {
    id: 'S007',
    name: '化太岁',
    type: '法事',
    priceRange: '¥200-800',
    masterIds: ['M002', 'M006'],
    description: '化解太岁冲犯，保佑流年顺利平安。'
  },
  {
    id: 'S008',
    name: '求姻缘',
    type: '祈愿',
    priceRange: '¥100-500',
    masterIds: ['M001', 'M005'],
    description: '祈求良缘和合、感情顺遂。'
  },
  {
    id: 'S009',
    name: '求财运',
    type: '祈愿',
    priceRange: '¥100-800',
    masterIds: ['M002', 'M006'],
    description: '祈求财运通达、事业经营顺利。'
  },
  {
    id: 'S010',
    name: '求事业',
    type: '祈愿',
    priceRange: '¥100-600',
    masterIds: ['M003', 'M006'],
    description: '祈求事业进阶、贵人扶持。'
  },
  {
    id: 'S011',
    name: '求风水',
    type: '咨询',
    priceRange: '¥200-1000',
    masterIds: ['M002', 'M006'],
    description: '结合道教科仪与环境格局提供风水咨询。'
  },
  {
    id: 'S012',
    name: '求健康',
    type: '祈愿',
    priceRange: '¥100-600',
    masterIds: ['M001', 'M004'],
    description: '祈求身心康泰、消灾延寿。'
  },
  {
    id: 'S013',
    name: '求学业',
    type: '祈愿',
    priceRange: '¥100-500',
    masterIds: ['M003', 'M005'],
    description: '祈求学业精进、考试顺遂。'
  }
];

// 4 项加持服务（DIY手串加持，价格必须精确匹配）
export const blessingServices: BlessingService[] = [
  {
    id: 'E001',
    name: '灵隐寺·开光加持',
    templeId: 'T001',
    templeName: '灵隐寺',
    masterId: 'M001',
    masterName: '智海法师',
    price: 168,
    description: '智海法师亲自为手串开光加持，注入禅宗正能量。'
  },
  {
    id: 'E002',
    name: '白云观·道长祈福',
    templeId: 'T002',
    templeName: '白云观',
    masterId: 'M002',
    masterName: '清风道长',
    price: 128,
    description: '清风道长以全真派科仪为手串祈福消灾。'
  },
  {
    id: 'E003',
    name: '少林寺·武僧加持',
    templeId: 'T003',
    templeName: '少林寺',
    masterId: 'M003',
    masterName: '释延心法师',
    price: 198,
    description: '释延心法师以少林禅功为手串加持护身。'
  },
  {
    id: 'E004',
    name: '大昭寺·活佛灌顶',
    templeId: 'T004',
    templeName: '大昭寺',
    masterId: 'M004',
    masterName: '扎西多吉活佛',
    price: 268,
    description: '扎西多吉活佛以藏密仪轨为手串灌顶加持。'
  }
];
