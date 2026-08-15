# web-shop-admin 视图审计报告（17 个页面）

- 审计时间：本会话
- 审计范围：`apps/web-shop-admin/src/views/` 下全部 17 个 `.vue`（共 3,585 行）+ `src/components/DataTable.vue`（49 行）
- 方法：逐文件通读；全量 grep 确认 `DataTable`、`el-table`、`any`、`console`/`TODO` 引用；核对 `src/main.ts` 与 `src/types/components.d.ts`。未修改任何文件。

## 全局结论

- 没有任何视图引用 `<DataTable`（唯一命中是自动生成的类型声明 `types/components.d.ts:10`），因此**不存在**把 DataTable 当表格传 `data/total/page` 的误用；但 DataTable.vue 是全 app **零引用的死代码**，而各视图在重复手写它本应封装的"卡片头 + 内容"结构（见文末汇总）。
- 无 `console.log`、无 TODO/FIXME、无空模板；全部 17 页的 import 均被实际使用（未发现未使用 import）。
- 所有表格均直接使用 `el-table`，不受 DataTable 影响。
- 完成度统计：12/17 完整，5/17 部分完成（DashboardView、MaterialListView、MaterialEditView、ServiceEditView、ReturnDetailView），无纯占位页面。

---

## 1. DashboardView.vue（231 行）

- **职责**：商城工作台，展示今日订单/销售额/待发货/商品总数四个指标卡、近 7 日销售趋势图与最新 5 条订单。
- **完成度**：**部分**。趋势图数据是 `Math.random()` 造假的假数组；统计指标基于抽样（仅取 5 条订单）计算，数值失真。
- **主要功能点**：
  1. 四个 StatCard 指标（今日订单/销售额/待发货/商品总数，14-19 行）
  2. ECharts 双轴"近 7 日销售趋势"（26-95 行）
  3. 最新订单 el-table + 跳转详情（170-191 行）
  4. resize/dispose 生命周期管理（123-133 行）
- **质量问题**：
  - `DashboardView.vue:37-38` — 趋势图数据 `Math.random() * 3000` / `Math.random() * 20` 纯随机数，**伪造**"近 7 日销售趋势"，无任何真实接口。
  - `DashboardView.vue:103` — `orderApi.list({ page: 1, size: 5 })` 只取 5 条订单，随后 106-110 行却据此统计"今日订单数/今日销售额/待发货"，**抽样当全量**，数值必然不准。
  - `DashboardView.vue:106` — `new Date().toISOString()` 按 UTC 取日期，与本地时区的 `createTime` 比较会错位（北京时间 0-8 点的订单算不进"今日"）。
  - `DashboardView.vue:111-113, 118-120` — catch 静默吞错，仅注释"忽略"。

## 2. LoginView.vue（258 行）

- **职责**：商城运营登录页，调用 auth store 登录并按 redirect 跳转。
- **完成度**：**完整**（流程可用），但存在明显安全问题。
- **主要功能点**：
  1. 账号/密码表单 + 校验规则（21-24 行）
  2. 调 `auth.login` 登录并按 `route.query.redirect` 跳转（26-42 行）
  3. 记住登录复选框（98 行）
- **质量问题**：
  - `LoginView.vue:16-17` — **硬编码默认账号密码 `admin / 123456`** 写死在表单初始值里。
  - `LoginView.vue:102` — 登录页面向所有访问者明文展示"默认账号：admin / 123456"，生产环境安全隐患。
  - `LoginView.vue:18, 98` — `form.remember` 仅绑定复选框、从未被读取使用，"记住登录"是**无效功能**。
  - `LoginView.vue:99` — `<a href="#">忘记密码？</a>` 死链接。
  - `LoginView.vue:36-37` — catch 仅注释"错误已由拦截器提示"，登录失败无任何用户反馈兜底（依赖拦截器是否真的提示）。

## 3. ProductListView.vue（276 行）

