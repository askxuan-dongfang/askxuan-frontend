//
//  PricingView.swift
//  MasterApp
//
//  定价管理（页面 11）。
//  复用法师资料接口：GET admin/masters/profile，PUT admin/masters/profile（pricing 字段）。
//  提供常用功德金档位快捷设置 + 自定义说明文本。
//

import SwiftUI

@MainActor
final class PricingViewModel: ObservableObject {
    @Published var pricingText: String = ""
    @Published var selectedTiers: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var message: String? = nil

    private let apiClient: APIClient
    private var originalPricing: String = ""

    /// 预设功德金档位
    let presetTiers: [String] = ["¥99", "¥199", "¥399", "¥699", "¥999", "¥1999"]

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        message = nil
        do {
            let profile: MasterProfile = try await apiClient.request(.masterProfile)
            originalPricing = profile.pricing
            pricingText = profile.pricing
            // 解析已有档位
            selectedTiers = Set(presetTiers.filter { profile.pricing.contains($0) })
        } catch let error as APIError {
            message = error.errorDescription
        } catch {
            message = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    func toggleTier(_ tier: String) {
        if selectedTiers.contains(tier) {
            selectedTiers.remove(tier)
        } else {
            selectedTiers.insert(tier)
        }
        rebuildPricingText()
    }

    /// 根据选中档位重建说明文本
    private func rebuildPricingText() {
        let tiers = presetTiers.filter { selectedTiers.contains($0) }
        if tiers.isEmpty {
            return  // 保留自定义文本
        }
        let customPart = pricingText
            .components(separatedBy: CharacterSet(charactersIn: "¥"))
            .filter { !$0.isEmpty && !presetTiers.contains("¥" + $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        pricingText = "功德金档位：" + tiers.joined(separator: " / ")
            + (customPart.isEmpty ? "" : "\n说明：" + customPart.joined())
    }

    var canSave: Bool {
        !isSaving && pricingText != originalPricing
    }

    func save() async {
        isSaving = true
        message = nil
        do {
            let req = MasterProfileUpdateRequest(pricing: pricingText)
            let _: MasterProfile = try await apiClient.request(.masterProfileUpdate(req))
            originalPricing = pricingText
            message = "定价已更新"
        } catch let error as APIError {
            message = error.errorDescription
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
        isSaving = false
    }
}

struct PricingView: View {
    @StateObject private var viewModel = PricingViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 当前定价说明
                pricingEditor

                // 档位选择
                tierSelector

                // 保存按钮
                PrimaryButton(title: "保存定价", icon: "checkmark.circle.fill",
                              isEnabled: viewModel.canSave,
                              isLoading: viewModel.isSaving) {
                    Task { await viewModel.save() }
                }

                if let msg = viewModel.message {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.contains("已更新") ? .stateSuccess : .stateError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                tipsCard
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.bgPrimary)
        .navigationTitle("定价管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
    }

    private var pricingEditor: some View {
        MasterCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.accentDefault)
                    Text("定价说明")
                        .font(.cardTitle)
                        .foregroundStyle(.textPrimary)
                }
                TextEditor(text: $viewModel.pricingText)
                    .font(.body)
                    .foregroundStyle(.textPrimary)
                    .frame(minHeight: 100)
                    .padding(AppSpacing.sm)
                    .background(Color.bgTertiary)
                    .cornerRadius(AppRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.borderDefault, lineWidth: 1)
                    )
            }
        }
    }

    private var tierSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("常用功德金档位")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: AppSpacing.md) {
                ForEach(viewModel.presetTiers, id: \.self) { tier in
                    let selected = viewModel.selectedTiers.contains(tier)
                    Button {
                        viewModel.toggleTier(tier)
                    } label: {
                        Text(tier)
                            .font(.system(size: 15, weight: selected ? .bold : .regular))
                            .foregroundStyle(selected ? .white : .textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                selected
                                ? AnyShapeStyle(LinearGradient(colors: [.brandDefault, .brandLight],
                                                               startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.bgSecondary)
                            )
                            .cornerRadius(AppRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(selected ? Color.clear : Color.borderDefault, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tipsCard: some View {
        MasterCard(padding: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.accentDefault)
                Text("定价说明将展示给信众，建议明确各档位对应的服务内容。档位调整不影响已下单的预约。")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PricingView()
    }
    .preferredColorScheme(.dark)
}
