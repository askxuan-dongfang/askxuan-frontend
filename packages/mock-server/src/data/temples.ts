export interface Temple {
  id: string;
  name: string;
  region: string;
  type: string;
  beliefCode: string;
  sect: string;
  status: string;
  address: string;
  coverImage: string;
  rating: number;
  description: string;
  serviceCodes: string[];
  serviceTags: string[];
  serviceCount: number;
}

const imageBase = 'https://101.96.228.71/objects/askxuan/temp';

export const temples: Temple[] = [
  { id: 'T001', name: '灵隐寺', region: '浙江杭州', type: '汉传佛教', beliefCode: 'han_buddhism', sect: '禅宗', status: '正常', address: '浙江省杭州市西湖区灵隐路法云弄1号', coverImage: `${imageBase}/20260813173807_T001.jpg`, rating: 4.9, description: '灵隐寺创建于东晋咸和元年（326年），位于杭州西湖西面的飞来峰与北高峰之间。', serviceCodes: ['S001', 'S002', 'S006', 'S008', 'S012'], serviceTags: ['祈福', '供灯', '开光', '求姻缘', '求健康'], serviceCount: 5 },
  { id: 'T002', name: '北京白云观', region: '北京西城', type: '道教', beliefCode: 'daoism', sect: '全真派', status: '正常', address: '北京市西城区白云观街9号', coverImage: `${imageBase}/20260813173756_T002.jpg`, rating: 4.7, description: '北京白云观始建于唐代，是全真道重要祖庭和龙门派祖庭。', serviceCodes: ['S001', 'S003', 'S007', 'S009', 'S011'], serviceTags: ['祈福', '上香', '化太岁', '求财运', '求风水'], serviceCount: 5 },
  { id: 'T003', name: '嵩山少林寺', region: '河南登封', type: '汉传佛教', beliefCode: 'han_buddhism', sect: '禅宗', status: '正常', address: '河南省郑州市登封市嵩山少林景区', coverImage: `${imageBase}/20260813174105_T003.jpg`, rating: 4.8, description: '嵩山少林寺始建于北魏太和十九年（495年），是中国佛教禅宗与少林文化的重要场所。', serviceCodes: ['S001', 'S005', 'S006', 'S010', 'S013'], serviceTags: ['祈福', '超度', '开光', '求事业', '求学业'], serviceCount: 5 },
  { id: 'T004', name: '大昭寺', region: '西藏拉萨', type: '藏传佛教', beliefCode: 'tibetan_buddhism', sect: '各派共尊', status: '正常', address: '西藏自治区拉萨市城关区八廓西街2号', coverImage: `${imageBase}/20260813173802_T004.jpg`, rating: 4.9, description: '大昭寺位于拉萨老城中心，始建于公元7世纪，是藏传佛教各教派共同尊崇的寺院。', serviceCodes: ['S001', 'S002', 'S005', 'S012'], serviceTags: ['祈福', '供灯', '超度', '求健康'], serviceCount: 4 },
  { id: 'T005', name: '普济禅寺', region: '浙江舟山', type: '汉传佛教', beliefCode: 'han_buddhism', sect: '禅宗', status: '待审核', address: '浙江省舟山市普陀区普陀山镇香华街', coverImage: `${imageBase}/20260813173810_T005.jpg`, rating: 4.6, description: '普济禅寺位于普陀山白华顶南麓，是普陀山佛教活动的重要场所。', serviceCodes: ['S001', 'S002', 'S008', 'S013'], serviceTags: ['祈福', '供灯', '求姻缘', '求学业'], serviceCount: 4 },
  { id: 'T006', name: '武当山紫霄宫', region: '湖北十堰', type: '道教', beliefCode: 'daoism', sect: '武当道教', status: '正常', address: '湖北省十堰市丹江口市武当山特区紫霄村', coverImage: `${imageBase}/20260813173804_T006.jpg`, rating: 4.7, description: '紫霄宫位于武当山展旗峰下，是武当山古建筑群的重要组成部分。', serviceCodes: ['S001', 'S003', 'S007', 'S010', 'S011'], serviceTags: ['祈福', '上香', '化太岁', '求事业', '求风水'], serviceCount: 5 },
  { id: 'T007', name: '九华山化城寺', region: '安徽池州', type: '汉传佛教', beliefCode: 'han_buddhism', sect: '地藏法门', status: '正常', address: '安徽省池州市青阳县九华山风景区九华街', coverImage: `${imageBase}/20260813173807_T007.jpg`, rating: 4.8, description: '化城寺位于九华山九华街，是九华山历史悠久的开山寺院。', serviceCodes: ['S001', 'S002', 'S005'], serviceTags: ['祈福', '供灯', '追思回向'], serviceCount: 3 },
  { id: 'T008', name: '雍和宫', region: '北京东城', type: '藏传佛教', beliefCode: 'tibetan_buddhism', sect: '格鲁派', status: '正常', address: '北京市东城区雍和宫大街12号', coverImage: `${imageBase}/20260813173803_T008.jpg`, rating: 4.8, description: '雍和宫前身为清代皇家府邸，后改为藏传佛教寺院。', serviceCodes: ['S001', 'S002', 'S012'], serviceTags: ['祈福', '供灯', '求健康'], serviceCount: 3 },
  { id: 'T009', name: '青城山天师洞', region: '四川都江堰', type: '道教', beliefCode: 'daoism', sect: '正一派', status: '正常', address: '四川省成都市都江堰市青城山景区', coverImage: `${imageBase}/20260813174114_T009.jpg`, rating: 4.7, description: '天师洞位于青城山前山，是青城山道教宫观与古建筑群的重要组成部分。', serviceCodes: ['S001', 'S007', 'S011'], serviceTags: ['祈福', '化太岁', '环境咨询'], serviceCount: 3 },
  { id: 'T010', name: '湄洲妈祖祖庙', region: '福建莆田', type: '民间信仰', beliefCode: 'folk', sect: '妈祖信俗', status: '正常', address: '福建省莆田市秀屿区湄洲北大道988号', coverImage: `${imageBase}/20260813173801_T010.jpg`, rating: 4.9, description: '湄洲妈祖祖庙始建于北宋雍熙四年（987年），是妈祖信俗的重要发祥地。', serviceCodes: ['S001', 'S003', 'S004'], serviceTags: ['平安祈愿', '敬香礼仪', '民俗还愿'], serviceCount: 3 }
];
