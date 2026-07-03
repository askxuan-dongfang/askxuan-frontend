//
//  BookingDetailView.swift
//  MasterApp
//
//  预约详情（页面 4）：含确认/接单、完成操作。
//  GET admin/masters/bookings/:id
//  PUT admin/masters/bookings/:id/confirm
//  PUT admin/masters/bookings/:id/complete
//

import SwiftUI

@MainActor
final class BookingDetailViewModel: ObservableObject {
    @Published var booking: Booking?
    @Published var isLoading: Bool = false
    @Published var isActionLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    let bookingId: String
    private let apiClient: APIClient

    init(bookingId: String, apiClient: APIClient = .shared) {
        self.bookingId = bookingId
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let booking: Booking = try await apiClient.request(.masterBookingDetail(id: bookingId))
            self.booking = booking
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    func confirm() async {
        guard let b = booking, b.statusEnum == .pending else { return }
        await runAction(.masterBookingConfirm(id: bookingId, remark: nil), successText: "已确认预约")
    }

    func complete() async {
        guard let b = booking, b.statusEnum == .inProgress || b.statusEnum == .confirmed else { return }
        await runAction(.masterBookingComplete(id: bookingId, remark: nil), successText: "已完成服务")
    }

    private func runAction(_ endpoint: Endpoint, successText: String) async {
        isActionLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let resp: BookingStatusResponse = try await apiClient.request(endpoint)
            successMessage = successText
            // 更新本地状态
            if var b = booking {
                b = Booking(id: b.id, userId: b.userId, templeId: b.templeId, templeName: b.templeName,
                            masterId: b.masterId, masterName: b.masterName, serviceId: b.serviceId,
                            serviceName: b.serviceName, bookingDate: b.bookingDate, timeSlot: b.timeSlot,
                            meritMoney: b.meritMoney, meritMoneyTier: b.meritMoneyTier,
                            status: resp.status, note: b.note, createdAt: b.createdAt)
                booking = b
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "操作失败：\(error.localizedDescription)"
        }
        isActionLoading = false
    }
}

struct BookingDetailView: View {
    let bookingId: String
    @StateObject private var viewModel: BookingDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(bookingId: String) {
        self.bookingId = bookingId
        _viewModel = StateObject(wrappedValue: BookingDetailViewModel(bookingId: bookingId))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                LoadingView(fullScreen: true)
            } else if let booking = viewModel.booking {
                VStack(spacing: AppSpacing.lg) {
                    // 状态头
                    statusHeader(booking)

                    // 服务信息
                    infoCard(title: "服务信息", icon: "sparkles") {
                        infoRow("服务", booking.serviceName)
                        infoRow("寺院", booking.templeName)
                        infoRow("时段", "\(booking.bookingDate)  \(booking.timeSlot)")
                        infoRow("功德金", booking.meritMoneyText)
                        infoRow("档位", booking.meritMoneyTier)
                    }

                    // 信众信息
                    infoCard(title: "信众信息", icon: "person") {
                        infoRow("信众ID", booking.userId.isEmpty ? "匿名" : booking.userId)
                        infoRow("备注", booking.note.isEmpty ? "无" : booking.note)
                        infoRow("下单时间", DFDateFormatter.friendly(booking.createdAt))
                    }

                    // 操作按钮
                    actionSection(booking)
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.bottom, AppSpacing.xl)
            } else {
                EmptyState(icon: "exclamationmark.triangle.fill",
                           title: "加载失败",
                           message: viewModel.errorMessage) {
                    Task { await viewModel.load() }
                }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("预约详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
        .alert("提示", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("好的") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    private func statusHeader(_ booking: Booking) -> some View {
        MasterCard(padding: AppSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.serviceName)
                        .font(.pageTitle)
                        .foregroundStyle(.textPrimary)
                    Text("单号：\(booking.id)")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                }
                Spacer()
                StatusBadge(status: booking.status, kind: .booking)
            }
        }
    }

    private func infoCard<Content: View>(title: String, icon: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        MasterCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.accentDefault)
                    Text(title)
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                }
                content()
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.textTertiary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func actionSection(_ booking: Booking) -> some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.stateError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        let status = booking.statusEnum
        if status.isTerminal {
            Text("该预约已结单")
                .font(.caption)
                .foregroundStyle(.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
        } else {
            VStack(spacing: AppSpacing.md) {
                if status == .pending {
                    PrimaryButton(title: "确认接单", icon: "checkmark.circle.fill",
                                  isLoading: viewModel.isActionLoading) {
                        Task { await viewModel.confirm() }
                    }
                }
                if status == .confirmed || status == .inProgress {
                    PrimaryButton(title: "完成服务", icon: "checkmark.seal.fill",
                                  isLoading: viewModel.isActionLoading) {
                        Task { await viewModel.complete() }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookingDetailView(bookingId: "B20260630001")
    }
    .preferredColorScheme(.dark)
}