- **职责**：商品列表页，支持关键词/分类/状态筛选、分页、上下架与删除。
- **完成度**：**完整**。
- **主要功能点**：
  1. 三条件筛选 + 重置（50-61 行）
  2. 商品表格（图片/分类/售价/库存/状态）+ 分页（157-223 行）
  3. 上下架状态切换（74-82 行）、删除带二次确认（84-97 行）
- **质量问题**：
  - `ProductListView.vue:74, 84` — `row: any` 滥用（行对象应使用 `Product` 类型）。
  - `ProductListView.vue:74-82` — 状态切换 catch 仅注释"忽略"，失败无提示。
  - `ProductListView.vue:29` — 分类下拉固定 `size: 100`，分类超过 100 个会丢失选项（同 ProductEditView:48、CategoryManageView:34）。

## 4. ProductEditView.vue（198 行）

- **职责**：商品新建/编辑表单页（基本信息、价格库存、标签、诉求标签、运费模板、描述）。
- **完成度**：**完整**。
- **主要功能点**：
  1. 编辑/新建双模式（`isEdit` 判断，22-23 行）
  2. 编辑时回填详情（55-75 行）、保存时 create/update 分流（77-95 行）
  3. ImageUploader 主图上传（136 行）、诉求标签多选（157-161 行）
- **质量问题**：
  - `ProductEditView.vue:55-75` — `loadDetail` 只有 `try/finally` **没有 catch**，接口失败会变成未处理的 Promise rejection，页面无错误提示。
  - `ProductEditView.vue:103` — `listIntentions().then(...)` 无 catch。
  - `ProductEditView.vue:163-166` — 运费模板用 `el-input-number` 让运营**手填裸 ID**（提示"模板 ID（0 表示默认包邮）"），应改为模板下拉选择器，硬编码体验差。
  - `ProductEditView.vue:48` — 分类 `size: 100` 上限（同 ProductListView）。

## 5. CategoryManageView.vue（186 行）

- **职责**：商品分类管理，树形列表 + 新建/编辑弹窗，支持新增子分类与删除。
- **完成度**：**完整**。
- **主要功能点**：
  1. 树形表格（`row-key` + `tree-props`，120-140 行）
  2. 新建/编辑共用弹窗（145-170 行），新增子分类自动带 parentId/level（42-52 行）
  3. 删除二次确认（88-101 行）
- **质量问题**：
  - `CategoryManageView.vue:42, 54, 88` — `any` 滥用（parent/row 应为 `ProductCategory`）。
  - `CategoryManageView.vue:155-158` — 父级用**裸 ID 数字输入**而非分类选择器，运营需自行知道父分类 ID。
  - `CategoryManageView.vue:34` — 分类 `size: 100`，超过 100 个分类时树不完整。
  - `CategoryManageView.vue:88-101` — catch 吞错（"取消"与真实删除失败无法区分，删除失败无提示）。

## 6. MaterialListView.vue（254 行）

- **职责**：DIY 材料列表页，支持分类/关键词筛选、分页、上下架。
- **完成度**：**部分**。删除按钮是**假实现**——弹确认框后只提示"不支持删除"，不执行任何操作。
- **主要功能点**：
  1. 材料表格（图片/分类/五行/单价/库存/状态，137-188 行）
  2. 上下架切换（68-76 行）
  3. 分页（190-201 行）
- **质量问题**：
  - `MaterialListView.vue:78-90` — `handleDelete` 先弹"确认删除材料…"确认框，随后只 `ElMessage.info('材料暂不支持物理删除，请使用下架')`（85-86 行注释自认"无独立删除接口"），而 185 行仍渲染红色"删除"按钮——**确认框+失败提示的组合严重误导用户**，应直接隐藏删除按钮或改为"下架"。
  - `MaterialListView.vue:24-32` — `categoryOptions` 硬编码数组与 `MaterialEditView.vue:42-50` **整份重复**（7 项完全相同），且与 `utils/format.ts` 的 `materialCategoryLabel` 职责重叠。
  - `MaterialListView.vue:68, 78` — `row: any` 滥用。
  - `MaterialListView.vue:68-76` — 上下架失败 catch 仅"忽略"，无提示。

