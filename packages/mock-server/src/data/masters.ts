// 法师数据 - 依据统一数据字典第2节
// 共 6 位法师

export interface Master {
  id: string;
  dharmaName: string;
  layName: string;
  templeId: string;
  templeName: string;
  position: string;
  sect: string;
  type: string;
  authStatus: string;
  specialties: string[];
  avatar: string;
  rating: number;
}

export const masters: Master[] = [
  {
    id: 'M001',
    dharmaName: '智海法师',
    layName: '陈建华',
    templeId: 'T001',
    templeName: '灵隐寺',
    position: '住持',
    sect: '汉传佛教',
    type: '佛教',
    authStatus: '已认证',
    specialties: ['佛学', '禅修', '开光', '祈福'],
    avatar: '/assets/master-avatar-zhihai.jpg',
    rating: 4.9
  },
  {
    id: 'M002',
    dharmaName: '清风道长',
    layName: '李信军',
    templeId: 'T002',
    templeName: '白云观',
    position: '监院',
    sect: '全真道派',
    type: '道教',
    authStatus: '已认证',
    specialties: ['道学', '风水', '命理', '祈福'],
    avatar: '/assets/master-avatar-qingfeng.jpg',
    rating: 4.8
  },
  {
    id: 'M003',
    dharmaName: '释延心法师',
    layName: '王建军',
    templeId: 'T003',
    templeName: '少林寺',
    position: '首座',
    sect: '禅宗',
    type: '佛教',
    authStatus: '已认证',
    specialties: ['武术', '禅修', '超度', '开光'],
    avatar: '/assets/master-avatar-zhihai.jpg',
    rating: 4.8
  },
  {
    id: 'M004',
    dharmaName: '扎西多吉活佛',
    layName: '—',
    templeId: 'T004',
    templeName: '大昭寺',
    position: '活佛',
    sect: '藏密佛教',
    type: '佛教',
    authStatus: '已认证',
    specialties: ['藏密仪轨', '灌顶', '超度', '祈福'],
    avatar: '/assets/master-avatar-zhaxiduoji.jpg',
    rating: 5.0
  },
  {
    id: 'M005',
    dharmaName: '慧明法师',
    layName: '周明华',
    templeId: 'T005',
    templeName: '普陀山',
    position: '副住持',
    sect: '汉传佛教',
    type: '佛教',
    authStatus: '待审核',
    specialties: ['净土', '观音法门', '祈福'],
    avatar: '/assets/master-avatar-shimingyuan.jpg',
    rating: 4.5
  },
  {
    id: 'M006',
    dharmaName: '真武道长',
    layName: '张志远',
    templeId: 'T006',
    templeName: '武当山',
    position: '知客',
    sect: '正一派',
    type: '道教',
    authStatus: '已认证',
    specialties: ['内丹', '太极', '风水', '化太岁'],
    avatar: '/assets/master-avatar-zhangzhishun.jpg',
    rating: 4.7
  }
];
