//
//  ProfileEditView.swift
//  MasterApp
//
//  资料编辑（页面 13）。
//  PUT admin/masters/profile（bio / specialties / avatar / pricing）。
//

import SwiftUI

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var bio: String = ""
    @Published var specialties: [String] = []
    let avatarDraft: AvatarDraftState
    @Published var pricing: String = ""
    @Published var isSaving: Bool = false
    @Published var message: String? = nil

    private let apiClient: APIClient
    private let original: MasterProfile?

    init(profile: MasterProfile?, apiClient: APIClient = .shared) {
        self.original = profile
        self.apiClient = apiClient
        self.bio = profile?.bio ?? ""
        self.specialties = profile?.specialties ?? []
        self.avatarDraft = AvatarDraftState(url: profile?.avatar ?? "")
        self.pricing = profile?.pricing ?? ""
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        message = nil
        do {
            let avatarURL = try await avatarDraft.resolve()
            let req = MasterProfileUpdateRequest(
                bio: bio,
                specialties: specialties,
                avatar: avatarURL,
                pricing: pricing
            )
            let _: MasterProfile = try await apiClient.request(.masterProfileUpdate(req))
            message = "资料已保存"
        } catch let error as APIError {
            message = error.errorDescription
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
        isSaving = false
    }
}

struct ProfileEditView: View {
    let profile: MasterProfile?
    let editAvatar: Bool
    @StateObject private var viewModel: ProfileEditViewModel
    @Environment(\.dismiss) private var dismiss
    // 特性 3：iOS 26+ 富文本编辑 —— AttributedString 支持加粗/斜体/下划线
    @State private var bioAttributed: AttributedString = AttributedString()

    init(profile: MasterProfile?, editAvatar: Bool = false) {
        self.profile = profile
        self.editAvatar = editAvatar
        _viewModel = StateObject(wrappedValue: ProfileEditViewModel(profile: profile))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                MasterCard(padding: AppSpacing.lg) {
                    AvatarPhotoField(draft: viewModel.avatarDraft, disabled: viewModel.isSaving, initialOpen: editAvatar)
                }
                if let profile {
                    MasterCard(padding: AppSpacing.md) {
                        VStack(spacing: 12) {
                            LabeledContent(L10n.text("法号"), value: profile.dharmaName)
                            LabeledContent(L10n.text("职位"), value: profile.position)
                            Text(L10n.text("身份资料由认证记录维护")).font(.caption).foregroundStyle(Color.textSecondary)
                        }.foregroundStyle(Color.textPrimary)
                    }
                }

                // 简介
                MasterCard(padding: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft")
                                .font(AppTypography.body)
                                .foregroundStyle(.accentDefault)
                            Text(L10n.text("个人简介"))
                                .font(.cardTitle)
                                .foregroundStyle(.textPrimary)
                        }
                        // 特性 3：iOS 26+ 富文本编辑 + 格式化工具栏
                        if #available(iOS 26.0, *) {
                            RichTextToolbar(attributedText: $bioAttributed)
                            TextEditor(text: $bioAttributed)
                                .font(AppTypography.body)
                                .foregroundStyle(.textPrimary)
                                .frame(minHeight: 100)
                                .padding(AppSpacing.sm)
                                .background(Color.bgTertiary)
                                .cornerRadius(AppRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(Color.borderDefault, lineWidth: 1)
                                )
                        } else {
                            TextEditor(text: $viewModel.bio)
                                .font(AppTypography.body)
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

                MasterCard(padding: AppSpacing.md) {
                    ProfileSpecialtyPicker(selection: $viewModel.specialties)
                }

                // 定价
                MasterCard(padding: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(AppTypography.body)
                                .foregroundStyle(.accentDefault)
                            Text(L10n.text("定价说明"))
                                .font(.cardTitle)
                                .foregroundStyle(.textPrimary)
                        }
                        TextEditor(text: $viewModel.pricing)
                            .font(AppTypography.body)
                            .foregroundStyle(.textPrimary)
                            .frame(minHeight: 80)
                            .padding(AppSpacing.sm)
                            .background(Color.bgTertiary)
                            .cornerRadius(AppRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(Color.borderDefault, lineWidth: 1)
                            )
                    }
                }

                if let msg = viewModel.message {
                    Text(L10n.lookup(msg))
                        .font(AppTypography.caption)
                        .foregroundStyle(msg.contains("已保存") ? .stateSuccess : .stateError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                PrimaryButton(title: L10n.text("保存资料"), icon: "checkmark.circle.fill",
                              isLoading: viewModel.isSaving) {
                    // 特性 3：保存前将 AttributedString 转回 String
                    if #available(iOS 26.0, *) {
                        viewModel.bio = String(bioAttributed.characters)
                    }
                    Task { await viewModel.save() }
                }
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.bgPrimary)
        .navigationTitle(L10n.text("编辑资料"))
        .navigationBarTitleDisplayMode(.inline)

        .interactiveDismissDisabled(viewModel.isSaving)
        .navigationBarBackButtonHidden(viewModel.isSaving)
        .onAppear {
            // 特性 3：初始化 AttributedString
            if #available(iOS 26.0, *) {
                bioAttributed = AttributedString(viewModel.bio)
            }
        }
    }
}

// MARK: - 特性 3：富文本格式化工具栏（iOS 26+）
// 对整个文本应用加粗 / 斜体 / 下划线 / 清除格式
@available(iOS 26.0, *)
struct RichTextToolbar: View {
    @Binding var attributedText: AttributedString

    var body: some View {
        HStack(spacing: 12) {
            formatButton(icon: "bold", label: L10n.text("加粗")) {
                var container = AttributeContainer()
                container.font = .body.bold()
                attributedText.mergeAttributes(container)
            }
            formatButton(icon: "italic", label: L10n.text("斜体")) {
                var container = AttributeContainer()
                container.font = .body.italic()
                attributedText.mergeAttributes(container)
            }
            formatButton(icon: "underline", label: L10n.text("下划线")) {
                var container = AttributeContainer()
                container.underlineStyle = .single
                attributedText.mergeAttributes(container)
            }
            Spacer()
            formatButton(icon: "xmark.circle", label: L10n.text("清除")) {
                attributedText = AttributedString(String(attributedText.characters))
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background(Color.bgTertiary.opacity(0.5))
        .cornerRadius(AppRadius.sm)
    }

    private func formatButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(AppTypography.caption.weight(.semibold))
                Text(L10n.lookup(label))
                    .font(AppTypography.micro)
            }
            .foregroundStyle(Color.accentDefault)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentDefault.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(CardPressButtonStyle())
    }
}

#Preview {
    NavigationStack {
        ProfileEditView(profile: nil)
    }
    .preferredColorScheme(.dark)
}
