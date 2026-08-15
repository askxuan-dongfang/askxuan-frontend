# 三端 Vue 3 管理台代码评审报告（web-temple-admin / web-shop-admin / web-platform-admin）

审查范围：`/Users/gaofeng/develop/DongFang/askXuan-frontend/apps/{web-temple-admin,web-shop-admin,web-platform-admin}`。方法：read/grep 逐文件核实 + 3 个子代理逐行审计视图层（temple 15 页 / shop 17 页 / platform 25 页；shop 逐页报告另存档于同目录 `shop-admin-views-audit.md`）。以下路径均相对 `askXuan-frontend/`。

---

## 1. 跨三端代码复用程度：几乎零共享，复制粘贴后各自演化

### 三端复用对比表

| 文件 | temple 行数 | shop 行数 | platform 行数 | diff 结论 | 关键差异（行号证据） |
|---|---|---|---|---|---|
| `src/api/client.ts` | 118 | 118 | 116 | **基本相同**（仅字符串前缀替换） | 差异仅为 `X-Client-Type` 与 localStorage key：temple:12,20,25,34,42,48,63-64,92-93 ↔ shop:12,20,25,34,42,48,63-64,92-93 ↔ platform:12,20,25,34,42,48,63-64,90-91（值 `temple-admin/shop-admin/platform-admin`、key `df_temple_admin_*/df_shop_admin_*/df_platform_admin_*`）。platform 响应拦截器签名 `(response: AxiosResponse)`（platform:54）无泛型，另两端为 `AxiosResponse<ApiResponse>`（temple:54）；platform 少 2 行。其余结构逐行相同：baseURL `'/api/v1'`（:8）、`as any` 解包（:58,73）、40101 登出（:61-68）、refresh 重试（:75-89）、`as unknown as Promise<T>`（temple:104-115） |
| `src/stores/auth.ts` | 83 | 62 | 48 | **微差→结构不同** | temple 独有：templeId/templeName 状态与 `setTemple`（:59-63）、默认兜底 `T001/灵隐寺`（:13-14）、五把 key 常量（:6-10）、`persist()` 统一落盘（:34-43）；shop 独有：`isLoggedIn/nickname` getter 与 `setSession`（:17-18,31-38）、`JSON.parse` 无 try/catch（:12-14，脏数据即崩）、末尾 `export { client }` 死导出（:62，全库无人引用）、无 templeId；platform 最精简：常量 key（:7-9）、try/catch 读 user（:14-23）、无 templeId。登出：temple:65-70 / shop:41-48 / platform:38-45 |
| `src/utils/format.ts` | 127 | 142 | 67 | **不同** | 同名函数仅 `formatDate/formatMoney`，签名互不兼容：formatDate temple:5（`withTime` 参数）、shop:7,15（拆 formatDate/formatDateTime 两个）、platform:26（`fmt` 参数）；**`formatPercent` 语义相反**——temple:19-22 `Number(n).toFixed(digits)+'%'`（不乘 100，且全库从未被调用=死函数），platform:19-23 `(num*100).toFixed(digits)+'%'`（用于 FinanceTempleView.vue:34 佣金率）；状态映射为各端领域私有：temple booking/service/master/temple/review/blessing（:25-114）+ `parseImages`（:118-127）、shop product/order/return/enabled（:31-135）+ `nameInitial`（:140-142）、platform maskMobile/maskBankCard/safeJsonParse/truncate（:38-67） |
| `src/components/DataTable.vue` | 62 | 49 | 116 | **完全不同** | temple=分页表格封装（el-table+el-pagination，:27-52；generic `T extends Record<string,any>` :1；`rowKey/height` :9-10）；shop=**卡片容器**（仅 `title/padding` 两个 prop，:3-9，不接收任何表格属性）且**全库零引用死代码**（全 src grep 仅命中自动生成声明 `types/components.d.ts:10`）；platform=功能最全的表格（selection/index 列 :13-14、`v-model:page/size` 双向绑定 :62-67、sort-change :66,90、`data: any[]` :40） |
| `src/components/PageHeader.vue` | 51 | 49 | 39 | 微差 | 结构同（title/subtitle/操作槽），但槽名不同：temple 默认 slot（:12）/ shop `extra`（:19）/ platform `actions`（:8）；样式来源不同：temple 硬编码 hex（标题 `#2a1e1a` :28、装饰条渐变 `#c45a3c→#c8a96e` :37）/ shop `var(--text-dark)`（:36）/ platform `var(--color-text-primary)` + `dfx-serif`（:4,31） |
| `src/components/StatCard.vue` | 102 | 89 | 79 | 微差 | props API 三套：temple `title/icon/tone/suffix/trend`（趋势数值+箭头 :30,43-46，硬编码 hex 色表 :22-28）/ shop `label/change/up/color`（CSS 变量 :69-73；模板用 `CaretTop/CaretBottom` 但 script 未 import :32，靠 main.ts 全局图标注册兜底）/ platform `label/prefix/suffix/iconColor/extra`（无趋势 :26-27，`iconBg` 拼 `22` 透明度 :30） |
| `src/components/StatusTag.vue` | 55 | 57 | 76 | 微差 | 分发机制不同：temple `kind` 分发到 format.ts（:15,18,20-50）/ shop `domain` 分发到 format.ts（:14,21,24-52）/ platform 内置大 `STATUS_MAP`（:20-57）且默认 `effect:'dark'`（:16，另两端 `light`） |
| `src/components/ImageUploader.vue` | 152 | 160 | 63 | **不同** | temple 单图+拖拽+手动 URL（:8-11,17-36；hint 写 2MB 但无实际校验 :10）；shop 多图 picture-card+limit8+10MB 校验（:10-19,101-111）；platform 单图精简（:12-30，10MB 内联校验 :13）。上传端点均写死 `/files/upload`（temple:10 / shop:81 / platform:21） |
| `src/layouts/DefaultLayout.vue` | 240 | 346 | 282 | **不同** | temple el-container+硬编码菜单+寺院名 tag（:101）；shop div 布局+固定侧栏+分组菜单+`@media` 响应式收窄（:334-345）+写死角色文案"商城运营"（:129）；platform el-container+可折叠（`collapsed` :92）+`menuGroups` 数据驱动菜单（:94-156）。三端菜单均为**布局内硬编码**，与 router 双份维护 |
| `src/styles/tokens.css` | 53 | 53 | 53 | **逐字节完全相同** | 三份内容一致（--color-bg-primary:#1C1210 等暗色变量）。注释不同：temple 手抄"复制自 packages/design-tokens"（:4），shop/platform "Auto-generated, Do not edit manually"（:3-4）。注：tokens 是暗色主题，但 temple/shop 实际用浅色主题（各自 index.css 重定义 --el-* 变量），仅 platform 真正消费这些变量 |
| `src/types/index.ts` | 224 | 299 | 386 | **不同** | 仅 `ApiResponse`（temple:4-8/shop:5-9/platform:4-8）与分页结构（temple:11-22 `PageResult`/platform:11-22 同；shop:12-17 命名 `Page<T>`）相同；其余领域类型各自定义（temple Temple/Booking/Master/BlessingTask…、shop Product/Order/Return/DiyOrder…、platform Settlement/Withdrawal/Audit/…）。temple 版 tab/空格缩进混排（:74,88-95,129-135） |