## 7. MaterialEditView.vue（184 行）

- **职责**：DIY 材料新建/编辑表单页（名称/规格/分类/五行/单价/单位/库存/图片）。
- **完成度**：**部分**。编辑回填用"拉全列表 + 前端 find"兜底（无 detail 接口），第 100 条以后的材料无法编辑且无提示。
- **主要功能点**：
  1. 新建/编辑双模式（18-19 行）
  2. 表单校验 + 保存分流（77-95 行）
  3. 五行属性选择（52, 137-146 行）
- **质量问题**：
  - `MaterialEditView.vue:58-59` — `materialApi.list({ keyword: '', page: 1, size: 100 })` 拉全列表再 `find` 代替 detail 接口：**超过 100 条的材料编辑时表单为空**，且无任何"未找到"提示。
  - `MaterialEditView.vue:54-75` — `try/finally` **无 catch**，接口失败静默 + 未处理 rejection。
  - `MaterialEditView.vue:42-50` — 与 MaterialListView.vue:24-32 重复的分类硬编码数组（见上）。

## 8. ServiceListView.vue（133 行）

- **职责**：祈福服务列表页，分页浏览 + 编辑/删除。
- **完成度**：**完整**。
- **主要功能点**：
  1. 服务表格（编码/名称/寺院/法师/价格/状态，76-105 行）
  2. 删除二次确认（44-57 行）
  3. 分页（107-118 行）
- **质量问题**：
  - `ServiceListView.vue:44` — `row: any`。
  - `ServiceListView.vue:81, 86` — `templeName || templeCode`、`masterName || masterCode` 的兜底显示说明列表接口字段不全，属于数据契约不稳定的征兆。
  - `ServiceListView.vue:44-57` — catch 吞错，删除失败无提示（与"取消"无法区分）。

## 9. ServiceEditView.vue（151 行）

- **职责**：祈福服务新建/编辑表单（名称/寺院编码/法师编码/价格/状态/描述）。
- **完成度**：**部分**。与 MaterialEditView 相同的"列表+find"兜底；寺院/法师用裸编码手填。
- **主要功能点**：
  1. 新建/编辑双模式（16-17 行）
  2. 状态 radio（114-119 行）
  3. 保存分流（56-74 行）
- **质量问题**：
  - `ServiceEditView.vue:39-40` — 同 MaterialEditView 的 `list(size:100)+find` 兜底，**第 100 条以后的服务无法编辑且无提示**。
  - `ServiceEditView.vue:35-54` — `try/finally` 无 catch。
  - `ServiceEditView.vue:101-107` — 寺院/法师是**裸编码文本输入**（placeholder 硬编码示例 `lingyin-temple`、`master-001`），运营必须记住编码，应改为寺院/法师选择器。
  - `ServiceEditView.vue:42-50` — 回填时 `status` 断言 `as 'on_shelf' | 'off_shelf'`，与 `BlessingServiceSaveParams` 类型契约耦合。

## 10. OrderListView.vue（149 行）

- **职责**：商城订单列表页，按状态筛选 + 分页 + 跳详情。
- **完成度**：**完整**（但副标题文案与功能不符）。
- **主要功能点**：
  1. 状态筛选（含 6 种订单状态枚举，21-28 行）
  2. 订单表格（订单号/金额/状态/备注/时间，92-114 行）
  3. 分页（116-127 行）
- **质量问题**：
  - `OrderListView.vue:70` — 副标题"支持发货操作"，但本页**没有任何发货按钮**（仅"详情"），文案与实际功能不符（发货实际在 OrderDetailView）。
  - `OrderListView.vue:108` — `备注` 列 `prop="note"`，若后端字段为 null 显示空白（小问题）。

## 11. OrderDetailView.vue（184 行）

- **职责**：订单详情页，展示基本信息/商品明细/物流，并支持发货操作。
- **完成度**：**完整**。
- **主要功能点**：
  1. 基本信息 el-descriptions（88-104 行）
  2. 商品明细表格（110-120 行）
  3. 发货弹窗（快递公司 + 运单号，138-163 行）
