//
//  LoginView.swift
//  MasterApp
//
//  法师登录页（页面 2）。
//  使用管理台账号 + 密码登录（role=master），POST auth/admin/login。
//  登录成功后 JWT 存 Keychain，法师身份从 JWT Claims 解析。
//

import SwiftUI

/// 登录响应（auth-service LoginResp）
struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int64?
    let userInfo: LoginUserInfo?
    let imToken: String?
}

struct LoginUserInfo: Decodable {
    let userId: Int64?
    let nickname: String?
    let avatar: String?
    let mobile: String?
}

struct RefreshResponse: Decodable {
    let accessToken: String
    let expiresIn: Int64?
}

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var account: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var canSubmit: Bool {
        !account.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isLoading
    }

    func login() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        do {
            let req = AdminLoginRequest(account: account.trimmingCharacters(in: .whitespaces),
                                        password: password)
            let resp: LoginResponse = try await apiClient.request(.adminLogin(req))
            // 保存 Token 并解析 JWT Claims（masterId 等），同时持久化 imToken 以便 app 重启后恢复 OpenIM 登录
            AuthStore.shared.didLogin(token: resp.accessToken, refreshToken: resp.refreshToken, imToken: resp.imToken)
            // 登录成功后，用 imToken 登录 OpenIM（法师端 userID 约定为 "m_" + masterId）
            if let imToken = resp.imToken, !imToken.isEmpty,
               let masterID = AuthStore.shared.masterId, !masterID.isEmpty {
                let openimUserID = "m_" + masterID
                OpenIMManager.shared.login(userID: openimUserID, token: imToken) { success, error in
                    if success {
                        print("✅ OpenIM 登录成功")
                    } else {
                        print("❌ OpenIM 登录失败: \(error?.localizedDescription ?? "")")
                    }
                }
            }
            await registerMockDeviceToken()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "登录失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    private func registerMockDeviceToken() async {
        guard let masterId = AuthStore.shared.masterId else { return }
        let req = DeviceTokenRegisterRequest(
            userId: masterId,
            clientType: AppConfig.clientType,
            platform: "ios",
            deviceToken: "mock-apns-token-master-\(masterId)",
            bundleId: Bundle.main.bundleIdentifier ?? "com.askxuan.master",
            appVersion: AppConfig.clientVersion
        )
        let _: DeviceTokenResponse? = try? await apiClient.request(.registerDeviceToken(req))
    }
}

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // 顶部品牌区
                VStack(spacing: AppSpacing.sm) {
                    Image("brand-logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.accentDefault.opacity(0.35), lineWidth: 1)
                        )
                        .padding(.bottom, AppSpacing.xs)
                    Text("问玄东方")
                        .font(.brandTitle)
                        .foregroundStyle(.textPrimary)
                    Text("法师工作台")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.accentDefault)
                }
                .padding(.top, AppSpacing.xl * 2)

                // 表单卡片
                MasterCard(padding: AppSpacing.lg) {
                    VStack(spacing: AppSpacing.lg) {
                        DFTextField(title: "账号", text: $viewModel.account,
                                    placeholder: "请输入法师账号", icon: "person")
                        DFSecureField(title: "密码", text: $viewModel.password,
                                      placeholder: "请输入密码", icon: "lock")

                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text(errorMessage)
                                    .font(.caption)
                            }
                            .foregroundStyle(.stateError)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(title: "登录", icon: "arrow.right.circle.fill",
                                      isEnabled: viewModel.canSubmit, isLoading: viewModel.isLoading) {
                            Task { await viewModel.login() }
                        }
                    }
                }

                Text("使用管理台账号登录（role=master）")
                    .font(.micro)
                    .foregroundStyle(.textTertiary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.pageHorizontal)
        }
        .background(Color.bgPrimary)
        .navigationTitle("法师登录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - 文本输入辅助组件

struct DFTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.textSecondary)
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.textTertiary)
                }
                TextField(placeholder, text: $text)
                    .font(.body)
                    .foregroundStyle(.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.bgTertiary)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
        }
    }
}

struct DFSecureField: View {
    let title: String
    @Binding var text: String
    var placeholder: String
    var icon: String? = nil
    @State private var isSecure: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.textSecondary)
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.textTertiary)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.body)
                .foregroundStyle(.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button {
                    isSecure = !isSecure
                } label: {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.bgTertiary)
            .cornerRadius(AppRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthStore.shared)
    }
    .preferredColorScheme(.dark)
}