**共享包结论**：三端 `src/` **零** `@dongfang/*` 或 `packages/` import（grep 全库仅命中 package.json name 字段；platform name 为裸 `web-platform-admin`，另两端为 `@dongfang/web-*`）。唯一跨包引用是 **web-shop-admin/tailwind.config.ts:4** `import tokens from '../../packages/design-tokens/dist/web/tailwind-tokens.js'`（构建期相对路径，非 workspace 依赖）；temple 刻意内联色板"避免构建期依赖 monorepo packages 路径"（temple tailwind.config.ts:3）；platform 映射到 CSS 变量（platform tailwind.config.ts:8-31）。仓库根**无 package.json/workspaces**，三 app 独立 node_modules + 各自 package-lock。

**结论**：三端为"同一模板复制三次后各自演化"——`client.ts` 仍是复制粘贴（唯一差异是前缀字符串），`tokens.css` 原样拷贝；组件（尤其 DataTable）与工具函数已严重漂移，**不存在任何跨端共享抽象**。

## 2. 路由守卫与权限控制：仅登录态守卫，无 RBAC

三端均有 `beforeEach` 守卫，逻辑等价：`meta.public` 放行、未登录跳 `/login?redirect=...`、已登录访问 login 跳 `/dashboard`：
- temple：`apps/web-temple-admin/src/router/index.ts:112-126`（返回式 `(to)=>`，:115 设 document.title，:118 已登录访问 login 跳 /dashboard，:122-124 未登录跳转）
- shop：`apps/web-shop-admin/src/router/index.ts:144-167`（`(to,_from,next)` 回调式，:147-149 标题，:153-154 login 重定向，:161-163 未登录跳转）
- platform：`apps/web-platform-admin/src/router/index.ts:183-199`（回调式，:185 标题，:187-192 login 重定向，:194-198 未登录跳转）