- **质量问题**：
  - `OrderDetailView.vue:30` — `expressOptions` 快递公司**硬编码字符串数组**，与 `DiyOrderDetailView.vue:30` **逐字重复**，且与 LogisticsView 的快递公司数据源（接口管理）脱节——物流公司应该来自 `logisticsApi.expressList`。
  - `OrderDetailView.vue:22-61` — 发货弹窗整套逻辑（shipForm/shipRules/openShipDialog/handleShip）与 DiyOrderDetailView 22-102 行**大面积重复代码**，应抽取共用组件。
  - `OrderDetailView.vue:32-39` — `loadDetail` 无 catch，接口失败未处理。
  - `OrderDetailView.vue:98` — 收货地址只显示 `addressId` 裸 ID，不展示具体地址，运营无法直接使用。

## 12. DiyOrderListView.vue（150 行）

- **职责**：DIY 手串订单列表页，按状态筛选 + 分页 + 跳详情。
- **完成度**：**完整**。
- **主要功能点**：
  1. 状态筛选（含 7 种 DIY 订单状态，21-29 行）
  2. 订单表格（材料费/加持费/合计，93-115 行）
  3. 分页（117-128 行）
- **质量问题**：
  - `DiyOrderListView.vue:108` — 状态列 `prop="status"` 直接渲染**原始枚举值**（`paid`/`in_review`…），没有像 OrderListView:100-106 那样做中文 label/颜色映射，用户看到英文裸值。
  - `DiyOrderListView.vue:71` — 副标题"审核与发货"，列表页同样无审核/发货操作（在详情页）。

## 13. DiyOrderDetailView.vue（277 行）

- **职责**：DIY 订单详情页，展示基本信息/材料明细/加持任务（含证书图片预览），支持审核通过/拒绝、标记制作完成、发货。
- **完成度**：**完整**（功能最全的页面之一），但状态处理不一致。
- **主要功能点**：
  1. 审核通过/拒绝（拒绝需填原因，41-65 行）
  2. 制作完成（67-80 行）、发货弹窗（88-102 行）
  3. 加持任务 + 证书图片预览（182-208 行）
- **质量问题**：
  - `DiyOrderDetailView.vue:131` — 发货按钮条件 `status === 'paid' || status === 'approved'`，其中 **`approved` 不在列表页状态枚举里**（DiyOrderListView.vue:21-29 无 approved）；同时 **`paid` 状态下（审核前）就允许发货**，与"审核-制作-发货"流程矛盾——要么列表枚举缺了 `approved`，要么发货条件过宽，两处契约不一致。
  - `DiyOrderDetailView.vue:151, 188` — 订单状态/任务状态直接渲染裸枚举值，与 OrderDetailView 用 `orderStatusLabel` 的风格不一致。
  - `DiyOrderDetailView.vue:30` — `expressOptions` 硬编码重复（同 OrderDetailView）。
  - `DiyOrderDetailView.vue:22-102` — 发货弹窗逻辑与 OrderDetailView 重复（见上）。
  - `DiyOrderDetailView.vue:32-39` — loadDetail 无 catch。

## 14. LogisticsView.vue（485 行，全目录最长）

- **职责**：物流管理页，Tab 切换承载快递公司 CRUD、运费模板 CRUD、物流追踪查询与批量同步三个子模块。
- **完成度**：**完整**（功能覆盖最全），但单文件过大、运费规则 JSON 无校验。
- **主要功能点**：
  1. 快递公司列表/新建/编辑/启禁用（37-113 行 + 394-422 行弹窗）
  2. 运费模板列表/新建/编辑/启禁用（139-212 行 + 425-458 行弹窗）
  3. 物流追踪（运单号查询 + 时间线，219-232, 353-389 行）与批量同步（234-246 行）
