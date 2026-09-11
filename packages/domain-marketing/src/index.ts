export interface HomePromotion {
  id: number; title: string; placement: string; imageUrl: string; linkType: string;
  linkValue: string; sort: number; status: string; startTime: string; endTime: string;
}
export const promotionTargets = [
  { value: 'temple', label: '寺院详情', placeholder: '寺院编号，例如 T001' },
  { value: 'master', label: '大师详情', placeholder: '大师编号，例如 W001' },
  { value: 'product', label: '商品详情', placeholder: '商品编号' },
  { value: 'service', label: '服务详情', placeholder: '服务编号，例如 S001' },
  { value: 'activity', label: '营销活动详情', placeholder: '营销活动编号' },
  { value: 'reward', label: '免费活动详情', placeholder: '免费活动编号' },
  { value: 'ai', label: 'AI 问事', placeholder: '' },
  { value: 'diy', label: 'DIY 手串定制', placeholder: '' },
  { value: 'ad_landing', label: '站内功能页', placeholder: '/c/shop、/c/masters、/c/temples 等' },
];
const paths: Record<string, string> = {temple:'/c/temples/',master:'/c/masters/',product:'/c/shop/',service:'/c/services/',activity:'/c/activities/',reward:'/c/rewards/'};
const landings = new Set(['/c/ai','/c/diy','/c/shop','/c/rewards','/c/temples','/c/masters','/c/services']);
export function promotionHref(b: Pick<HomePromotion,'linkType'|'linkValue'>): string | null {
  if (b.linkType === 'ai' || b.linkType === 'diy') return b.linkValue ? null : `/c/${b.linkType}`;
  if (b.linkType === 'ad_landing') return landings.has(b.linkValue) ? b.linkValue : null;
  return paths[b.linkType] && /^[A-Za-z0-9_-]+$/.test(b.linkValue) ? paths[b.linkType]+b.linkValue : null;
}
export function promotionImageURL(value: string): boolean {
  if (/[\\\r\n]/.test(value)) return false;
  if (/^\/(?!\/)/.test(value)) return true;
  try {const u=new URL(value);return u.protocol==='https:' && !!u.hostname && !u.username && !u.password;} catch{return false;}
}
export function promotionTime(value: string, end = false): number {
  if (!value) return end ? Infinity : -Infinity;
  if (!/^\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?$/.test(value)) return NaN;
  return Date.parse((value.length===10 ? `${value}T${end?'23:59:59':'00:00:00'}` : value.replace(' ','T'))+'+08:00');
}
export function promotionPhase(b: Pick<HomePromotion,'status'|'startTime'|'endTime'>, now = Date.now()): string {
  if (b.status==='draft') return '草稿';
  if (b.status!=='enabled') return '已下架';
  const start=promotionTime(b.startTime),end=promotionTime(b.endTime,true);
  if (Number.isNaN(start)||Number.isNaN(end)||start>end) return '时间无效';
  if (now<start) return '待开始';
  if (now>end) return '已结束';
  return '展示中';
}
export function visiblePromotions(list: HomePromotion[], now = Date.now()): HomePromotion[] {
  return list.filter(b=>b.placement==='customer_home'&&promotionPhase(b,now)==='展示中'&&promotionImageURL(b.imageUrl)&&promotionHref(b))
    .sort((a,b)=>a.sort-b.sort||b.id-a.id);
}