**无任何角色/权限校验**：三端守卫均只查 `isLogin/isLoggedIn`（token 存在性）；**无** `meta.permission`/`roles` 字段、**无**动态路由、**无**按钮级权限。platform meta 仅多 `parent`（面包屑）/`hidden`（详情页隐藏菜单）：router:31,37,69。三端路由结构同构：login 公开路由 + `/`(DefaultLayout) 子路由 + 通配 `/:pathMatch(.*)* → /dashboard`（temple:103 / shop:132-134 / platform:173）。差异：temple 路由 name 用 kebab-case（`master-list`，:38），shop/platform 用 PascalCase（`ProductList`，shop:28）；注释条数与实际不符（shop router:1 声称"17 条路由"实为 16 子路由；platform router:1 声称"23 条"实为 24 子路由）。

**登录态持久化（localStorage key 各不同，是三端身份隔离的唯一手段）**：
- temple：`df_temple_admin_token/refresh_token/user/temple_id/temple_name`（auth.ts:6-10），默认兜底 `T001/灵隐寺`（:13-14）
- shop：`df_shop_admin_token/refresh_token/user`（auth.ts:10-12）
- platform：`df_platform_admin_token/refresh_token/user`（auth.ts:7-9）

**角色区分现状**：仅靠"localStorage key 前缀 + `X-Client-Type` 请求头 + 演示账号"（temple `lingyin_admin`、shop `admin`、platform `admin`），无任何服务端角色校验。platform 有完整角色/账号管理 API 与 UI（`api/auth.ts:46-63` 角色 CRUD+权限列表；SettingsRoleView；SettingsAccountView:151-153 按 `temple_admin/master/shop_admin` 联动绑定 templeId/masterId/shopId），但**没有任何校验落点**——"角色权限"只有管理界面，未接入路由守卫或按钮。shop 的"角色"仅是侧栏写死文案（DefaultLayout.vue:129）。

**登出**：三端 store 均清状态+localStorage（temple auth.ts:65-70 / shop:41-48 / platform:38-45）；temple 另在 SettingsView.vue:39 提供 `localStorage.clear()`（清同源全站存储，范围过宽）。

## 3. 网络层：三端同构的复制粘贴 axios 封装

- **baseURL**：三端均硬编码 `'/api/v1'`（temple client.ts:8 / shop:8 / platform:8），无环境变量；refresh 调用写死绝对路径 `/api/v1/auth/refresh`（temple:37）。
- **vite proxy**：三端 `server.proxy['/api'] → http://localhost:8080`（temple vite.config.ts:16-22 / shop:33-39 / platform:16-21），指向真实网关；**与 mock-server 无关联**（mock-server 在 packages/mock-server，监听 3001，index.ts:9；三端 proxy 均不指向它）。
- **请求拦截器**：读 localStorage token 注入 `Authorization: Bearer`（temple:18-31）；再次设置 `X-Client-Type/X-Client-Version`（temple:24-27，与 create 时重复）。
- **响应拦截器**：解包 `{code,message,data}` 直接返回 `data`（`res as any`，temple:58,73）；`code!==0` 全局 `ElMessage.error`（:69）；`40101` 清 token 并 `window.location.href = BASE_URL+'login'`（:61-68，temple 生产 BASE_URL=`/temple/` 跳转正确）；HTTP 401 先 `refreshAccessToken()` 重试一次（:75-89），失败再登出（:90-94）。
- **类型**：`client.get/post/put/delete` 全 `as unknown as Promise<T>` 强转（temple:104-115）。
- 该封装三端几乎逐字节相同（仅前缀），是"应抽共享包未抽"的最典型样本（见 §1）。

## 4. mock / 假数据