- **质量问题**：
  - `LogisticsView.vue:439-446` — 运费规则 `config` 是**裸 JSON textarea**，提交前无 JSON.parse 校验，运营填错格式直接提交报错。
  - `LogisticsView.vue:157` — 新建模板默认值硬编码 `'{"first":1,"firstFee":10,...}'`。
  - `LogisticsView.vue:262` — `@tab-change="(name: any) => ..."` 内联箭头 + `any`。
  - `LogisticsView.vue:62, 104, 163, 203` — `row: any` 滥用。
  - `LogisticsView.vue:104-113, 203-212` — 启禁用失败 catch 仅"忽略"。
  - 单文件 485 行承载三个独立模块（快递/运费/追踪），状态与模板大量平铺，建议拆分；`freightQuery.type/status` 定义了但筛选 UI 未用 `status`（312-315 行只有计费方式）——部分字段死代码。
  - `LogisticsView.vue:411, 447` — 弹窗状态字段仅在编辑时显示，新建时 `expressForm.status` 虽有默认值但 payload 剥离了 status（82-93 行显式挑选字段），两处不一致。

## 15. ReturnListView.vue（159 行）

- **职责**：退货/换货列表页，按状态筛选 + 分页 + 跳详情。
- **完成度**：**完整**。
- **主要功能点**：
  1. 状态筛选（7 种退货状态，21-29 行）
  2. 退货表格（类型标签/退款金额/状态/原因，93-124 行）
  3. 分页（126-137 行）
- **质量问题**：
  - 无明显严重问题；`ReturnListView.vue:98-100` 类型标签 `row.type === 'exchange' ? '换货' : '退货'` 三元判断可读性一般，可抽 `returnTypeLabel`（与 utils 中 `returnStatusLabel` 风格不统一）。

## 16. ReturnDetailView.vue（191 行）

- **职责**：退货详情页，展示退货信息与原因，支持审核通过/拒绝与退款操作。
- **完成度**：**部分**。详情用"拉 200 条列表 + 前端 find"兜底（代码注释自认后端无详情接口），第 200 条之后的退货单**详情页显示"未找到"**，无法操作。
- **主要功能点**：
  1. 审核通过/拒绝（拒绝需原因，37-61 行）
  2. 退款弹窗（可改退款金额，63-82, 146-157 行）
  3. 退货信息/原因展示（115-141 行）
- **质量问题**：
  - `ReturnDetailView.vue:26-28` — 注释明说"后端未提供单独的退货详情接口，从列表中查找"：`returnList({ page: 1, size: 200 })` + `find`，**>200 条数据时详情缺失**，属架构级兜底缺陷（后端应补 detail 接口）。
  - `ReturnDetailView.vue:23-35` — `try/finally` 无 catch。
  - `ReturnDetailView.vue:68-82` — `handleRefund` 无 catch，退款失败静默（只有 finally 复位 saving），用户无任何失败反馈。
  - `ReturnDetailView.vue:106` — 退款按钮条件含 `refunding`（退款中还能再退款），状态机判断可疑。

## 17. ReportView.vue（308 行）

- **职责**：数据报表页，按日期范围查询销售趋势、Top 商品排行（图表 + 明细表）。
- **完成度**：**完整**（数据来自真实接口，与 Dashboard 的假数据形成对比）。
- **主要功能点**：
  1. 日期范围筛选（默认近 30 天，20-25, 197-214 行）
  2. 四个指标卡（217-222 行）
  3. ECharts 趋势图 + Top 商品横向条形图（56-168 行）+ 明细表（243-258 行）
- **质量问题**：
  - `ReportView.vue:34-45` — 接口失败时 catch 静默渲染**全零假数据**，用户无法区分"无数据"与"请求失败"。
  - `ReportView.vue:163` — `formatter: (params: any)` any 滥用。
  - `ReportView.vue:130` — `top.slice(0,10).reverse()` 依赖后端已排序，若未排序 Top 排行会错（前端未兜底排序）。

---

## 占位 / 未完成页面清单

无空模板、无 TODO、无 console.log 页面。**部分完成（5 个）**：

