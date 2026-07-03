//
//  ProfileSubPages.swift
//  DongFangApp
//
//  个人中心二级页面集合：14 个二级页面统一存放于本文件，
//  供 ProfileView 的各菜单项 NavigationLink 跳转使用。
//  所有页面均使用 Mock 数据占位，深色主题 + design token。
//  后续接入真实数据时替换各页面的 mock 数据与状态管理即可。
//

import SwiftUI

// MARK: - 1. 订单列表
/// 订单列表：顶部状态筛选 Tab + 订单卡片列表。
/// `initialStatus` 用于从个人中心不同入口直达对应分类。
struct OrderListView: View {
    var initialStatus: String? = nil

    @State private var selectedTab: String

    init(initialStatus: String? = nil) {
        self.initialStatus = initialStatus
        _selectedTab = State(initialValue: initialStatus ?? "all")
    }

    private let tabs: [(key: String, title: String)] = [
        ("all", "全部"), ("pending", "服务订单"), ("shipping", "商城订单"),
        ("diy", "DIY手串"), ("booking", "预约记录")
    ]

    private let mockOrders: [(id: Int, type: String, title: String, desc: String, amount: String, status: String)] = [
        (1001, "pending",  "祈福法事 · 普佛", "灵隐寺 · 妙音法师", "¥388.00", "待确认"),
        (1002, "shipping", "檀木念珠（18mm）", "东方文创商城", "¥128.00", "待收货"),
        (1003, "diy",      "DIY 手串定制", "8mm 砗磲 + 蜜蜡", "¥256.00", "制作中"),
        (1004, "booking",  "法师预约 · 咨询", "智海法师 · 30分钟", "¥99.00", "待进行"),
        (1005, "pending",  "点灯供养 · 七日", "大昭寺", "¥58.00", "已完成"),
        (1006, "shipping", "沉香线香礼盒", "东方文创商城", "¥168.00", "已发货")
    ]

    private var filteredOrders: [(id: Int, type: String, title: String, desc: String, amount: String, status: String)] {
        if selectedTab == "all" { return mockOrders }
        return mockOrders.filter { $0.type == selectedTab }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                tabBar
                if filteredOrders.isEmpty {
                    DFEmptyState(icon: "doc.text", title: "暂无订单", subtitle: "去首页看看吧")
                        .frame(height: 320)
                } else {
                    ForEach(filteredOrders, id: \.id) { order in
                        orderCard(order)
                    }
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("我的订单")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(tabs, id: \.key) { tab in
                    Text(tab.title)
                        .font(.system(size: 13, weight: selectedTab == tab.key ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab.key ? Color.accentDefault : Color.textTertiary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(selectedTab == tab.key ? Color.bgTertiary : Color.bgSecondary)
                        .overlay(
                            Capsule().stroke(Color.borderDefault, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .onTapGesture { selectedTab = tab.key }
                }
            }
        }
    }

    private func orderCard(_ order: (id: Int, type: String, title: String, desc: String, amount: String, status: String)) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(Color.bgTertiary).frame(width: 44, height: 44)
                Image(systemName: "doc.text")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textTertiary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(order.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(order.desc)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(order.amount)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
                    .monospacedDigit()
                Text(order.status)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.stateWarning)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }
}

// MARK: - 2. 收藏列表
struct FavoritesView: View {
    private let mockItems: [(icon: String, name: String, subtitle: String, tag: String)] = [
        ("person.crop.circle", "妙音法师", "灵隐寺 · 监院", "法师"),
        ("person.crop.circle", "智海法师", "普陀山 · 知客", "法师"),
        ("building.2", "灵隐寺", "浙江杭州", "寺院"),
        ("building.2", "法门寺", "陕西宝鸡", "寺院")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(Array(mockItems.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle().fill(Color.bgTertiary).frame(width: 44, height: 44)
                            Image(systemName: item.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.accentDefault)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Text(item.tag)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.brandDefault)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.brandDefault.opacity(0.15))
                            .clipShape(Capsule())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 3. 收货地址列表
struct AddressListView: View {
    @State private var addresses: [UserAddress] = UserAddress.mockAddresses

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(addresses) { addr in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            Text(addr.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text(addr.maskedPhone)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textTertiary)
                            if addr.isDefault {
                                Text("默认")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.brandDefault)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.accentDefault)
                        }
                        Text(addr.fullAddress)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("收货地址")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
            }
        }
    }
}

// MARK: - 4. 我的评价
struct ReviewListView: View {
    private let mockReviews: [(target: String, content: String, date: String, rating: Int)] = [
        ("祈福法事 · 普佛", "法师用心，过程庄严，感恩结缘。", "2026-06-28", 5),
        ("檀木念珠（18mm）", "质地温润，做工精细，很满意。", "2026-06-20", 5),
        ("智海法师 · 咨询", "解答详尽，受益匪浅。", "2026-06-12", 4)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(Array(mockReviews.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text(item.target)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { i in
                                    Image(systemName: i < item.rating ? "star.fill" : "star")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.stateWarning)
                                }
                            }
                        }
                        Text(item.content)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.date)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("我的评价")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 5. 功德金（钱包）
