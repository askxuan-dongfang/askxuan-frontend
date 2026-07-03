//
//  EarningsView.swift
//  MasterApp
//
//  收益概览（页面 10）：含提现入口。
//  GET admin/masters/earnings/summary
//  GET admin/masters/earnings/details
//  POST admin/finance/withdrawals/apply（JWT 保护路由）
//

import SwiftUI

@MainActor
final class EarningsViewModel: ObservableObject {
    @Published var summary: EarningsSummary?
    @Published var details: [EarningsDetailItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // 提现
    @Published var showWithdrawSheet: Bool = false
    @Published var withdrawAmount: String = ""
    @Published var withdrawBankCard: String = ""
    @Published var isWithdrawing: Bool = false
    @Published var withdrawMessage: String? = nil

    private let apiClient: APIClient
    private var page: Int = 1
    private let size: Int = 20
    private var hasMore: Bool = true

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        async let summaryResult = fetchSummary()
        async let detailsResult = fetchDetails()

        let (s, d) = await (summaryResult, detailsResult)
        switch s {
        case .success(let v): summary = v
        case .failure: summary = nil
        }
        switch d {
        case .success(let list): details = list
        case .failure: details = []
        }
        isLoading = false
    }

    private func fetchSummary() async -> Result<EarningsSummary, Error> {
        do {
            let v: EarningsSummary = try await apiClient.request(.earningsSummary)
            return .success(v)
        } catch { return .failure(error) }
    }

    private func fetchDetails() async -> Result<[EarningsDetailItem], Error> {
        do {
            let resp: EarningsDetailResponse = try await apiClient.request(
                .earningsDetails(serviceType: nil, page: page, size: size)
            )
            hasMore = resp.list.count < Int(resp.total)
            return .success(resp.list)
        } catch { return .failure(error) }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        page += 1
        do {
            let resp: EarningsDetailResponse = try await apiClient.request(
                .earningsDetails(serviceType: nil, page: page, size: size)
            )
            details.append(contentsOf: resp.list)
            hasMore = resp.list.count < Int(resp.total)
        } catch { }
    }

    var maxWithdrawable: Double { summary?.withdrawable ?? 0 }

    /// 提现申请
    func applyWithdrawal() async {
        let amount = Double(withdrawAmount)
        let card = withdrawBankCard.trimmingCharacters(in: .whitespaces)
        guard let amount, amount > 0, !card.isEmpty else {
            withdrawMessage = "请输入有效金额与银行卡号"
            return
        }
        guard amount <= maxWithdrawable else {
            withdrawMessage = "提现金额不得超过可提现余额 ¥\(String(format: "%.2f", maxWithdrawable))"
            return
        }
        isWithdrawing = true
        withdrawMessage = nil
        do {
            let req = WithdrawalApplyRequest(amount: amount, bankCard: card)
            let _: WithdrawalApplyResponse = try await apiClient.request(.withdrawalApply(req))
            withdrawMessage = "提现申请已提交，等待审核"
            withdrawAmount = ""
            withdrawBankCard = ""
            // 刷新概览
            await load()
            showWithdrawSheet = false
        } catch let error as APIError {
            withdrawMessage = error.errorDescription
        } catch {
            withdrawMessage = "提现失败：\(error.localizedDescription)"
        }
        isWithdrawing = false
    }
}