- 三端 src grep `mock|sample|dummy|假数据`：**仅注释命中**——temple auth.ts:12（"Mock 账号 lingyin_admin 对应灵隐寺，默认 templeId 兜底"）、shop auth.ts:24（"禁止 Mock 兜底（安全要求）"）。**管理台页面无 mock 数组**。
- 但存在假数据/伪功能：
  - **shop DashboardView.vue:37-38** `Math.round(2000+Math.random()*3000)` / `Math.random()*20` 生成"近 7 日销售趋势"（纯随机数）；**:103-110** "今日订单/今日销售额/待发货"基于 `orderApi.list({page:1,size:5})` 抽样计算（抽样当全量，数值必然失真）；**:106** `new Date().toISOString()` 按 UTC 取日期与本地 createTime 比较会错位（北京 0-8 点订单算不进今日）。
  - **shop MaterialListView.vue:78-90,185**：删除按钮是假实现——弹确认框后仅 `ElMessage.info('材料暂不支持物理删除，请使用下架')`（:86 注释自认"无独立删除接口"），:185 仍渲染红色"删除"按钮。
  - **shop ReportView.vue:34-45**：接口失败时 catch 静默渲染**全零假数据**，用户无法区分"无数据"与"请求失败"。
- **演示账号硬编码进登录表单并明文展示**：temple LoginView.vue:14（`lingyin_admin/123456`）+ :89 明文提示；shop LoginView.vue:16-17（`admin/123456`）+ :102；platform LoginView.vue:46 + :28。shop 另有 `remember` 复选框无效（LoginView.vue:18,98，从未被读取）与 `<a href="#">忘记密码？</a>` 死链（:99）。
- 硬编码字典/选项：platform MasterListView.vue:18-19（佛教/道教）、SettingsDictView.vue:70-75（政治/宗教/低俗/广告）、MarketingActivityView.vue:83-87、MarketingCouponView.vue:99-104、MarketingBannerView.vue:95-101；shop MaterialListView.vue:24-32（与 MaterialEditView.vue:42-50 整份重复，且与 format.ts:124-135 `materialCategoryLabel` 职责重叠）、OrderDetailView.vue:30 与 DiyOrderDetailView.vue:30 快递公司数组重复（而 LogisticsView 有快递公司 API 管理）、LogisticsView.vue:157 运费 JSON 默认值硬编码。
- proxy 均指向网关 8080，未指向 packages/mock-server（3001）。

## 5. 各端视图完成度审计

**temple（15 页，13 完整 / 2 演示残留，无占位空页）**——职责与证据：
- DashboardView（工作台聚合）完整；`Promise.allSettled` 静默吞错（:30-43）、`getTempleReport()` 无参（:42）
- LoginView（登录）完整但**演示残留**：:14 硬编码账号密码、:89 明文展示、:29 open-redirect 未校验、:31-32 catch 空块
- TempleInfoView / TempleGalleryView 完整；TempleGalleryView.vue:55-64 `ElMessageBox.confirm` 无 .catch（取消即 unhandledrejection）、:35 `sort=list.length+1` 推断排序
- MasterListView 完整；MasterEditView **缺陷**：:51-57 用 `listMasters({page:1,size:200})` 全量+find 顶替详情接口（>200 人误报"未找到"并 router.back）、:34 `type:'佛教'` 硬编码默认
- ServiceListView **缺陷**：:68 `DataTable :total="0"` 硬编码关闭分页、:19-21 前端 filter 替代服务端筛选、:26-27 一次全量拉取；ServiceEditView **缺陷**：:57-63 同 MasterEditView 全量 find、:67-70 硬编码 `capacity:10,status:'enabled'`、:112 `addSlot` 硬编码 09:00-10:00、tab 缩进混排
- BookingListView/BookingDetailView 完整（BookingDetailView:139 直接展示 userId 未脱敏、:132-137 缩进混排）
- BlessingTaskListView 完整但 :29-33 请求不带 templeId（数据隔离缺口待确认）；BlessingTaskDetailView **语义错配**：:47 把选中 `master.id` 传给形参 `masterCode`（api/blessing.ts:19），而 types/index.ts:102-116 Master **无 masterCode 字段**；:34 回显值类型不一致；:22 `Number(route.params.id)` 无校验
- ReviewListView 完整但 :66 `String(auth.userInfo?.userId ?? '0')` 以 `'0'` 作 replierId 落库、:29 `targetType:'booking'` 硬编码
- ReportView 完整（真实报表 API，三图）；:95 `(p:any)` 滥用、:22-36 无 catch
- SettingsView 完整；:12 `templeFormRef` 声明未使用（死代码）、:39 `localStorage.clear()`

