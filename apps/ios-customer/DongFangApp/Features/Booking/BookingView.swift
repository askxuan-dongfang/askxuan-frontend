//
//  BookingView.swift
//  DongFangApp
//
//  预约下单页：对齐产品原型 booking.html 布局。
//  自定义顶部导航 + 法师卡 + 服务选择 + 日期时段 + 备注 + 功德 + 价格汇总 + 底部 CTA。
//

import SwiftUI

struct BookingView: View {
    @StateObject private var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss

    init(master: Master) {
        _viewModel = StateObject(wrappedValue: BookingViewModel(master: master))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topNav
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        masterCard
                        serviceSection
                        dateTimeSection
                        remarkSection
                        meritSection
                        priceSummary
                        Spacer().frame(height: 24)
                    }
                    .padding(.top, AppSpacing.lg)
                }
            }

            bottomCTA
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
		.task { await viewModel.loadServices() }
		.onChange(of: viewModel.selectedServiceId) { _, _ in
			Task { await viewModel.refreshAvailability() }
		}
        .alert("提交失败", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("预约成功", isPresented: $viewModel.showSuccess) {
            Button("好的") { dismiss() }
        } message: {
			Text(viewModel.submittedBooking?.simulated == true ? "模拟支付成功，预约已进入寺院待确认。" : "预约已提交，请完成支付。")
        }
    }

    // MARK: - 顶部导航（返回 + 标题）
    private var topNav: some View {
        ZStack {
            Text("预约服务")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentDefault)
        }
        .frame(height: AppSpacing.navTop)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentDefault)
                    .padding(.leading, AppSpacing.lg)
            }
            .buttonStyle(.plain)
        }
        .background(Color.bgPrimary.opacity(0.92).background(.ultraThinMaterial))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1)
        }
    }

    // MARK: - 法师信息卡
    private var masterCard: some View {
        HStack(spacing: 12) {
            RemoteAvatar(urlString: viewModel.master.avatar, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.master.dharmaName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text("\(viewModel.master.templeName) · \(viewModel.master.position)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)

                HStack(spacing: 8) {
                    if let specialty = viewModel.master.specialties.first {
                        Text(specialty)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 2)
                            .background(Color.brandDefault)
                            .clipShape(Capsule())
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentDefault)
                        Text(viewModel.master.ratingText)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.accentDefault)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - 服务选择
    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择服务项目")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 10) {
				ForEach(viewModel.services) { service in
                    serviceCard(service)
                }
				if viewModel.services.isEmpty && !viewModel.isLoading {
					Text("该寺院暂无可预约服务")
						.font(.system(size: 14))
						.foregroundStyle(Color.textTertiary)
				}
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 20)
    }

	private func serviceCard(_ service: TempleServiceInfo) -> some View {
		let isSelected = viewModel.selectedServiceId == service.serviceCode

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
				viewModel.selectedServiceId = service.serviceCode
            }
        } label: {
            HStack(spacing: 12) {
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
					Text(service.serviceName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
					Text("以寺院实时可用时段为准")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                HStack(spacing: 0) {
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
                    .stroke(isSelected ? Color.brandDefault : Color.borderDefault, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 日期 + 时段
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择预约时间")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)

            // 日期横向滚动（7 天）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Array(viewModel.upcomingDates.prefix(7).enumerated()), id: \.offset) { index, date in
                        let isSelected = viewModel.selectedDateIndex == index
                        VStack(spacing: 4) {
                            Text(AppDateFormatter.dayLabel(for: date))
                                .font(.system(size: 12))
                                .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                            Text(AppDateFormatter.shortDay.string(from: date))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : Color.textSecondary)
                        }
                        .frame(width: 60)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.brandDefault : Color.bgSecondary)
                        .cornerRadius(AppRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(isSelected ? Color.brandDefault : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.selectedDateIndex = index
                            }
							Task { await viewModel.refreshAvailability() }
                        }
                    }
                }
            }

            // 时段网格
			LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
				ForEach(viewModel.availableSlots) { slot in
					let isSelected = viewModel.selectedSlotCode == slot.slotCode
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
							viewModel.selectedSlotCode = slot.slotCode
                        }
                    } label: {
                        VStack(spacing: 4) {
							Image(systemName: slot.timeRange.hasPrefix("0") ? "sun.max" : "clock")
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? Color.brandDefault : Color.accentDefault)
							Text(slot.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
							Text("\(slot.timeRange) · 余\(slot.remaining)")
                                .font(.system(size: 11))
                                .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? Color.brandDefault.opacity(0.08) : Color.bgSecondary)
                        .cornerRadius(AppRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(isSelected ? Color.brandDefault : Color.borderDefault, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
					.disabled(!slot.available)
					.opacity(slot.available ? 1 : 0.45)
                }
            }
			if viewModel.availableSlots.isEmpty {
				Text("当日暂无可预约时段")
					.font(.system(size: 13))
					.foregroundStyle(Color.textTertiary)
			}
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 20)
    }

    // MARK: - 备注
    private var remarkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("备注说明（选填）")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)

            TextField("请描述您的需求或祈福对象...", text: $viewModel.note, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
                .padding(12)
                .frame(minHeight: 80)
                .background(Color.bgSecondary)
                .cornerRadius(AppRadius.md)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 20)
    }

    // MARK: - 随喜功德
    private var meritSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("随喜功德（选填）")
                .font(.cardTitle)
                .foregroundStyle(Color.textPrimary)

            // 金额快捷按钮
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.meritTiers) { tier in
                    let isSelected = viewModel.selectedMeritTier == tier
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectedMeritTier = tier
                            viewModel.customMeritMoney = ""
                        }
                    } label: {
                        Text("¥\(Int(tier.amount))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isSelected ? Color.white : Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(isSelected ? Color.brandDefault : Color.bgSecondary)
                            .cornerRadius(AppRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(isSelected ? Color.brandDefault : Color.borderDefault, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // 自定义金额
            HStack(spacing: 6) {
                Text("¥")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
                TextField("自定义金额", text: $viewModel.customMeritMoney)
                    .keyboardType(.numberPad)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.md)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 20)
    }

    // MARK: - 价格汇总
    private var priceSummary: some View {
		let serviceFee = Int(viewModel.serviceFee)
        let merit = viewModel.finalMeritMoney
        let total = serviceFee + Int(merit)

        return VStack(spacing: 0) {
            priceRow(label: "服务费用", value: "¥\(serviceFee)", valueColor: Color.textPrimary)
            priceRow(label: "随喜功德", value: "¥\(Int(merit))", valueColor: Color.accentDefault)

            Rectangle()
                .fill(Color.borderDefault)
                .frame(height: 1)
                .padding(.vertical, 10)

            HStack {
                Text("合计")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("¥\(total)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
            }

            HStack(spacing: 2) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                Text("预约成功后24小时内可免费取消")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .padding(16)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 16)
    }

    private func priceRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 6)
    }

    // MARK: - 底部 CTA
    private var bottomCTA: some View {
		let serviceFee = Int(viewModel.serviceFee)
        let merit = viewModel.finalMeritMoney
        let total = serviceFee + Int(merit)

        return VStack(spacing: 0) {
            Button {
                guard viewModel.canSubmit else { return }
                Task { await viewModel.submit() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "creditcard")
                            .font(.system(size: 18))
                    }
                    Text("确认预约并支付 ¥\(total)")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.cinnabarDefault)
                .cornerRadius(AppRadius.lg)
                .opacity(viewModel.canSubmit ? 1.0 : 0.6)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmit)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Color.bgPrimary.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.borderDefault).frame(height: 1)
        }
    }
}

#Preview {
    NavigationStack {
        BookingView(master: Master.mockData[0])
    }
    .preferredColorScheme(.dark)
}
