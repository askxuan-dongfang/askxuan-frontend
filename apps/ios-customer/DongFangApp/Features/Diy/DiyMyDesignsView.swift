//
//  DiyMyDesignsView.swift
//  DongFangApp
//
//  我的设计列表：我保存过的全部设计（草稿/审核中/已公开）以及已下单的设计，
//  每条含完整设计数据与发布状态，点击直接进入编辑器。
//

import SwiftUI

struct DiyMyDesignsView: View {
    @State private var designs: [MyDesignItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter = "all"
    @StateObject private var editorModel = DiyViewModel()
    @State private var showEditor = false
    @State private var publicationDesign: MyDesignItem?
    @State private var showPublicationConfirm = false
    @State private var busyDesignId: Int64?

    var body: some View {
        VStack(spacing: 0) {
            DFTopNavBar("我的设计", showsBackButton: true) { EmptyView() } trailing: {
                NavigationLink { DiyDesignView() } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }.accessibilityLabel(L10n.text("开始新设计"))
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if !designs.isEmpty {
                        Picker(L10n.text("作品筛选"), selection: $selectedFilter) {
                            Text(L10n.text("全部")).tag("all")
                            Text(L10n.text("已发布")).tag("public")
                            Text(L10n.text("已下单")).tag("ordered")
                        }.pickerStyle(.segmented)
                    }
                    if isLoading && designs.isEmpty {
                        ProgressView(L10n.text("正在加载作品")).tint(Color.accentDefault)
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if filteredDesigns.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: errorMessage == nil ? "square.stack" : "wifi.exclamationmark")
                                .font(.largeTitle).foregroundStyle(Color.accentDefault)
                            Text(L10n.lookup(errorMessage == nil ? (designs.isEmpty ? L10n.text("第一件作品，等你开始") : L10n.text("暂无符合筛选的作品")) : L10n.text("作品加载失败")))
                                .font(.headline).foregroundStyle(Color.textPrimary)
                            Text(L10n.lookup(errorMessage ?? L10n.text("保存搭配后，就能在这里继续编辑和分享。")))
                                .font(.subheadline).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                            if errorMessage != nil {
                                Button(L10n.text("重新加载")) { Task { await load() } }.frame(minHeight: 44)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 220).padding(16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredDesigns) { design in
                                VStack(spacing: 0) {
                                    Button { openEditor(design) } label: { designRow(design) }.buttonStyle(.plain)
                                        .accessibilityIdentifier("diy-my-design-\(design.id)")
                                    HStack {
                                        Button(L10n.text("继续编辑")) { openEditor(design) }
                                            .accessibilityIdentifier("diy-edit-design-\(design.id)")
                                        Spacer()
                                        Button(L10n.lookup(design.status == "public" ? "下架" : "发布到广场")) {
                                            publicationDesign = design; showPublicationConfirm = true
                                        }.accessibilityIdentifier("diy-publish-design-\(design.id)")
                                    }.font(.subheadline).foregroundStyle(Color.accentDefault)
                                        .frame(minHeight: 44).padding(.horizontal, 16)
                                }.background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
                                    .disabled(busyDesignId != nil)
                            }
                        }
                        if let errorMessage {
                            Text(L10n.lookup(errorMessage)).font(.caption).foregroundStyle(Color.textSecondary)
                            Button(L10n.text("重新加载")) { Task { await load() } }.frame(minHeight: 44)
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
        .sheet(isPresented: $showEditor, onDismiss: { Task { await load() } }) { NavigationStack { DiyDesignView(viewModel: editorModel) } }
        .confirmationDialog(L10n.lookup(publicationDesign?.status == "public" ? "下架后，仅你可见；已有副本与订单保留。" : "发布后，其他人可以分享、复制搭配和定制。"), isPresented: $showPublicationConfirm, titleVisibility: .visible) {
            Button(L10n.lookup(publicationDesign?.status == "public" ? "确认下架" : "确认发布")) { updatePublication() }
        }
        .alert(L10n.text("提示"), isPresented: Binding(get: { errorMessage != nil && !designs.isEmpty }, set: { if !$0 { errorMessage = nil } })) {
            Button(L10n.text("好的"), role: .cancel) {}
        } message: { Text(L10n.lookup(errorMessage ?? "")) }

    }

    private func openEditor(_ design: MyDesignItem) {
        guard busyDesignId == nil else { return }
        busyDesignId = design.id
        Task {
            await editorModel.loadDesign(id: design.id, checkAvailability: false)
            busyDesignId = nil
            if editorModel.currentDesign?.id == design.id && editorModel.isDesignOwner { showEditor = true }
            else { errorMessage = editorModel.errorMessage ?? L10n.text("暂时无法打开作品") }
        }
    }
    private func updatePublication() {
        guard let design = publicationDesign, busyDesignId == nil else { return }
        busyDesignId = design.id
        Task {
            await editorModel.loadDesign(id: design.id, checkAvailability: false, persistRestoredDraft: false)
            if editorModel.currentDesign?.id == design.id && editorModel.isDesignOwner {
                await editorModel.setPublication(design.status != "public")
            }
            let failure = editorModel.errorMessage
            busyDesignId = nil
            if let failure { errorMessage = failure } else { await load() }
        }
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
                Text(L10n.lookup(design.name))
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
                    Text(L10n.lookup(String(time.prefix(10))))
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
        return Text(L10n.lookup(text))
            .font(AppTypography.micro.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
    }

    private func orderBadge(_ status: String?) -> some View {
        Text(L10n.text("已下单 · \(orderStatusLabel(status))"))
            .font(AppTypography.micro.weight(.medium))
            .foregroundStyle(Color.stateSuccess)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(Color.stateSuccess.opacity(0.5), lineWidth: 1))
    }

    private func designStatusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "private":        return ("未发布", Color.textTertiary)
        case "public":         return ("已发布", Color.stateSuccess)
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
