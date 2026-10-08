# 弹层逐页代码核查与跨端规范（2026-10-08）

## 统一行为

- H5：短确认在可见视口居中；手机模型选择和商城规格为底部面板；桌面使用有最大宽度的居中窗口；历史列表为左侧抽屉。
- 使用浏览器原生顶层 dialog；全局 reset 后显式恢复 margin:auto。输入法改变 visualViewport 后更新可用宽高和偏移，不禁止缩放。
- 長内容在面板内滚动，包含安全区；关闭、Escape、焦点归还和减少动态效果沿用原生/共享实现。收银台共享可嵌套滚动锁。
- Web：所有 Element Plus Dialog/Drawer append-to-body；短窗居中，长窗正文滚动，页头和页脚保持可见。消息确认框同样受可视高度限制。
- iOS：使用系统 sheet。模型选择放到输入区；历史会话使用系统弹层；模型列表、预约/咨询、结果均可滚动；日期和固定高度结果面板允许展开。保留系统键盘避让、VoiceOver 和交互式关闭。

## 页面/组件静态核查清单

以下是逐文件定位与容器规则检查，不等同于所有页面已通过登录后的实机验收。共享组件行覆盖调用它们的路由。确认付款、发货、删除等业务不通过真实数据操作验收。

| 应用 | 文件 | 弹层入口数 |
|---|---|---:|
| web-h5 | `apps/web-h5/src/components/Cashier.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/ProfileMedia.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/Reviews.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/master/Profile.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/Rewards.tsx` | 3 |
| web-h5 | `apps/web-h5/src/routes/customer/AiReports.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/MasterProfile.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/AiExperiences.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/DiyDetail.tsx` | 3 |
| web-h5 | `apps/web-h5/src/routes/customer/CommunityDetail.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/DiyEditor.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/Points.tsx` | 2 |
| web-h5 | `apps/web-h5/src/routes/customer/WheelExperience.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/Profile.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/ShopOrderDetail.tsx` | 1 |
| web-h5 | `apps/web-h5/src/routes/customer/Ai.tsx` | 3 |
| web-h5 | `apps/web-h5/src/routes/customer/ShopDetail.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/chat/ChatRoom.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/chat/ChatCall.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/auth/AccountAccess.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/shop/ShopSheet.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/profile/ProfileEditor.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/ai/AiModelPicker.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/ai/AiMemory.tsx` | 1 |
| web-h5 | `apps/web-h5/src/components/ai/AiDialog.tsx` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/components/AuditAction.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/OnboardingReviewView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/CommerceView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/settings/SettingsDictView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/settings/SettingsRoleView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/settings/SettingsTaxonomyView.vue` | 2 |
| web-platform-admin | `apps/web-platform-admin/src/views/settings/SettingsAccountView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/audit/ContentReportView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/audit/ContentDesignView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/master/MasterListView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/ai/KnowledgeLibrary.vue` | 4 |
| web-platform-admin | `apps/web-platform-admin/src/views/ai/KnowledgeWiki.vue` | 2 |
| web-platform-admin | `apps/web-platform-admin/src/views/ai/KnowledgeModels.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/ai/EntityGraph.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/ai/WikiEditor.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/ai/AgentOperationsView.vue` | 3 |
| web-platform-admin | `apps/web-platform-admin/src/views/marketing/MarketingCouponView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/marketing/MarketingBannerView.vue` | 2 |
| web-platform-admin | `apps/web-platform-admin/src/views/marketing/RewardsView.vue` | 3 |
| web-platform-admin | `apps/web-platform-admin/src/views/marketing/MarketingActivityView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/views/temple/TempleReviewView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/commerce/views/PointsMallView.vue` | 2 |
| web-platform-admin | `apps/web-platform-admin/src/commerce/views/DiyOrderDetailView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/commerce/views/OrderDetailView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/commerce/views/CategoryManageView.vue` | 1 |
| web-platform-admin | `apps/web-platform-admin/src/commerce/views/LogisticsView.vue` | 2 |
| web-platform-admin | `apps/web-platform-admin/src/commerce/views/ReturnDetailView.vue` | 1 |
| web-temple-admin | `apps/web-temple-admin/src/views/ReviewListView.vue` | 1 |
| web-temple-admin | `apps/web-temple-admin/src/views/TempleGalleryView.vue` | 1 |

## 回归方式与验收边界

- 三个 Web 应用分别执行 build，H5 执行 test:navigation / test:auth。
- `e2e/playwright.overlay-position.config.ts`：生产构建配合本地 API fixture，390×640、768×900、1440×900、812×375；检查中心点、边界、页脚/关闭按钮以及根部挂载。
- `e2e/playwright.ai-models.config.ts`：手机底部模型面板、桌面居中、模型失败/重试、短视口、Escape、焦点恢复和草稿保持。
- iOS 两个 workspace 使用 generic iOS Simulator、CODE_SIGNING_ALLOWED=NO 编译。此产物不等同于真机或 TestFlight 发布。
- Ego Lite 当前任务被用户接管，等待明确恢复后进行已登录逐页视觉复核；不以代码扫描或 CI 替代该验收。
