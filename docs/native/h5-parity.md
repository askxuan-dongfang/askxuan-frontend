# iOS / H5 页面、功能和动效对应

基线：H5 `ce109474721c34e666a9152bfc96bed79e414d42`，共享前端 `fa4a287a34fdf555f41ed58031d7b6ba9990ba06`。2026-10-15。

保留信众与大师两个原生 iOS 应用，按 H5 的产品入口、数据契约与操作语义对齐。原生 push/pop、交互式返回、系统 sheet、相册和分享使用系统实现；局部按压、选中、展开使用同源动效参数，并遵循“减少动态效果”。下面是源码入口对应，不代表每个生产账号和业务状态均已端到端实测。

| H5 页面 / 功能 | 信众原生入口 |
| --- | --- |
| `/c`、推广活动、信仰专题、7 类心愿 | HomeView、NativeMarketingActivityView、BeliefTopicView、IntentionHubView |
| 寺院目录、详情、寺院服务预约 | TempleListView、TempleDetailView、ServiceContainerView |
| 大师目录、详情、服务预约、咨询购买 | MasterListView、MasterProfileView、BookingView；心愿传递 serviceCode |
| `/c/services`、13 类标准服务详情 | ServicesView、ServiceContainerView；首页“查看全部服务” |
| 对话、会话详情、社区、短视频、直播 | ChatView、ChatExperienceView、CommunityPlazaView、CommunityPostDetailView、CommunityVideoFeedView、LiveViewerView |
| AI 发现、专题、问事、示例、报告、笔记 | AiDiscoveryView、AiDivinationView、AiExperienceView、AiReportTopicEntry、AiReportExampleView、AiReportWorkspace、AiNotebookView、AiSavedNoteView |
| 商城、商品详情、购物车、结算、订单和售后 | ShopView、ShopProductDetailView、ShopCartView、ShopCheckoutView、ShopOrderListView、ShopOrderDetailView |
| DIY 广场、2D/3D 编辑、设计详情、我的设计和订单 | DiyBraceletView、DiyDesignView、DiyDetailView、DiyMyDesignsView、DiyOrderView、OrderListView |
| 服务订单、履约进度、评价 | OrderListView、CustomerBookingDetailView、JourneyCenterView、JourneyDetailView、ReviewListView |
| 我的、收藏、消息、地址、资料、安全和外观 | ProfileView、ProfileSubPages、NativeMessageCenterView、AppearanceSettingsView |
| 积分、优惠券、活动奖励 | PointsView、CouponView、RewardsView、RewardDetailView |
| 消费钱包、充值、退款、创作收益和提现 | WalletView、CashBalanceView、CreatorWalletView |
| 邮箱登录、注册、恢复账号 | LoginView |

| H5 大师页面 / 功能 | 大师原生入口 |
| --- | --- |
| 工作台、待办、指标 | WorkspaceView |
| 登录、注册、入驻及审核状态 | LoginView、MasterOnboardingView |
| 预约列表、详情、日历 | BookingsView、BookingDetailView、CalendarView |
| 履约中心、详情、加持任务 | JourneyCenterView、JourneyDetailView、BlessingTasksView、BlessingTaskDetailView |
| 对话列表和详情 | MessagesView、ChatExperienceView |
| 收入、账单历史、提现 | EarningsView、EarningsHistoryView |
| 定价、服务标签、资料、评价、设置 | PricingView、ServiceTagsView、ProfileView、ProfileEditView、ReviewsView、SettingsView |
| 内容、图文/视频上传、草稿、审核、直播 | MediaStudioView；工作台和个人中心均可进入 |

## 本次消除的差异

1. 创作收益从“我的 → 钱包”进入，与消费余额分开；服务端奖励策略、奖励明细、提现记录、申请表单、失败重试与幂等请求标识均接入已有 API。金额使用 Decimal 转整数分，不通过浮点计算。无真实资金验收写入。
2. 寺院/大师目录补齐地区、宗派/信俗；支持与信仰、服务等筛选求交集；地区与宗派来自服务端目录。获取完整分页数据后筛选，避免仅前 100 条；清除筛选同时恢复新增条件。
3. 大师价格区间对齐 H5 的 200 / 500 / 1000 元边界，按可用服务价格计算；禁用服务不参与可约筛选。心愿选定服务进入大师详情后保留上下文。
4. 补齐首页公共服务目录；大师个人中心补内容与直播入口，异步提交时锁定控件，限制重复提交和文本长度。
5. `scripts/sync-motion.mjs` 从 `packages/design-tokens/tokens.json` 同时生成 H5 CSS 和两端 Swift 动效参数；`--check` 检测漂移。按压 120ms，选中 180ms，展开 240ms，退出 140ms；保留系统导航手势。
6. 两个 Web 后台共用一个 Mac 原生容器，Web 页面本身不复制实现；平台、寺院独立持久会话，支持原生桌面操作。

## 持续检查

```sh
node scripts/sync-motion.mjs --check
python3 apps/ios-customer/scripts/native-parity-fixture.py
# iOS：Xcode 运行 DongFangAppTests/H5ParityTests 与 H5ParityUITests。
# 两端 UI tests 使用上述 http://127.0.0.1:5399 的只读合成数据服务。
# 另一个终端可执行：bash apps/ios-customer/scripts/test-auth-expiry.sh
# Mac：Xcode 运行 AskXuanAdminTests。
```

运行证据、截图、签名/公证边界和实际验证结果见工作区 `artifacts/native/2026-10/native-parity-mac-20261015/ACCEPTANCE.md`。源码对应不替代真机 GPU、相机、支付、推送或真实提现验收。

2026-10-15 本地验收：两端 iOS 模拟器构建、4 个金额/筛选测试函数（13 组用例）、74 项会话恢复断言、5 条原生 UI 流程、3 个 Mac 规则测试函数（7 组用例）通过。UI 流程包含五主导航切换、目录条件及返回、收益表单、公共服务目录、大师内容入口。Mac Universal Release 包已在本机打开两个线上后台登录页并验证切换，尚未完成已登录后台业务、真机及 Developer ID 公证验收。
