// 寺院数据 - 依据统一数据字典第1节
// 共 6 座寺院

export interface Temple {
  id: string;
  name: string;
  region: string;
  type: string;
  sect: string;
  status: string;
  address: string;
  coverImage: string;
  rating: number;
  description: string;
}

export const temples: Temple[] = [
  {
    id: 'T001',
    name: '灵隐寺',
    region: '浙江杭州',
    type: '汉传佛教',
    sect: '禅宗',
    status: '正常',
    address: '杭州市西湖区灵隐路法云弄1号',
    coverImage: '/assets/temple-card-lingyinsi.jpg',
    rating: 4.9,
    description: '杭州最早的名刹，江南禅宗五大名山之一，以禅修、祈福、开光法事闻名。'
  },
  {
    id: 'T002',
    name: '白云观',
    region: '北京',
    type: '道教',
    sect: '全真派',
    status: '正常',
    address: '北京市西城区白云观街1号',
    coverImage: '/assets/temple-card-baimasi.jpg',
    rating: 4.7,
    description: '道教全真派三大祖庭之一，北京最大道观，以道教科仪、祈福、化太岁闻名。'
  },
  {
    id: 'T003',
    name: '少林寺',
    region: '河南嵩山',
    type: '汉传佛教',
    sect: '禅宗',
    status: '正常',
    address: '河南省郑州市登封市嵩山少林景区',
    coverImage: '/assets/temple-card-shaolinsi.jpg',
    rating: 4.8,
    description: '禅宗祖庭，少林武术发源地，以禅修、武术、超度、开光法事闻名。'
  },
  {
    id: 'T004',
    name: '大昭寺',
    region: '西藏拉萨',
    type: '藏传佛教',
    sect: '格鲁派',
    status: '正常',
    address: '拉萨市城关区八廓街',
    coverImage: '/assets/temple-card-dazhaosi.jpg',
    rating: 4.9,
    description: '藏传佛教圣地，拉萨城市中心，以藏密仪轨、灌顶、超度、祈福闻名。'
  },
  {
    id: 'T005',
    name: '普陀山',
    region: '浙江舟山',
    type: '汉传佛教',
    sect: '禅宗',
    status: '待审核',
    address: '舟山市普陀区普陀山',
    coverImage: '/assets/temple-card-famensi.jpg',
    rating: 4.6,
    description: '观音菩萨道场，佛教四大名山之一，以净土法门、观音法门、祈福闻名。'
  },
  {
    id: 'T006',
    name: '武当山',
    region: '湖北十堰',
    type: '道教',
    sect: '正一派',
    status: '正常',
    address: '十堰市丹江口市武当山特区',
    coverImage: '/assets/temple-card-qingyanggong.jpg',
    rating: 4.7,
    description: '道教圣地，真武大帝道场，以内丹、太极、风水、化太岁闻名。'
  }
];
