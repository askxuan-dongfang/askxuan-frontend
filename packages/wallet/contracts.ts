export interface WalletRefund { id: number; refundNo: string; amountCents: number; status: string; reason: string; createdAt: string }
export interface WalletEntry { id: number; paymentNo: string; orderType: string; orderNo: string; amountCents: number; channel: string; status: string; createdAt: string; refunds: WalletRefund[] }
export interface CustomerWallet { summary: {paidCents:number;refundedCents:number;refundingCents:number}; list:WalletEntry[]; total:number;page:number;pageSize:number;mode:string }
export interface Settlement {id:number;number:string;sourceType:string;sourceNo:string;grossCents:number;commissionCents:number;netCents:number;status:string;createdAt:string}
export interface Withdrawal {id:number;number:string;amountCents:number;status:string;createdAt:string}
export interface ProviderWallet {summary:{pendingCents:number;confirmedCents:number;recordedPaidCents:number};settlements:Settlement[];withdrawals:Withdrawal[];total:number;withdrawalTotal:number;page:number;pageSize:number;withdrawEnabled:boolean;recordMode:string}
export const money=(cents:number)=>new Intl.NumberFormat('zh-CN',{style:'currency',currency:'CNY'}).format(cents/100);
export const paymentStatus:Record<string,string>={pending:'待支付',success:'支付成功',failed:'支付失败',refunding:'退款中',refunded:'已退款',closed:'已关闭'};
export const refundStatus:Record<string,string>={pending:'待处理',processing:'退款处理中',success:'退款完成',failed:'退款失败'};
export const settlementStatus:Record<string,string>={pending:'待确认结算',confirmed:'已确认结算',paid:'账面已结算'};
export const withdrawalStatus:Record<string,string>={pending:'待审核',approved:'审核通过',processing:'模拟处理中',success:'模拟完成',failed:'模拟失败',rejected:'审核拒绝'};
export const orderType:Record<string,string>={booking:'预约服务',consultation:'即时咨询',shop_order:'商城购物',diy_order:'DIY 手串',ai_report:'AI 报告'};