struct EarningsView: View {
    @StateObject private var viewModel = EarningsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                summarySection
                withdrawButton
                trendSection
                detailsSection
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.bgPrimary)
        .navigationTitle("收益中心")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PricingView()
                } label: {
                    Text("定价")
                        .font(.caption)
                        .foregroundStyle(.accentDefault)
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $viewModel.showWithdrawSheet) {
            withdrawSheet
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.withdrawMessage != nil && !viewModel.showWithdrawSheet },
            set: { if !$0 { viewModel.withdrawMessage = nil } }
        )) {
            Button("好的") { viewModel.withdrawMessage = nil }
        } message: {
            Text(viewModel.withdrawMessage ?? "")
        }
    }

    // MARK: - 概览

    private var summarySection: some View {
        MasterCard(padding: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                Text("可提现余额（元）")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                Text(String(format: "%.2f", viewModel.summary?.withdrawable ?? 0))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.accentDefault)

                HStack(spacing: AppSpacing.xl) {
                    summaryItem("本月收益", viewModel.summary?.monthIncome ?? 0)
                    summaryItem("累计收益", viewModel.summary?.totalIncome ?? 0)
                }
                .padding(.top, AppSpacing.sm)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryItem(_ title: String, _ value: Double) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.micro)
                .foregroundStyle(.textTertiary)
            Text("¥\(String(format: "%.2f", value))")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.textPrimary)
        }
    }

    private var withdrawButton: some View {
        PrimaryButton(title: "申请提现", icon: "arrow.up.circle.fill",
                      isEnabled: viewModel.maxWithdrawable > 0) {
            viewModel.showWithdrawSheet = true
        }
    }

    // MARK: - 提现弹窗

    private var withdrawSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    MasterCard(padding: AppSpacing.lg) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("可提现余额")
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                            Text("¥\(String(format: "%.2f", viewModel.maxWithdrawable))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.accentDefault)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    DFTextField(title: "提现金额（元）", text: $viewModel.withdrawAmount,
                                placeholder: "请输入提现金额", icon: "yensign.circle")
                        .keyboardType(.decimalPad)
                    DFTextField(title: "银行卡号", text: $viewModel.withdrawBankCard,
                                placeholder: "请输入收款银行卡号", icon: "creditcard")
                        .keyboardType(.numberPad)

                    if let msg = viewModel.withdrawMessage, viewModel.showWithdrawSheet {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(msg.contains("已提交") ? .stateSuccess : .stateError)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: "确认提现",
                                  isLoading: viewModel.isWithdrawing) {
                        Task { await viewModel.applyWithdrawal() }
                    }

                    Text("提现申请提交后将进入审核流程，到账时间以银行为准。")
                        .font(.micro)
                        .foregroundStyle(.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, AppSpacing.lg)
            }
            .background(Color.bgPrimary)
            .navigationTitle("申请提现")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { viewModel.showWithdrawSheet = false }
                        .foregroundStyle(.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 趋势

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("收益趋势")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
            MasterCard(padding: AppSpacing.md) {
                let trend = viewModel.summary?.trend ?? []
                let maxValue = trend.map { $0.amount }.max() ?? 1
                VStack(spacing: AppSpacing.sm) {
                    ForEach(trend) { item in
                        HStack(spacing: AppSpacing.md) {
                            Text(item.month)
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                                .frame(width: 56, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.bgTertiary)
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: [.brandDefault, .accentDefault],
                                                             startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(item.amount / maxValue), height: 10)
                                }
                            }
                            .frame(height: 10)
                            Text("¥\(String(format: "%.0f", item.amount))")
                                .font(.caption)
                                .foregroundStyle(.textPrimary)
                                .frame(width: 64, alignment: .trailing)
                        }
                        .frame(height: 22)
                    }
                    if trend.isEmpty {
                        Text("暂无趋势数据")
                            .font(.caption)
                            .foregroundStyle(.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                    }
                }
            }
        }
    }

    // MARK: - 明细

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("收益明细")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)

            if viewModel.isLoading && viewModel.details.isEmpty {
                LoadingView(message: "加载明细...")
                    .frame(maxWidth: .infinity)
            } else if viewModel.details.isEmpty {
                EmptyState(icon: "doc.text.magnifyingglass", title: "暂无明细")
            } else {
                ForEach(viewModel.details) { item in
                    MasterCard(padding: AppSpacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.serviceTypeText)
                                    .font(.cardTitle)
                                    .foregroundStyle(.textPrimary)
                                Text("\(item.userName) · \(DFDateFormatter.dayOnly(item.date))")
                                    .font(.micro)
                                    .foregroundStyle(.textTertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("¥\(String(format: "%.2f", item.amount))")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.accentDefault)
                                Text(item.settleStatusText)
                                    .font(.micro)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                    }
                    .onAppear {
                        if item.id == viewModel.details.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EarningsView()
    }
    .preferredColorScheme(.dark)
}
