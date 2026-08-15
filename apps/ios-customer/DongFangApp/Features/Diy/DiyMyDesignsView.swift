//
//  DiyMyDesignsView.swift
//  DongFangApp
//
//  我的设计列表：我保存过的全部设计（草稿/审核中/已公开）以及已下单的设计，
//  每条含完整设计数据（排布、状态、订单信息），点击进入设计详情。
//

import SwiftUI

struct DiyMyDesignsView: View {
    @State private var designs: [MyDesignItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar("我的设计", showsBackButton: true) {
                EmptyView()
            } trailing: {
                EmptyView()
            }

            Group {
                if isLoading && designs.isEmpty {
                    ProgressView("正在加载设计")
                        .tint(Color.accentDefault)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if designs.isEmpty {
                    DFEmptyState(icon: "doc.on.doc", title: "还没有设计",
                                 subtitle: errorMessage ?? "点击「开始设计」，你保存的草稿和下单的手串都会显示在这里")
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(designs) { design in
                                NavigationLink {
                                    DiyDetailView(designId: design.id)
                                } label: {
                                    designRow(design)
                                }
                                .buttonStyle(CardPressButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.navBottom + 32)
                    }
                    .refreshable { await load() }
                }
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        if designs.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            let resp: PageResponse<MyDesignItem> = try await APIClient.shared.request(
                .diyMyDesigns(page: 1, size: 50))
            designs = resp.list
        } catch {
            if (error as? APIError)?.isCancellation == true || error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - 行视图
    private func designRow(_ design: MyDesignItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(Color.brandDefault.opacity(0.12))
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandDefault)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(design.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    statusBadge(design.status)
                    if design.hasOrder {
                        orderBadge(design.orderStatus)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("¥\(design.totalPrice, specifier: "%.2f")")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
                if let time = design.updateTime, !time.isEmpty {
                    Text(String(time.prefix(10)))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDivider, lineWidth: 1))
    }

    private func statusBadge(_ status: String) -> some View {
        let (text, color) = designStatusInfo(status)
        return Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
    }

    private func orderBadge(_ status: String?) -> some View {
        Text("已下单 · \(orderStatusLabel(status))")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.stateSuccess)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(Color.stateSuccess.opacity(0.5), lineWidth: 1))
    }

    private func designStatusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "private":        return ("草稿", Color.textTertiary)
        case "public":         return ("已公开", Color.stateSuccess)
        case "pending_review": return ("审核中", Color.stateWarning)
        case "approved":       return ("已通过", Color.stateSuccess)
        case "rejected":       return ("已驳回", Color.stateError)
        default:               return (status, Color.textTertiary)
        }
    }

    private func orderStatusLabel(_ status: String?) -> String {
        switch status {
        case "pending_review":        return "待审核"
        case "in_making":             return "制作中"
        case "awaiting_blessing":     return "待加持"
        case "blessing_in_progress":  return "加持中"
        case "blessing_completed":    return "加持完成"
        case "awaiting_shipment":     return "待发货"
        case "shipped":               return "已发货"
        case "completed":             return "已完成"
        case "cancelled":             return "已取消"
        case "in_return":             return "退换中"
        default:                      return status ?? "已下单"
        }
    }
}