**shop（17 页，12 完整 / 5 部分完成，无占位空页）**——（逐页完整报告见同目录 `shop-admin-views-audit.md`）：
- **部分完成**：DashboardView（:37-38 随机数趋势、:103-110 抽样统计、:106 UTC 错位、:111-120 静默吞错）；MaterialListView（:78-90,185 假删除、:24-32 分类数组重复、:68,78 `row:any`）；MaterialEditView（:58-59 `list(size:100)+find` 顶替详情、>100 条无法编辑且无提示；:54-75 无 catch；:42-50 分类数组重复）；ServiceEditView（:39-40 同上兜底；:101-107 寺院/法师裸编码手填、placeholder 硬编码 `lingyin-temple/master-001`；:35-54 无 catch）；ReturnDetailView（:26-28 注释自认"后端未提供详情接口"，`returnList({page:1,size:200})+find`，>200 条显示"未找到"；:68-82 handleRefund 无 catch；:106 退款条件含 `refunding` 状态机可疑）
- 完整页共性问题：ProductListView:74,84 `row:any`、:29 分类 `size:100` 上限；ProductEditView:48 同、:55-75 无 catch、:163-166 运费模板手填裸 ID；CategoryManageView:42,54,88 `any`、:155-158 父级裸 ID 输入、:34 `size:100`；OrderListView:70 副标题称"支持发货"但页面无发货操作；OrderDetailView:30 快递硬编码、:22-61 发货弹窗与 DiyOrderDetailView:22-102 整段重复、:98 只显示 addressId 裸 ID；DiyOrderListView:108 状态列渲染英文裸值、:71 副标题"审核与发货"但列表无操作；**DiyOrderDetailView:131 发货条件 `status==='paid'||status==='approved'`——`approved` 不在列表枚举 DiyOrderListView:21-29 中，且 `paid`（审核前）即可发货，契约矛盾**；LogisticsView（485 行三模块）:439-446 运费规则裸 JSON 无校验、:262 `(name:any)`、:104-113/203-212 启禁用失败静默；ReportView:163 `(params:any)`、:130 `top.slice(0,10).reverse()` 依赖后端已排序、:34-45 全零兜底；ReturnListView:98-100 三元标签可读性差；ServiceListView:44 `row:any`、:81,86 兜底显示说明字段不全；LoginView:16-17,102 硬编码凭证、:18,98 remember 无效、:99 死链

**platform（25 页，23 完整 / 2 部分完成，无占位空页）**：
- **部分完成**：SettingsRoleView（:30-38 权限点表格只读，**无任何角色-权限绑定/授权 UI**，页面名"角色权限"名不副实；:36 权限点列只有 action 展示；角色列表无分页）；FinanceMasterView（:52-78 提现 tab 完全只读，无审核/打款入口；:124-129 confirmSettle 无行级 loading/防重复点击，对照 FinanceTempleView:92-102 有 `_saving`）
- 完整页共性问题：LoginView:28,46 硬编码演示账号、:63 `catch(e:any)`（全目录唯一 any）且与 client.ts 拦截器重复弹错（双重 toast）；DashboardView:147,152 用魔法数组下标 `todos.value[4]/[2]` 写计数、5 路 Promise.allSettled 静默丢失败；TempleListView:91-92、MasterListView:124 筛选项从"当前页"数据 computed 派生（翻页后选项随页变化甚至消失）、TempleListView:132 用 `row.id` 当 templeCode 传参；MasterListView:18-19 类型硬编码、:117,155-157 咨询费默认值 `39/72/30` 魔法数写两遍、:143 onStatus 参数 `string` 未用联合类型、:59-64 缩进混排；ContentCommentView:76 / ContentDesignView:86 auditorId 缺省 `'0'` 落库、两文件结构几乎逐行重复；ContentReportView:35,40,46 模板内 `evidenceUrls()` 重复解析 3 次、:150 handlerId `'0'` 兜底；FinanceOverviewView:112-123 `configLoading` 在 await 之后才置 true（表格 v-loading 覆盖不到请求期）、:47 `row._saving` 动态属性；FinanceTempleView:74 `settleType:'temple'` 硬编码、与 FinanceMasterView 结算表格 90% 重复；MarketingActivityView:61,139-155 config JSON 文本无 parse 校验可落库非法 JSON、:83-87 类型硬编码；MarketingCouponView:37 `progress()` 每行调用 2 次、:69 折扣券 `el-input-number` 无 `:max`（可输 99 折）、:99-104 类型硬编码；MarketingBannerView:95-101 linkTypes 硬编码、:178-183 toggle 无确认（其它状态操作均有）；SettingsAccountView:114 `roleId:2` 魔法默认值、:79 中文字面量 `'已认证'` 与英文 `'normal'` 混用比较、:181-182 下拉数据 `size:100` 写死（>100 选不到）、:83-84 商铺手输 ID 无下拉、:131-139 三个 find 兜底函数冗余；SettingsBackupView:14 "私有对象存储"、:24 "手动全量" 写死文案不读数据、:59 假设备份列表已按时间倒序取 [0]、:83-86 window.open 无兜底；SettingsDictView:91-92 `(c as 'political')` 类型断言 hack、:70-75 分类硬编码；SettingsLogView:62-64 bizTypeText 只映射 4 类；SettingsTaxonomyView:16-17 icon 默认 `'sparkles'`、landingType 默认 `'aggregate'` 硬编码、script 在 template 前（风格不一致）、保存无 loading；UserListView:95-102 confirm 取消 rejection 未捕获；MasterReviewView:47 内联箭头每行建新函数；TempleDetailView:26 `rating?.toFixed(1)` 无兜底、:89 路由参数无校验；UserDetailView:36,42 preferenceTags 未判空；FinanceReconcileView:118 then/catch 模拟取消判断可读性差、:145-148 切 tab 重复请求

