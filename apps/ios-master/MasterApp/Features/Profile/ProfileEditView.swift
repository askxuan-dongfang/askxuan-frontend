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
    @Published var specialtiesText: String = ""
    @Published var avatarURL: String = ""
    @Published var pricing: String = ""
    @Published var isSaving: Bool = false
    @Published var message: String? = nil

    private let apiClient: APIClient
    private let original: MasterProfile?

    init(profile: MasterProfile?, apiClient: APIClient = .shared) {
        self.original = profile
        self.apiClient = apiClient
        self.bio = profile?.bio ?? ""
        self.specialtiesText = (profile?.specialties ?? []).joined(separator: "、")
        self.avatarURL = profile?.avatar ?? ""
        self.pricing = profile?.pricing ?? ""
    }

    func save() async {
        isSaving = true
        message = nil
        do {
            let specialties = specialtiesText
                .components(separatedBy: CharacterSet(charactersIn: "、,，"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let req = MasterProfileUpdateRequest(
                bio: bio,
                specialties: specialties,
                avatar: avatarURL.isEmpty ? nil : avatarURL,
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
    @StateObject private var viewModel: ProfileEditViewModel
    @Environment(\.dismiss) private var dismiss

    init(profile: MasterProfile?) {
        self.profile = profile
        _viewModel = StateObject(wrappedValue: ProfileEditViewModel(profile: profile))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 头像
                MasterCard(padding: AppSpacing.lg) {
                    VStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.bgTertiary)
                                .frame(width: 80, height: 80)
                            if let url = URL(string: viewModel.avatarURL), !viewModel.avatarURL.isEmpty {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.accentDefault)
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.accentDefault)
                            }
                        }
                        DFTextField(title: "头像 URL", text: $viewModel.avatarURL,
                                    placeholder: "https://...", icon: "photo")
                    }
                }

                // 简介
                MasterCard(padding: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 14))
                                .foregroundStyle(.accentDefault)
                            Text("个人简介")
                                .font(.cardTitle)
                                .foregroundStyle(.textPrimary)
                        }
                        TextEditor(text: $viewModel.bio)
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

                // 专长
                MasterCard(padding: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 14))
                                .foregroundStyle(.accentDefault)
                            Text("专长（用顿号分隔）")
                                .font(.cardTitle)
                                .foregroundStyle(.textPrimary)
                        }
                        TextField("如：开光、化太岁、超度", text: $viewModel.specialtiesText, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(.textPrimary)
                            .padding(AppSpacing.sm)
                            .background(Color.bgTertiary)
                            .cornerRadius(AppRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(Color.borderDefault, lineWidth: 1)
                            )
                            .lineLimit(1...3)
                    }
                }

                // 定价
                MasterCard(padding: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(.system(size: 14))
                                .foregroundStyle(.accentDefault)
                            Text("定价说明")
                                .font(.cardTitle)
                                .foregroundStyle(.textPrimary)
                        }
                        TextEditor(text: $viewModel.pricing)
                            .font(.body)
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
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(msg.contains("已保存") ? .stateSuccess : .stateError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                PrimaryButton(title: "保存资料", icon: "checkmark.circle.fill",
                              isLoading: viewModel.isSaving) {
                    Task { await viewModel.save() }
                }
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.bgPrimary)
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        ProfileEditView(profile: nil)
    }
    .preferredColorScheme(.dark)
}
