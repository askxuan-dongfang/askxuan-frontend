//
//  BookingView.swift
//  DongFangApp
//
//  预约下单页：服务摘要 + 服务项单选 + 日期时段 + 功德金 + 备注 + 价格汇总 + 提交。
//

import SwiftUI

struct BookingView: View {
    @StateObject private var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    init(master: Master) {
        _viewModel = StateObject(wrappedValue: BookingViewModel(master: master))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    if viewModel.isSuccess {
                        successView
                    } else {
                        VStack(spacing: 20) {
                            serviceSummaryCard
                            serviceSelectionSection
                            dateTimeSection
                            remarkSection
                            meritSection
                            priceSummarySection
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.lg)
                    }
                }
                .background(Color.bgPrimary)

                if !viewModel.isSuccess {
                    bottomSubmitBar
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("预约服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.accentDefault)
                    }
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - 服务摘要卡
    private var serviceSummaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            Image(viewModel.master.avatarAssetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.master.dharmaName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(viewModel.master.templeName) · \(viewModel.master.position)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
                HStack(spacing: 8) {
                    Text("在线预约")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(Color.brandDefault)
                        .clipShape(Capsule())
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text(viewModel.master.ratingText)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentDefault)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - 服务项单选
    private var serviceSelectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("选择服务项目")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 10) {
                ForEach(Array(viewModel.services.enumerated()), id: \.element.id) { index, service in
                    let isSelected = viewModel.selectedServiceIndex == index
                    Button {
                        viewModel.selectedServiceIndex = index
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            // 单选指示器
                            ZStack {
                                Circle()
                                    .stroke(isSelected ? Color.brandDefault : Color.textTertiary, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if isSelected {
                                    Circle()
                                        .fill(Color.brandDefault)
                                        .frame(width: 10, height: 10)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                Text(service.duration)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("¥\(Int(service.price))")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.brandDefault)
                                Text("/次")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                        .padding(14)
                        .background(isSelected ? Color.brandDefault.opacity(0.08) : Color.bgSecondary)
                        .cornerRadius(AppRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(isSelected ? Color.brandDefault : Color.borderDefault,
                                        lineWidth: isSelected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 日期 / 时段
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("选择预约时间")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            // 日期横向滚动
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Array(viewModel.dates.enumerated()), id: \.offset) { index, _ in
                        let isSelected = viewModel.selectedDateIndex == index
                        Button {
                            viewModel.selectedDateIndex = index
                        } label: {
                            VStack(spacing: 4) {
                                Text(viewModel.dateLabel(for: index))
                                    .font(.system(size: 12))
                                    .foregroundStyle(isSelected ? Color.textPrimary.opacity(0.7) : Color.textTertiary)
                                Text(viewModel.dateNumber(for: index))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : Color.textSecondary)
                            }
                            .frame(width: 60, height: 64)
                            .background(isSelected ? Color.brandDefault : Color.bgSecondary)
                            .cornerRadius(AppRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(isSelected ? Color.brandDefault : Color.borderDefault,
                                            lineWidth: isSelected ? 0 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 时段
            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(viewModel.timeSlots.enumerated()), id: \.element.id) { index, slot in
                    let isSelected = viewModel.selectedTimeSlotIndex == index
                    Button {
                        viewModel.selectedTimeSlotIndex = index
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: slot.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? Color.brandDefault : Color.accentDefault)
                            Text(slot.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                            Text(slot.range)
                                .font(.system(size: 11))
                                .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(isSelected ? Color.brandDefault.opacity(0.08) : Color.bgSecondary)
                        .cornerRadius(AppRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(isSelected ? Color.brandDefault : Color.borderDefault,
                                        lineWidth: isSelected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 备注
    private var remarkSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("备注说明（选填）")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            TextEditor(text: $viewModel.note)
                .frame(height: 80)
                .padding(AppSpacing.sm)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
                .scrollContentBackground(.hidden)
                .foregroundStyle(Color.textPrimary)
                .font(.body)
                .overlay(alignment: .topLeading) {
                    if viewModel.note.isEmpty {
                        Text("请描述您的需求或祈福对象...")
                            .font(.body)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - 功德金
    private var meritSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("随喜功德（选填）")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(viewModel.meritOptions.enumerated()), id: \.offset) { index, amount in
                    let isSelected = viewModel.selectedMeritIndex == index
                    Button {
                        viewModel.selectedMeritIndex = index
                    } label: {
                        Text(amount == 0 ? "随喜" : "¥\(amount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isSelected ? .white : Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(isSelected ? Color.brandDefault : Color.bgSecondary)
                            .cornerRadius(AppRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(isSelected ? Color.brandDefault : Color.borderDefault,
                                            lineWidth: isSelected ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                // 自定义
                Button {
                    viewModel.selectedMeritIndex = -1
                } label: {
                    Text("自定义")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(viewModel.selectedMeritIndex == -1 ? .white : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(viewModel.selectedMeritIndex == -1 ? Color.brandDefault : Color.bgSecondary)
                        .cornerRadius(AppRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(viewModel.selectedMeritIndex == -1 ? Color.brandDefault : Color.borderDefault,
                                        lineWidth: viewModel.selectedMeritIndex == -1 ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // 自定义金额输入
            if viewModel.selectedMeritIndex == -1 {
                HStack(spacing: 6) {
                    Text("¥")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)
                    TextField("自定义金额", text: $viewModel.customMeritAmount)
                        .keyboardType(.numberPad)
                        .foregroundStyle(Color.textPrimary)
                        .font(.body)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 44)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 价格汇总
    private var priceSummarySection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("服务费用")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("¥\(Int(viewModel.serviceFee))")
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
            }
            HStack {
                Text("随喜功德")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(viewModel.meritMoney > 0 ? "¥\(Int(viewModel.meritMoney))" : "随喜")
                    .font(.body)
                    .foregroundStyle(Color.accentDefault)
            }
            Rectangle().fill(Color.borderDefault).frame(height: 1)
            HStack {
                Text("合计")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("¥\(Int(viewModel.totalAmount))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }
        }
        .padding(AppSpacing.lg)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - 底部提交栏
    private var bottomSubmitBar: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.stateError)
                    .padding(.top, AppSpacing.sm)
            }
            DFPrimaryButton(title: viewModel.isSubmitting ? "提交中..." : "确认预约并支付",
                            isLoading: viewModel.isSubmitting,
                            isEnabled: viewModel.canSubmit) {
                Task { await viewModel.submit() }
            }
            .padding(AppSpacing.lg)
        }
        .background(
            Color.bgPrimary.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }

    // MARK: - 提交成功页
    private var successView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            // 成功图标
            ZStack {
                Circle()
                    .fill(Color.stateSuccess.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.stateSuccess)
            }

            Text("预约提交成功")
                .font(.custom(AppFont.serif, size: 20).weight(.bold))
                .foregroundStyle(Color.textPrimary)

            Text("法师将在确认后为您安排服务，请留意消息通知。")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            // 订单信息卡
            if let booking = viewModel.createdBooking {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    successInfoRow(label: "订单号", value: booking.id)
                    successInfoRow(label: "服务", value: booking.serviceName)
                    successInfoRow(label: "师傅", value: booking.masterName ?? viewModel.master.dharmaName)
                    successInfoRow(label: "日期", value: booking.bookingDate)
                    successInfoRow(label: "时段", value: booking.timeSlot)
                    successInfoRow(label: "状态", value: booking.status)
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
                .padding(.horizontal, AppSpacing.lg)
            }

            Spacer()

            DFPrimaryButton(title: "完成") {
                dismiss()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func successInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(Color.textPrimary)
        }
    }
}

#Preview {
    BookingView(master: Master.mockData[0])
        .preferredColorScheme(.dark)
}