struct WalletView: View {
    private let mockRecords: [(title: String, date: String, amount: String, isIncome: Bool)] = [
        ("充值", "2026-06-28", "+¥200.00", true),
        ("祈福法事支出", "2026-06-25", "-¥188.00", false),
        ("点灯供养", "2026-06-20", "-¥58.00", false),
        ("充值", "2026-06-10", "+¥100.00", true)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: AppSpacing.xs) {
                    Text("功德金余额")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                    Text("¥128.00")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.accentDefault)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.xl)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(Color.borderDefault, lineWidth: 1))

                Text("收支明细")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(mockRecords.enumerated()), id: \.offset) { _, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.date)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Text(item.amount)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.isIncome ? Color.stateSuccess : Color.brandDefault)
                            .monospacedDigit()
                    }
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("功德金")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 6. 优惠券
struct CouponView: View {
    private let mockCoupons: [(amount: String, threshold: String, title: String, scope: String, expire: String)] = [
        ("¥20", "满¥199可用", "新人专享券", "全品类通用", "2026-07-31 到期"),
        ("¥10", "满¥99可用", "文创满减券", "文创商城", "2026-07-15 到期"),
        ("¥50", "满¥500可用", "法事专享券", "祈福/法事服务", "2026-08-31 到期")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(Array(mockCoupons.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 0) {
                        VStack(spacing: 2) {
                            Text(item.amount)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color.brandDefault)
                                .monospacedDigit()
                            Text(item.threshold)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(width: 92)
                        .padding(.vertical, AppSpacing.md)

                        Rectangle().fill(Color.borderDivider).frame(width: 1)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.scope)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                            Text(item.expire)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.leading, AppSpacing.md)
                        Spacer()
                    }
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("优惠券")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 7. 积分明细
struct PointsView: View {
    private let mockRecords: [(title: String, date: String, points: String, isIncome: Bool)] = [
        ("签到奖励", "2026-06-28", "+10", true),
        ("完成订单", "2026-06-25", "+88", true),
        ("兑换优惠券", "2026-06-20", "-200", false),
        ("签到奖励", "2026-06-19", "+10", true)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: AppSpacing.xs) {
                    Text("我的积分")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                    Text("3,560")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.accentDefault)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.xl)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.xl).stroke(Color.borderDefault, lineWidth: 1))

                ForEach(Array(mockRecords.enumerated()), id: \.offset) { _, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.date)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Text(item.points)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.isIncome ? Color.stateSuccess : Color.brandDefault)
                            .monospacedDigit()
                    }
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("积分明细")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 8. 浏览记录
struct HistoryView: View {
    private let mockItems: [(icon: String, title: String, subtitle: String, time: String)] = [
        ("person.crop.circle", "妙音法师", "灵隐寺 · 监院", "10分钟前"),
        ("building.2", "灵隐寺", "浙江杭州", "1小时前"),
        ("bag", "檀木念珠（18mm）", "东方文创商城", "昨天"),
        ("doc.text", "祈福法事 · 普佛", "灵隐寺", "昨天"),
        ("building.2", "法门寺", "陕西宝鸡", "2天前")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(mockItems.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle().fill(Color.bgTertiary).frame(width: 40, height: 40)
                            Image(systemName: item.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textTertiary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Text(item.time)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("浏览记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 9. 通话记录
struct CallHistoryView: View {
    private let mockRecords: [(name: String, duration: String, time: String, incoming: Bool)] = [
        ("妙音法师", "12:30", "今天 10:20", false),
        ("智海法师", "08:15", "昨天 15:42", false),
        ("客户回拨", "00:00", "2天前", true)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(mockRecords.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle().fill(Color.bgTertiary).frame(width: 40, height: 40)
                            Image(systemName: item.incoming ? "phone.arrow.down.left" : "phone.arrow.up.right")
                                .font(.system(size: 16))
                                .foregroundStyle(item.incoming ? Color.stateSuccess : Color.accentDefault)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.time)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Text(item.duration)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .monospacedDigit()
                    }
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("通话记录")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 10. 帮助中心
struct HelpView: View {
    private let mockFAQ: [(q: String, a: String)] = [
        ("如何预约法师？", "在法师主页点击「预约咨询」，选择时间并提交即可。"),
        ("订单如何退款？", "在「我的订单」中找到对应订单，点击「申请退款」并填写原因。"),
        ("功德金如何使用？", "功德金可用于法事、供养等服务，下单时勾选功德金支付即可。"),
        ("如何修改收货地址？", "进入「收货地址」页面，点击对应地址进行编辑。"),
        ("DIY 手串定制流程？", "在首页进入「DIY 手串」，选择珠子材质与搭配后提交定制。")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                ForEach(Array(mockFAQ.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.accentDefault)
                            Text(item.q)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                        Text(item.a)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(Color.bgSecondary)
                    .cornerRadius(AppRadius.lg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                }
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("帮助与客服")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 11. 个人资料编辑
struct ProfileEditView: View {
    @State private var nickname: String = UserProfile.mock.nickname
    @State private var mobile: String = UserProfile.mock.maskedMobile
    @State private var gender: String = UserProfile.mock.gender
    @State private var birthday: String = UserProfile.mock.birthday ?? ""
    @State private var region: String = UserProfile.mock.region ?? ""
    @State private var bio: String = UserProfile.mock.bio ?? ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                avatarSection
                infoSection
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var avatarSection: some View {
        HStack {
            Spacer()
            ZStack {
                Circle().fill(Color.bgTertiary).frame(width: 72, height: 72)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentDefault)
                Circle().stroke(Color.accentDefault, lineWidth: 2).frame(width: 72, height: 72)
            }
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(Color.brandDefault).frame(width: 22, height: 22)
                    Image(systemName: "camera")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white)
                }
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.md)
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            editRow(label: "昵称", value: $nickname)
            divider
            editRow(label: "手机号", value: $mobile)
            divider
            PickerRow(label: "性别", value: genderDisplay)
            divider
            editRow(label: "生日", value: $birthday)
            divider
            editRow(label: "地区", value: $region)
            divider
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("个人简介")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                TextEditor(text: $bio)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .frame(height: 80)
                    .padding(AppSpacing.sm)
                    .background(Color.bgTertiary)
                    .cornerRadius(AppRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
            }
            .padding(AppSpacing.md)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    private var genderDisplay: String {
        switch gender { case "male": return "男"; case "female": return "女"; default: return "未知" }
    }

    private func editRow(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            TextField("", text: value)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(AppSpacing.md)
    }

    private func PickerRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(AppSpacing.md)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, AppSpacing.md)
    }
}

// MARK: - 12. 消息通知设置
struct NotificationSettingsView: View {
    @State private var orderNotify = true
    @State private var activityNotify = true
    @State private var systemNotify = false
    @State private var chatNotify = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                toggleGroup
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("消息通知")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var toggleGroup: some View {
        VStack(spacing: 0) {
            toggleRow(icon: "doc.text", title: "订单通知", subtitle: "订单状态变更提醒", isOn: $orderNotify)
            divider
            toggleRow(icon: "gift", title: "活动通知", subtitle: "优惠活动与福利提醒", isOn: $activityNotify)
            divider
            toggleRow(icon: "bell", title: "系统通知", subtitle: "系统消息与公告", isOn: $systemNotify)
            divider
            toggleRow(icon: "bubble.left", title: "消息通知", subtitle: "法师/客服消息提醒", isOn: $chatNotify)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.brandDefault)
        }
        .padding(AppSpacing.md)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 52)
    }
}

// MARK: - 13. 账号安全
struct SecurityView: View {
    private let items: [(icon: String, title: String, value: String)] = [
        ("lock", "修改密码", "已设置"),
        ("phone", "绑定手机", "138****8000"),
        ("person.text.rectangle", "实名认证", "未认证"),
        ("icloud", "第三方账号", "微信未绑定")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { divider }
                        NavigationLink {
                            SecurityDetailView(title: item.title)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textTertiary)
                                    .frame(width: 24)
                                Text(item.title)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text(item.value)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textTertiary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.lg)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))

                Text("如遇账号异常，请联系客服：400-000-0000")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("账号安全")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 52)
    }
}

/// 账号安全子项详情占位
private struct SecurityDetailView: View {
    let title: String
    var body: some View {
        DFEmptyState(icon: "lock.shield", title: title, subtitle: "功能开发中，敬请期待")
            .background(Color.bgPrimary)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 14. 关于
struct AboutView: View {
    private let items: [(icon: String, title: String)] = [
        ("doc.text", "用户协议"),
        ("hand.raised", "隐私政策"),
        ("star", "给我们评分"),
        ("trash", "清除缓存")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle().fill(Color.bgTertiary).frame(width: 84, height: 84)
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentDefault)
                    }
                    .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2).frame(width: 84, height: 84))
                    Text("问玄东方")
                        .font(.custom(AppFont.serif[0], size: 20).weight(.bold))
                        .foregroundStyle(Color.accentDefault)
                    Text("版本 1.0.0 (1)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { divider }
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: item.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textTertiary)
                                .frame(width: 24)
                            Text(item.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                }
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.lg)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))

                Text("© 2026 问玄东方 保留所有权利")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.bgPrimary)
        .navigationTitle("关于问玄东方")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var divider: some View {
        Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 52)
    }
}
