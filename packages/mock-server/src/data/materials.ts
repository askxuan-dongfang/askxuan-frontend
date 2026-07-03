// DIY手串材料基准价格 - 依据统一数据字典第5节
// 共 14 种材料

export interface Material {
  id: string;
  name: string;
  spec: string;
  unit: string;
  price: number;
  category: string;
}

export const materials: Material[] = [
  {
    id: 'MAT001',
    name: '小叶紫檀圆珠',
    spec: '10mm',
    unit: '颗',
    price: 28,
    category: '主珠'
  },
  {
    id: 'MAT002',
    name: '星月菩提',
    spec: '10mm',
    unit: '颗',
    price: 18,
    category: '主珠'
  },
  {
    id: 'MAT003',
    name: '凤眼菩提',
    spec: '10mm',
    unit: '颗',
    price: 22,
    category: '主珠'
  },
  {
    id: 'MAT004',
    name: '白玉',
    spec: '8mm',
    unit: '颗',
    price: 35,
    category: '主珠'
  },
  {
    id: 'MAT005',
    name: '青金石',
    spec: '10mm',
    unit: '颗',
    price: 25,
    category: '主珠'
  },
  {
    id: 'MAT006',
    name: '南红玛瑙',
    spec: '8mm',
    unit: '颗',
    price: 32,
    category: '主珠'
  },
  {
    id: 'MAT007',
    name: '蜜蜡',
    spec: '10mm',
    unit: '颗',
    price: 45,
    category: '主珠'
  },
  {
    id: 'MAT008',
    name: '黑曜石',
    spec: '10mm',
    unit: '颗',
    price: 12,
    category: '主珠'
  },
  {
    id: 'MAT009',
    name: '藏银三通',
    spec: '10mm',
    unit: '个',
    price: 48,
    category: '配饰'
  },
  {
    id: 'MAT010',
    name: '蜜蜡佛头',
    spec: '12mm',
    unit: '个',
    price: 68,
    category: '配饰'
  },
  {
    id: 'MAT011',
    name: '花丝莲花吊坠',
    spec: '15mm',
    unit: '个',
    price: 20,
    category: '配饰'
  },
  {
    id: 'MAT012',
    name: '白水晶隔片',
    spec: '6mm',
    unit: '颗',
    price: 2.5,
    category: '配饰'
  },
  {
    id: 'MAT013',
    name: '流苏配饰',
    spec: '—',
    unit: '个',
    price: 28,
    category: '配饰'
  },
  {
    id: 'MAT014',
    name: '弹力绳',
    spec: '—',
    unit: '根',
    price: 2,
    category: '辅料'
  }
];
