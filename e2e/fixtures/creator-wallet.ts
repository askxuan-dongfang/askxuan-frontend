export const emptyCreatorWallet = () => ({
 account:{availableCents:0,heldCents:0,paidCents:0},pendingCents:0,
 rewards:[],withdrawals:[],total:0,withdrawalTotal:0,
 policy:{enabled:true,kind:'cash',rateBps:500,capCents:2000,waitDays:7,minWithdrawCents:100},
});
