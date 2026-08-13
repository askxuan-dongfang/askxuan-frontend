export interface Master {
  id: string;
  dharmaName: string;
  layName: string;
  templeId: string;
  templeName: string;
  position: string;
  beliefCode: string;
  sect: string;
  type: string;
  authStatus: string;
  shelfStatus: string;
  platformStatus: string;
  specialties: string[];
  avatar: string;
  rating: number;
  consultEnabled?: boolean;
  consultFee?: number;
  consultValidHours?: number;
  consultResponseMinutes?: number;
}

const imageBase = 'https://101.96.228.71/objects/askxuan/temp';

// All profiles are fictional demo characters. Venue names and affiliations are real-world reference data.
export const masters: Master[] = [
  { id: 'M001', dharmaName: '明觉法师（演示）', layName: '林知远', templeId: 'T001', templeName: '灵隐寺', position: '客堂法师', beliefCode: 'han_buddhism', sect: '禅宗', type: '佛教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['禅修入门', '佛教文化', '祈愿礼仪'], avatar: `${imageBase}/20260813174243_M001.jpg`, rating: 4.9 },
  { id: 'M002', dharmaName: '玄和道长（演示）', layName: '赵清远', templeId: 'T002', templeName: '北京白云观', position: '经师', beliefCode: 'daoism', sect: '全真派', type: '道教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['道教文化', '科仪讲解', '养生导引'], avatar: `${imageBase}/20260813174246_M002.jpg`, rating: 4.8 },
  { id: 'M003', dharmaName: '延澄法师（演示）', layName: '周安行', templeId: 'T003', templeName: '嵩山少林寺', position: '禅修讲师', beliefCode: 'han_buddhism', sect: '禅宗', type: '佛教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['禅修指导', '少林文化', '静心课程'], avatar: `${imageBase}/20260813174238_M003.jpg`, rating: 4.8 },
  { id: 'M004', dharmaName: '嘉措讲师（演示）', layName: '', templeId: 'T004', templeName: '大昭寺', position: '文化讲师', beliefCode: 'tibetan_buddhism', sect: '各派共尊', type: '佛教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['藏传佛教文化', '寺院历史', '祈愿礼仪'], avatar: `${imageBase}/20260813174249_M004.jpg`, rating: 4.9 },
  { id: 'M005', dharmaName: '慧闻法师（演示）', layName: '孙明远', templeId: 'T005', templeName: '普济禅寺', position: '客堂法师', beliefCode: 'han_buddhism', sect: '禅宗', type: '佛教', authStatus: '待审核', shelfStatus: 'off_shelf', platformStatus: 'normal', specialties: ['观音文化', '佛教礼仪', '静心交流'], avatar: `${imageBase}/20260813174250_M005.jpg`, rating: 4.5 },
  { id: 'M006', dharmaName: '守一道长（演示）', layName: '张云舟', templeId: 'T006', templeName: '武当山紫霄宫', position: '经师', beliefCode: 'daoism', sect: '武当道教', type: '道教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['武当文化', '太极养生', '道教礼仪'], avatar: `${imageBase}/20260813174248_M006.jpg`, rating: 4.7 },
  { id: 'M007', dharmaName: '行愿法师（演示）', layName: '吴善行', templeId: 'T007', templeName: '九华山化城寺', position: '客堂法师', beliefCode: 'han_buddhism', sect: '地藏法门', type: '佛教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['地藏文化', '佛教礼仪', '静心交流'], avatar: `${imageBase}/20260813173804_M007.png`, rating: 4.7 },
  { id: 'M008', dharmaName: '嘉木扬讲师（演示）', layName: '', templeId: 'T008', templeName: '雍和宫', position: '文化讲师', beliefCode: 'tibetan_buddhism', sect: '格鲁派', type: '佛教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['藏传佛教文化', '建筑讲解', '祈愿礼仪'], avatar: `${imageBase}/20260813173803_M008.png`, rating: 4.7 },
  { id: 'M009', dharmaName: '静虚道长（演示）', layName: '陈守静', templeId: 'T009', templeName: '青城山天师洞', position: '经师', beliefCode: 'daoism', sect: '正一派', type: '道教', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['青城道教文化', '养生导引', '礼仪讲解'], avatar: `${imageBase}/20260813173803_M009.png`, rating: 4.6 },
  { id: 'M010', dharmaName: '林怀恩讲师（演示）', layName: '林怀恩', templeId: 'T010', templeName: '湄洲妈祖祖庙', position: '文化讲师', beliefCode: 'folk', sect: '妈祖信俗', type: '民间信仰', authStatus: '已认证', shelfStatus: 'on_shelf', platformStatus: 'normal', specialties: ['妈祖文化', '民俗礼仪', '海洋文化'], avatar: `${imageBase}/20260813173807_M010.jpg`, rating: 4.8 }
];

const consultationFees: Record<string, number> = {
  M001: 39, M002: 49, M003: 39, M004: 59, M005: 39,
  M006: 49, M007: 39, M008: 59, M009: 49, M010: 39
};

masters.forEach((master) => {
  master.consultEnabled = master.id !== 'M005';
  master.consultFee = consultationFees[master.id] ?? 39;
  master.consultValidHours = 72;
  master.consultResponseMinutes = ['M004', 'M008'].includes(master.id) ? 45 : 30;
});