**占位结论**：三端 **57 页均无空模板/TODO/console.log 占位页**（grep 零命中）；问题集中在"演示残留、列表顶替详情、假数据、缺 detail 接口、状态机/枚举不一致"。

## 6. 依赖与构建差异

| 项 | temple | shop | platform |
|---|---|---|---|
| package name | `@dongfang/web-temple-admin`（package.json:2） | `@dongfang/web-shop-admin`（:2） | `web-platform-admin`（:2，无 @dongfang 前缀） |
| build script | `vue-tsc --noEmit && vite build`（:9） | 同左（:9） | **`vue-tsc -b && vite build`**（:9，项目引用模式） |
| auto-import | **无**（README.md:9 声称"按需自动导入"与实际 main.ts:14 全量 `app.use(ElementPlus)` 不符） | **有**：`unplugin-auto-import ^0.17.6` + `unplugin-vue-components ^0.27.0`（package.json:29-30）；main.ts 不 use ElementPlus，全局注册全部图标（main.ts:12-14）；dts 已提交（types/auto-imports.d.ts、components.d.ts） | 无；main.ts 全量 + **引入 `element-plus/theme-chalk/dark/css-vars.css`**（main.ts:5）+ 全局图标（:14-16） |
| 依赖版本 | vue 3.4.31 / vite 5.3.1 / ep 2.7.6（:18,29,17） | 同 temple | 更旧：vue 3.4.27 / vite 5.2.11 / ep 2.7.2（:19,29,17） |
| vite base | **`VITE_PUBLIC_BASE \|\| (mode==='production' ? '/temple/' : '/')`**（vite.config.ts:7）——commit `39a2a49 "fix: build temple admin for subpath deployment"` 引入（git show 确认仅改此 3 行）；dist/index.html 已输出 `/temple/` 前缀（favicon/JS/CSS 均带） | `VITE_PUBLIC_BASE \|\| '/'`（:10），未配 subpath | `VITE_PUBLIC_BASE \|\| '/'`（:7），**未配置 subpath 部署** |
| vite 端口 | **5174**（:15） | **5175**（:32） | **5210**（:15） |
| manualChunks | vue/element/echarts 分包（:29-33） | 同左（:47-49） | 无分包 |
| tsconfig | `types:["node","element-plus/global"]`，include 仅 src | 同 temple | `types:["node"]`（无 element-plus/global），**include 含 vite.config.ts** → `vue-tsc -b` 产物 `vite.config.js/.d.ts`、`tsconfig.node.tsbuildinfo`、`tsconfig.tsbuildinfo` **已提交进 git**（git ls-files 确认；.gitignore 的 `dist/` 规则未覆盖） |
| index.html | 无字体外链 | 无 | `class="dark"`（:2）+ Google Fonts 外链（:8-10） |

