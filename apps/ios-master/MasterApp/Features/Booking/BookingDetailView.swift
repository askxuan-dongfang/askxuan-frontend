//
//  BookingDetailView.swift
//  MasterApp
//
//  预约详情：接单、执行、阶段记录与最终回执；由信众确认完成。
//  GET admin/masters/bookings/:id
//  PUT admin/masters/bookings/:id/confirm
//  PUT admin/masters/bookings/:id/start
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

    func load(showLoading: Bool = true) async {
        if showLoading { isLoading = true }
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

    func start() async {
        guard let b = booking, b.statusEnum == .confirmed else { return }
        await runAction(.masterBookingStart(id: bookingId, remark: nil), successText: "服务已开始")
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
                            serviceName: b.serviceName, bookingDate: b.bookingDate, slotCode: b.slotCode,
                            timeSlot: b.timeSlot, serviceFee: b.serviceFee, meritMoney: b.meritMoney,
                            totalFee: b.totalFee, paymentStatus: b.paymentStatus, paymentNo: b.paymentNo,
                            meritMoneyTier: b.meritMoneyTier,
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
                    JourneyRecordPanel(bookingId: bookingId) { _ in Task { await viewModel.load(showLoading: false) } }
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
                        .font(AppTypography.caption)
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
                        .font(AppTypography.body)
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
                .font(AppTypography.caption)
                .foregroundStyle(.textTertiary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }


}

#Preview {
    NavigationStack {
        BookingDetailView(bookingId: "B20260630001")
    }
    .preferredColorScheme(.dark)
}
