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
    @State private var selectedFilter = "all"

    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar("我的作品", showsBackButton: true) { EmptyView() } trailing: {
                NavigationLink { DiyDesignView() } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }.accessibilityLabel("开始新设计")
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("每一串，都是你的心意").font(AppTypography.title(24)).foregroundStyle(Color.textPrimary)
                        Text("收藏搭配灵感，随时继续创作。")
                            .font(.subheadline).foregroundStyle(Color.textSecondary)
                        NavigationLink { DiyDesignView() } label: {
                            Label("开始新设计", systemImage: "plus")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentLight)
                                .frame(minHeight: 44)
                        }.buttonStyle(DiyPressButtonStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(20).diySurface(highlighted: true)
                    if !designs.isEmpty {
                        Picker("作品筛选", selection: $selectedFilter) {
                            Text("全部").tag("all")
                            Text("已公开").tag("public")
                            Text("已下单").tag("ordered")
                        }.pickerStyle(.segmented)
                    }
                    if isLoading && designs.isEmpty {
                        ProgressView("正在加载作品").tint(Color.accentDefault)
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if filteredDesigns.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: errorMessage == nil ? "square.stack" : "wifi.exclamationmark")
                                .font(.largeTitle).foregroundStyle(Color.accentDefault)
                            Text(errorMessage == nil ? (designs.isEmpty ? "第一件作品，等你开始" : "暂无符合筛选的作品") : "作品加载失败")
                                .font(.headline).foregroundStyle(Color.textPrimary)
                            Text(errorMessage ?? "保存搭配后，就能在这里继续编辑和分享。")
                                .font(.subheadline).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                            if errorMessage != nil {
                                Button("重新加载") { Task { await load() } }.frame(minHeight: 44)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 220).padding(16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredDesigns) { design in
                                NavigationLink { DiyDetailView(designId: design.id) } label: { designRow(design) }
                                    .buttonStyle(DiyPressButtonStyle())
                            }
                        }
                        if let errorMessage {
                            Text(errorMessage).font(.caption).foregroundStyle(Color.textSecondary)
                            Button("重新加载") { Task { await load() } }.frame(minHeight: 44)
                        }
                    }
                }
                .padding(16).padding(.bottom, AppSpacing.navBottom)
            }
            .refreshable { await load() }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
    }

    private var filteredDesigns: [MyDesignItem] {
        designs.filter { selectedFilter == "all" || (selectedFilter == "ordered" ? $0.hasOrder : $0.status == "public") }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let resp: PageResponse<MyDesignItem> = try await APIClient.shared.request(
                .diyMyDesigns(page: 1, size: 50))
            designs = resp.list
        } catch {
            if (error as? APIError)?.isCancellation == true || error is CancellationError { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 行视图
    private func designRow(_ design: MyDesignItem) -> some View {
        HStack(spacing: 14) {
            DiyMiniBracelet(slots: DiyDesignPreview.slots(from: design.designData), fallbackCount: 0)
                .frame(width: 78, height: 84)
                .background(Color.bgTertiary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(design.name)
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 6) {
                    statusBadge(design.status)
                    if design.hasOrder {
                        orderBadge(design.orderStatus)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("¥\(design.totalPrice, specifier: "%.2f")")
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(Color.accentLight)
                if let time = design.updateTime, !time.isEmpty {
                    Text(String(time.prefix(10)))
                        .font(AppTypography.micro)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(AppSpacing.md)
        .diySurface()
    }

    private func statusBadge(_ status: String) -> some View {
        let (text, color) = designStatusInfo(status)
        return Text(text)
            .font(AppTypography.micro.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
    }

    private func orderBadge(_ status: String?) -> some View {
        Text("已下单 · \(orderStatusLabel(status))")
            .font(AppTypography.micro.weight(.medium))
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
