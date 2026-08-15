//
//  MasterProfileView.swift
//  DongFangApp
//
//  法师主页：背景区 + 头像 + 简介 + 5 Tab + 底部双按钮。
//

import SwiftUI

struct MasterProfileView: View {
    let masterId: String

    @StateObject private var viewModel = MasterProfileViewModel()
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false
    @State private var selectedServiceCode: String?
    @State private var directBookingDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var isSubmittingDirectBooking = false
    @State private var directBookingMessage = ""
    @State private var showDirectBookingMessage = false
    @State private var showLoginPrompt = false
    @State private var paidConversation: ChatConversation?
    @State private var isResolvingConversation = false
    @State private var isPurchasingConsultation = false
    @State private var consultationQuote: ConsultationQuote?
    @State private var consultationQuestion = ""
    @State private var showConsultCheckout = false
    @State private var consultMessage = ""
    @State private var showConsultMessage = false

    private let tabs = ["资质", "预约", "文创", "视频", "咨询"]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    infoSection
                    tabBar
                    tabContent
                    Spacer(minLength: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            bottomActionBar
        }
        .background(Color.bgPrimary)
        .secondaryPage()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.master == nil { await viewModel.load(id: masterId) }
        }
        .sheet(isPresented: $showBooking) {
            if let master = viewModel.master {
                NavigationStack { BookingView(master: master) }
            }
        }
        .sheet(isPresented: $showLoginPrompt) {
            NavigationStack {
                LoginView()
                    .environmentObject(authStore)
            }
        }
        .sheet(item: $paidConversation) { conversation in
            NavigationStack {
                ChatDetailView(conversation: conversation, viewModel: ChatViewModel())
            }
        }
        .sheet(isPresented: $showConsultCheckout) {
            consultationCheckout
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("咨询提示", isPresented: $showConsultMessage) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(consultMessage)
        }
    }

    // MARK: - 背景 + 头像
    private var heroSection: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.brandDark.opacity(0.6), Color.bgPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 240)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentDefault)
                        .frame(width: 36, height: 36)
                        .background(Color.bgPrimary.opacity(0.6))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 56)

            VStack(spacing: 8) {
                RemoteAvatar(urlString: viewModel.master?.avatar, size: 80)
                    .padding(.top, 140)

                Text(viewModel.master?.dharmaName ?? "法师")
                    .font(.custom(AppFont.serif[0], size: 20).weight(.bold))
                    .foregroundStyle(Color.accentDefault)

                if let master = viewModel.master {
                    HStack(spacing: 6) {
                        Text(master.position)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.brandDefault)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.brandDefault.opacity(0.15))
                            .clipShape(Capsule())
                        Text(master.templeName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .frame(height: 240)
    }

    // MARK: - 简介
    private var infoSection: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xl) {
                statItem(icon: "star.fill",
                         value: viewModel.master?.ratingText ?? "5.0",
                         label: "评分", color: .accentDefault)
                statItem(icon: "person.badge.clock",
                         value: (viewModel.master?.isOnlineDisplay ?? true) ? "在线" : "离线",
                         label: "状态",
                         color: (viewModel.master?.isOnlineDisplay ?? true) ? .stateSuccess : .textTertiary)
                statItem(icon: "yensign.circle.fill",
                         value: viewModel.master?.consultFeeText ?? "—",
                         label: "咨询费", color: .brandDefault)
            }
            .padding(.vertical, AppSpacing.md)

            if let master = viewModel.master, !master.specialties.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("擅长领域")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                    FlowLayout(spacing: 8) {
                        ForEach(master.specialties, id: \.self) { specialty in
                            Text(specialty)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accentDefault)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.accentDefault.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
            }
        }
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 12))
                Text(value).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    let isSelected = viewModel.selectedTab == index
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedTab = index }
                    } label: {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                            Capsule()
                                .fill(isSelected ? Color.brandDefault : Color.clear)
                                .frame(width: 24, height: 3)
                        }
                        .frame(width: 70)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.bgPrimary)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
        .padding(.top, AppSpacing.lg)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case 0: qualificationPanel
        case 1: bookingPanel
        case 2: wenchuangPanel
        case 3: videoPanel
        case 4: consultPanel
        default: EmptyView()
        }
    }

    private var qualificationPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                Text("法师简介")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                Text("法师修行多年，深谙佛理，致力于弘法利生，广结善缘。擅长为信众提供禅修指导、祈福法事、开光加持等服务，深受信众敬仰。")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)

            VStack(alignment: .leading, spacing: 8) {
                Text("认证信息")
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.stateSuccess)
                    Text(viewModel.master?.authStatus ?? "已认证")
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var bookingPanel: some View {
        Group {
            if viewModel.master?.manageBy == "platform" {
                directBookingPanel
            } else {
                templeServicePanel
            }
        }
    }

    /// 野生大师直约面板：大师服务标签 → 先付费咨询 → 预约服务
    private var directBookingPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("大师服务标签")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)

            if let tags = viewModel.master?.serviceTags, !tags.isEmpty {
                ForEach(tags, id: \.self) { tag in
                    serviceTagRow(tag)
                }

                DatePicker("预约日期", selection: $directBookingDate, in: Date()..., displayedComponents: .date)
                    .padding(.horizontal, AppSpacing.lg)

                Text("先完成付费咨询，再预约服务（咨询入口见底部按钮）")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, AppSpacing.lg)

                DFPrimaryButton(title: isSubmittingDirectBooking ? "提交中…" : "预约服务", icon: "calendar.badge.plus") {
                    submitDirectBooking()
                }
                .disabled(isSubmittingDirectBooking || selectedServiceCode == nil)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            } else {
                DFEmptyState(icon: "tag", title: "暂无服务标签", subtitle: "该大师暂未配置可预约服务")
            }
        }
        .alert("预约提示", isPresented: $showDirectBookingMessage) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(directBookingMessage)
        }
    }

    private func serviceTagRow(_ tag: MasterServiceTag) -> some View {
        let isSelected = selectedServiceCode == tag.serviceCode
        let iconName = ServiceType.from(serviceCode: tag.serviceCode)?.iconName ?? "sparkles"
        let title = ServiceType.from(serviceCode: tag.serviceCode)?.rawValue ?? tag.serviceCode
        return Button {
            selectedServiceCode = tag.serviceCode
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(Color.brandDefault.opacity(0.12))
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brandDefault)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(String(format: "¥%.2f", tag.price))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.brandDefault)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(isSelected ? Color.brandDefault : Color.borderDefault, lineWidth: 1))
            .padding(.horizontal, AppSpacing.lg)
        }
        .buttonStyle(.plain)
    }

    private var templeServicePanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("可预约服务")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)

            ForEach(viewModel.services) { service in
                if let type = ServiceType.from(serviceCode: service.serviceCode) {
                    NavigationLink(value: HomeRoute.service(type)) {
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .fill(Color.brandDefault.opacity(0.12))
                                Image(systemName: type.iconName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.brandDefault)
                            }
                            .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.serviceName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(type.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(AppSpacing.md)
                        .background(Color.bgSecondary)
                        .cornerRadius(AppRadius.lg)
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var wenchuangPanel: some View {
        DFEmptyState(icon: "shippingbox", title: "文创商品", subtitle: "敬请期待")
    }
    private var videoPanel: some View {
        DFEmptyState(icon: "play.rectangle", title: "法师视频", subtitle: "敬请期待")
    }
    private var consultPanel: some View {
        VStack(spacing: AppSpacing.md) {
            Text("在线咨询")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.top, AppSpacing.md)
            Text("法师将为您解答佛学疑问、指引修行方向。")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Text("即时咨询单独付费，不要求先预约服务；预约法事、祈福等服务需另行下单。")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity)
    }

    private func submitDirectBooking() {
        guard let master = viewModel.master, let code = selectedServiceCode else { return }
        isSubmittingDirectBooking = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let request = DirectBookingRequest(
            serviceCode: code,
            bookingDate: formatter.string(from: directBookingDate),
            requestId: UUID().uuidString,
            note: nil)
        Task {
            defer { isSubmittingDirectBooking = false }
            do {
                let resp: DirectBookingResponse = try await APIClient.shared.request(.masterBooking(master.id, request))
                directBookingMessage = "预约成功！单号 \(resp.id)，请等待法师确认（\(resp.paymentStatus)）"
            } catch {
                directBookingMessage = error.localizedDescription
            }
            showDirectBookingMessage = true
        }
    }

    // MARK: - 底部操作栏
    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            DFSecondaryButton(title: consultationButtonTitle) {
                if authStore.isLoggedIn {
                    guard !isResolvingConversation else { return }
                    Task { await openPaidConversation() }
                } else {
                    showLoginPrompt = true
                }
            }
            DFPrimaryButton(title: "预约服务") {
                if authStore.isLoggedIn {
                    showBooking = true
                } else {
                    showLoginPrompt = true
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            Color.bgPrimary.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) { Rectangle().fill(Color.borderDivider).frame(height: 1) }
    }

    @MainActor
    private func openPaidConversation() async {
        isResolvingConversation = true
        defer { isResolvingConversation = false }
        do {
            let response: BookingChatListResponse = try await APIClient.shared.request(.chats(page: 1, size: 100))
            if let conversation = response.list.first(where: { $0.masterId == masterId && $0.canChat }) {
                paidConversation = conversation
            } else {
                let quote: ConsultationQuote = try await APIClient.shared.request(.consultationQuote(masterId: masterId))
                guard quote.enabled else {
                    consultMessage = "该法师暂未开通即时咨询，可先预约寺院服务。"
                    showConsultMessage = true
                    return
                }
                consultationQuote = quote
                showConsultCheckout = true
            }
        } catch {
            consultMessage = error.localizedDescription
            showConsultMessage = true
        }
    }

    private var consultationButtonTitle: String {
        if isResolvingConversation { return "查询中..." }
        if let fee = viewModel.master?.consultFeeText { return "立即咨询 \(fee)" }
        return "立即咨询"
    }

    private var consultationCheckout: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let quote = consultationQuote {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("向\(quote.masterName)发起即时咨询")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("文字咨询有效 \(quote.validHours) 小时，法师承诺尽量在 \(quote.responseMinutes) 分钟内响应。预约服务不包含在本订单中。")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    TextField("简要描述想咨询的问题（可选）", text: $consultationQuestion, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(AppSpacing.md)
                        .background(Color.bgSecondary)
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault))

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("即时咨询费")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textTertiary)
                            Text("款项先进入平台总账，再按规则结算")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer()
                        Text("¥\(Int(quote.consultFee))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.brandDefault)
                    }

                    Button {
                        Task { await purchaseConsultation() }
                    } label: {
                        HStack {
                            if isPurchasingConsultation { ProgressView().tint(.white) }
                            Text(isPurchasingConsultation ? "支付中..." : "模拟支付并开始咨询")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.brandDefault)
                        .cornerRadius(AppRadius.md)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasingConsultation)
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("确认咨询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showConsultCheckout = false }
                }
            }
        }
    }

    @MainActor
    private func purchaseConsultation() async {
        guard consultationQuote != nil, !isPurchasingConsultation else { return }
        isPurchasingConsultation = true
        defer { isPurchasingConsultation = false }
        do {
            let request = ConsultationCreateRequest(requestId: UUID().uuidString,
                                                    masterId: masterId,
                                                    question: consultationQuestion)
            let order: ConsultationOrder = try await APIClient.shared.request(.consultationCreate(request))
            guard order.paymentStatus == "success", order.status == "active" else {
                consultMessage = "支付尚未完成，请稍后重试。"
                showConsultMessage = true
                return
            }
            let response: BookingChatListResponse = try await APIClient.shared.request(.chats(page: 1, size: 100))
            guard let conversation = response.list.first(where: { $0.id == order.conversationId }) else {
                consultMessage = "咨询已支付成功，会话正在创建，请到“对话”列表刷新。"
                showConsultMessage = true
                showConsultCheckout = false
                return
            }
            showConsultCheckout = false
            try? await Task.sleep(for: .milliseconds(250))
            paidConversation = conversation
        } catch {
            consultMessage = error.localizedDescription
            showConsultMessage = true
        }
    }
}

/// 简单的流式布局（标签自动换行）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth == .infinity ? lineWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack { MasterProfileView(masterId: "M001") }
        .preferredColorScheme(.dark)
}