**端口事实澄清**：任务描述"temple=5173/shop=5174/platform=5175"，但三端 `vite.config.ts` 实际端口是 **5174/5175/5210**；而 README.md:7-9、scripts/dev/clients-up.sh:108-110（启动时 `npm run dev -- --port 5173/5174/5175`，:94 覆盖）、e2e/playwright.config.ts:33-49（同样 5173/5174/5175）使用另一套口径。dev 脚本用 `--port` 覆盖了配置端口（实际生效 5173/5174/5175），但**直接 `npm run dev` 时端口与文档不一致**（platform 尤其偏到 5210）。

## 7. 代码质量

- **any 精确计数**（grep `as any|: any|any[]|<any>`）：temple **4 处**（client.ts:58,73；ImageUploader.vue:22；ReportView.vue:95）+ DataTable.vue:1 `Record<string,any>` 泛型约束；shop **18 处**（client.ts:58,73；ImageUploader.vue:86；视图 12 处 `row:any`：LogisticsView:62,104,163,203 + ServiceListView:44 + ProductListView:74,84 + CategoryManageView:42,54,88 + MaterialListView:68,78 + LogisticsView:262 `(name:any)` + ReportView:163 `(params:any)`）+ vite-env.d.ts:5；platform **10 处**（DataTable.vue:40 `data:any[]`,90；StatCard.vue:21 `icon?:any`；AuditAction.vue:27 `Promise<any>`；StatusTag.vue:62；ImageUploader.vue:15,28；LoginView.vue:63；client.ts:58,72）+ env.d.ts:5。三端合计约 35 处。
- **重复代码**：三端整份复制（§1）；shop 每页手写 `el-table+el-pagination` 骨架（10+ 页，`df-card`+`chart-header/section-title` 卡片头在 7 文件出现 10+ 处，见 shop 存档 md:273），DataTable.vue 死代码；platform ContentCommentView↔ContentDesignView 几乎逐行重复、FinanceTempleView↔FinanceMasterView 结算表格重复；shop OrderDetailView:22-61↔DiyOrderDetailView:22-102 发货弹窗整段重复。
- **硬编码**：URL（`/files/upload` 三处、`/api/v1/auth/refresh`）；ID（temple `T001` auth.ts:13；platform `roleId:2` SettingsAccountView:114；审核人 `'0'` 三处 + temple replierId `'0'`）；文案/颜色（temple 组件内大量 hex：#C45A3C/#2A1E1A/#8A7A6A；platform SettingsBackupView "私有对象存储/手动全量"）；字典（§4 清单）。
- **错误处理**：三端普遍 `try/finally` 无 catch 依赖拦截器 toast（shop ProductEditView:55-75、OrderDetailView:32-39、DiyOrderDetailView:32-39、ReturnDetailView:23-35,68-82；platform FinanceOverviewView 等）；`ElMessageBox.confirm` 取消 reject 未捕获（platform UserListView:96-98、temple TempleGalleryView:55-64）；`catch{}` 静默吞错（shop LoginView:36、ProductListView:79、MaterialListView:73、LogisticsView:110/209、ReportView:34）。
- **其它**：`formatPercent` 语义分裂（§1）；tab/空格混排（temple types/index.ts:74,88-95,129-135、ServiceEditView:25,67-70,83-84,97-98；platform MasterListView:59-64、SettingsAccountView:72-82；SettingsTaxonomyView script 在 template 前）；shop auth.ts:12-14 `JSON.parse` 无防护（localStorage 脏数据即崩）；shop `remember` 复选框无效；temple SettingsView.vue:12 `templeFormRef` 死引用、format.ts:19 `formatPercent` 死函数；platform SettingsRoleView 角色列表无分页。

## 8. 问题清单（P0/P1/P2）

**P0（上线前必须处理）**
1. 演示账号硬编码+明文展示：temple LoginView.vue:14,89；shop LoginView.vue:16-17,102；platform LoginView.vue:28,46
2. shop 仪表盘假数据误导运营：DashboardView.vue:37-38（随机数趋势图）、:103-110（5 条抽样当今日全量）、:106（UTC 时区错位）
3. 审核/回复人 id 缺省 `'0'` 落库（脏数据）：platform ContentCommentView.vue:76、ContentDesignView.vue:86、ContentReportView.vue:150；temple ReviewListView.vue:66