| 页面 | 未完成点 | 证据 |
|---|---|---|
| DashboardView | 趋势图为随机数假数据；"今日订单/销售额/待发货"基于 5 条抽样订单计算，数值失真 | :37-38, :103-110 |
| MaterialListView | 删除按钮是假实现（确认后仅提示不支持删除），无真实删除/下架替代入口 | :78-90, :185 |
| MaterialEditView | 无 detail 接口，靠 `list(size:100)+find` 回填，>100 条无法编辑且无提示 | :58-59 |
| ServiceEditView | 同上 list+find 兜底（>100 条失效）；寺院/法师靠手填裸编码 | :39-40, :101-107 |
| ReturnDetailView | 无详情接口，靠 `returnList(size:200)+find`，>200 条显示"未找到" | :26-28 |

（注：OrderListView/DiyOrderListView 副标题声称"发货/审核"但列表页无对应操作——文案与功能不符，见上。）

## DataTable 误用汇总

**结论：无误用——因为完全无人使用。**

1. `components/DataTable.vue` 实际接口：仅接收 `title?: string` 与 `padding?: boolean` 两个 prop（3-9 行），模板是"标题头 + 默认插槽"的卡片容器（12-24 行），**不接收 `data/total/page` 等任何表格属性**。
2. 全 src 目录 grep `DataTable` 仅 1 处命中：自动生成的类型声明 `types/components.d.ts:10`（unplugin-vue-components 产物）。**17 个视图（以及 layouts/App.vue）均无 `<DataTable` 引用**，因此不存在"当表格用、传 data/total/page 而组件不接收"的 bug。
3. 附带发现：
   - **死代码**：DataTable.vue 被全局声明却零引用，是未使用的组件。
   - **重复代码**：视图们在重复手写 DataTable 本应封装的"卡片标题头"结构——`df-card` + `.chart-header`/`.section-title` 样式块在 7 个文件出现 10+ 处：DashboardView.vue:152-159, 162-169；ReportView.vue:225-231, 234-240, 243-246；OrderDetailView.vue:86-88, 108-109, 124-125；DiyOrderDetailView.vue:144-146, 163-164, 180-181；以及各列表页的 `df-card` 包装（ProductListView:116,156；MaterialListView:108,136；ServiceListView:75；OrderListView:72,91；DiyOrderListView:73,92；ReturnListView:73,92；CategoryManageView:119；LogisticsView:261）。表格全部改用 `el-table`，DataTable 从未被使用，属于设计遗留。

---

## 总结

页面整体完成度较高（12/17 完整），无占位空页；主要风险集中在：

1. **Dashboard 假数据**：随机数趋势图（:37-38）+ 抽样统计（:103-110）。
2. **缺 detail 接口的列表+find 兜底**：MaterialEditView:58-59、ServiceEditView:39-40、ReturnDetailView:26-28，均有数据量上限导致编辑/详情失效。
3. **MaterialListView 假删除按钮**（:78-90, :185）误导用户。
4. **跨文件重复硬编码**：发货弹窗（OrderDetailView:22-61 vs DiyOrderDetailView:22-102）、快递公司选项（两处 :30）、分类选项（MaterialListView:24-32 vs MaterialEditView:42-50）。
5. **错误处理缺失**：`try/finally` 无 catch（ProductEditView:55-75、OrderDetailView:32-39、DiyOrderDetailView:32-39、ReturnDetailView:23-35, 68-82）与 catch 静默吞错（LoginView:36、ProductListView:79、MaterialListView:73、LogisticsView:110/209、ReportView:34）。
6. **状态机/枚举不一致**：DiyOrderDetailView:131 发货条件含 `approved`（列表枚举 DiyOrderListView:21-29 无此值），且 `paid` 审核前即可发货。
7. **`any` 滥用共 14 处**：ProductListView:74,84；CategoryManageView:42,54,88；MaterialListView:68,78；ServiceListView:44；LogisticsView:62,104,163,203,262；ReportView:163。
8. **硬编码凭证**：LoginView:16-17, 102（admin/123456 并明文展示）。