**P1（安全/数据正确性/架构）**
4. 三端**无 RBAC**：platform 有角色管理 UI/API（api/auth.ts:46-63、SettingsRoleView）但零校验；三端守卫仅查 token（temple router:122、shop router:161、platform router:194）；身份仅靠客户端 localStorage key + 请求头可伪造
5. 列表接口顶替详情接口（分页截断）：temple MasterEditView.vue:51-57、ServiceEditView.vue:57-63；shop MaterialEditView.vue:58-59、ServiceEditView.vue:39-40、ReturnDetailView.vue:26-28（后端应补 detail 接口）
6. temple ServiceListView.vue:68 `:total="0"` 关闭分页+前端过滤；BlessingTaskDetailView.vue:47,83 masterCode/id 语义错配（types/index.ts:102-116 Master 无 masterCode 字段）
7. shop 发货状态机矛盾：DiyOrderDetailView.vue:131（`approved` 不在 DiyOrderListView.vue:21-29 枚举；`paid` 未审核可发货）
8. shop DataTable.vue 死组件（零引用）暴露"复制后各自演化"的组件分裂；三端同名组件 API 互不兼容（§1 对比表）
9. platform 构建产物污染仓库：`vite.config.js/.d.ts`、`tsconfig*.tsbuildinfo` 已提交（git ls-files 确认；vue-tsc -b 副作用；.gitignore 未覆盖）
10. platform SettingsRoleView.vue:30-38 权限点只读无授权 UI；FinanceMasterView.vue:52-78 提现 tab 只读、:124-129 无 loading 保护
11. shop ReportView.vue:34-45 接口失败渲染全零假数据（无数据 vs 失败不可区分）

**P2（一致性/维护性）**
12. 三端 client.ts/auth.ts/format.ts/组件/tokens.css 复制粘贴零共享；无 workspace/共享包（唯一跨包引用 shop tailwind.config.ts:4 相对路径，搬出 monorepo 即断）
13. tokens.css 三份逐字节拷贝且主题语义错位：tokens 为暗色（--color-bg-primary:#1C1210），temple/shop 实际浅色主题（各自 index.css 重定义），仅 platform 真正使用
14. 端口三套口径：vite.config 5174/5175/5210 vs 文档/脚本/e2e 5173/5174/5175
15. 硬编码字典/魔法数字/写死文案大面积存在（§4/§7 清单）：platform MasterListView:18-19,117,155-157、SettingsAccountView:114、SettingsBackupView:14,24、MarketingActivityView:83-87、MarketingCouponView:99-104、SettingsDictView:70-75、SettingsTaxonomyView:16-17；shop MaterialListView:24-32、OrderDetailView:30、DiyOrderDetailView:30、LogisticsView:157；`any` 三端共约 35 处
16. ElMessageBox 取消 rejection 未捕获（platform UserListView:96-98、temple TempleGalleryView:55-64）、catch 静默吞错（多处）
17. 路由与侧栏菜单双份硬编码维护（三端 DefaultLayout 菜单 vs router/index.ts）
18. 文案/契约不一致：temple README.md:9 声称"按需自动导入"实际全量引入；shop router:1 注释"17 条路由"实为 16、OrderListView:70/DiyOrderListView:71 副标题与功能不符；DiyOrderListView:108 状态列英文裸值
19. 健壮性细节：shop auth.ts:12-14 JSON.parse 无防护；temple SettingsView.vue:39 `localStorage.clear()` 清全站；缩进混排（§7）；platform TempleDetailView:26 rating 无兜底、UserDetailView:36,42 未判空、SettingsAccountView:79 中文/英文字面量混用比较

## 9. 总体结论

三端是同一脚手架复制三次后各自演化的独立应用（证据：`client.ts` 仅替换前缀、`tokens.css` 逐字节相同、`DataTable.vue` 同名不同义），**跨端共享率约等于零**。功能完成度高（57 页全部有真实 API 交互、无空模板占位页）；主要风险集中在安全残留（演示凭据、`'0'` 落库）、Dashboard 假数据、列表顶替详情导致的分页截断、全端无 RBAC（尤其 platform 有角色体系却不校验）、以及复制造成的组件语义分裂与硬编码漂移。建议优先级：抽共享包统一登录/权限基建 → 后端补 detail 接口 → 清理假数据与 `'0'` 落库 → 合并 DataTable 语义 → 治理构建产物与端口口径。

---
**附**：shop 端 17 页逐页审计完整报告（每页职责/完成度/功能点/行号证据 + DataTable 误用汇总）已存档于同目录 `shop-admin-views-audit.md`；temple/platform 逐页结论已并入上文 §5。
