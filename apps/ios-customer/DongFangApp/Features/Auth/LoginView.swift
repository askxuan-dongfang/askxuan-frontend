//
//  LoginView.swift
//  DongFangApp
//
//  C 端登录页：品牌 Logo + 手机号 + 验证码 + 登录按钮。
//  后端 mock 阶段验证码固定 1234，点击"获取验证码"直接填入。
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var phone: String = ""
    @State private var code: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var countdown: Int = 0
    @State private var countdownTimer: Timer?

    private var isPhoneValid: Bool {
        phone.count == 11 && phone.hasPrefix("1")
    }

    private var canLogin: Bool {
        isPhoneValid && code.count >= 4 && !isLoading
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    logoSection
                    formSection
                    loginButton
                    hintSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, 60)
            }
        }
        .alert("登录失败", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            countdownTimer?.invalidate()
        }
    }

    // MARK: - 品牌 Logo
    private var logoSection: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brandDefault.opacity(0.3), Color.accentDefault.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().stroke(Color.accentDefault.opacity(0.3), lineWidth: 1.5))

                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentDefault)
            }
            .frame(width: 88, height: 88)

            Text("问玄东方")
                .font(.custom(AppFont.serif[0], size: 26).weight(.bold))
                .foregroundStyle(Color.accentDefault)

            Text("结缘佛法  祈福纳祥")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - 表单
    private var formSection: some View {
        VStack(spacing: AppSpacing.md) {
            // 手机号
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 20)

                TextField("请输入手机号", text: $phone)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textPrimary)
                    .onChange(of: phone) { newValue in
                        if newValue.count > 11 {
                            phone = String(newValue.prefix(11))
                        }
                    }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 14)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(isPhoneValid ? Color.accentDefault.opacity(0.3) : Color.borderDefault, lineWidth: 1)
            )

            // 验证码
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 20)

                TextField("请输入验证码", text: $code)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textPrimary)
                    .onChange(of: code) { newValue in
                        if newValue.count > 6 {
                            code = String(newValue.prefix(6))
                        }
                    }

                Spacer()

                Button {
                    sendCode()
                } label: {
                    Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(countdown > 0 ? Color.textTertiary : Color.accentDefault)
                }
                .buttonStyle(.plain)
                .disabled(countdown > 0 || !isPhoneValid)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 14)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
        }
    }

    // MARK: - 登录按钮
    private var loginButton: some View {
        DFPrimaryButton(title: "登录", icon: "arrow.right.circle.fill",
                        isEnabled: canLogin,
                        isLoading: isLoading) {
            Task { await performLogin() }
        }
    }

    // MARK: - 提示
    private var hintSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("MVP 测试提示：验证码固定为 1234")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)

            Text("未注册手机号将自动创建账号")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary.opacity(0.7))
        }
    }

    // MARK: - 操作
    private func sendCode() {
        guard isPhoneValid else { return }
        // 后端无 send-code 接口，mock 阶段直接填入 1234
        code = "1234"
        startCountdown()
    }

    private func startCountdown() {
        countdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                countdownTimer?.invalidate()
            }
        }
    }

    private func performLogin() async {
        isLoading = true
        errorMessage = nil

        // 先尝试登录，若用户不存在则自动注册后再登录
        var loginSucceeded = false
        let loginResult = await tryLogin()
        switch loginResult {
        case .success:
            loginSucceeded = true
        case .userNotFound:
            // 自动注册
            let regResult = await tryRegister()
            switch regResult {
            case .success:
                // 注册成功后再次登录
                let retryResult = await tryLogin()
                if case .success = retryResult {
                    loginSucceeded = true
                } else if case .failure(let msg) = retryResult {
                    errorMessage = msg
                }
            case .failure(let msg):
                errorMessage = msg
            }
        case .failure(let msg):
            errorMessage = msg
        }

        await MainActor.run {
            isLoading = false
            // 登录成功后自动 dismiss 回到来源页（TabView 会因 isLoggedIn 变化刷新）
            if loginSucceeded {
                dismiss()
            }
        }
    }

    private enum LoginOutcome {
        case success
        case userNotFound
        case failure(String)
    }

    private enum RegisterOutcome {
        case success
        case failure(String)
    }

    private func tryLogin() async -> LoginOutcome {
        do {
            let resp: LoginResponse = try await APIClient.shared.request(
                .authLogin(LoginRequest(phone: phone, code: code, account: nil, password: nil))
            )
            let userId = resp.userInfo?.userId.map(String.init) ?? AppConfig.defaultUserId
            await MainActor.run {
                authStore.didLogin(
                    accessToken: resp.accessToken,
                    refreshToken: resp.refreshToken,
                    userId: userId,
                    nickname: resp.userInfo?.nickname,
                    avatar: resp.userInfo?.avatar,
                    mobile: resp.userInfo?.mobile ?? phone,
                    imToken: resp.imToken
                )
            }
            // 登录成功后，用 imToken 登录 OpenIM（C 端 userID 约定为 "u_" + userId）
            if let imToken = resp.imToken, !imToken.isEmpty {
                let openimUserID = "u_" + userId
                OpenIMManager.shared.login(userID: openimUserID, token: imToken) { success, error in
                    if success {
                        print("✅ OpenIM 登录成功")
                    } else {
                        print("❌ OpenIM 登录失败: \(error?.localizedDescription ?? "")")
                    }
                }
            }
            await registerMockDeviceToken(userId: userId)
            return .success
        } catch let APIError.serverError(code, message) {
            // 用户不存在（后端 code 通常为 40401 或 message 含"不存在"）
            if message.contains("不存在") || code == 40401 {
                return .userNotFound
            }
            return .failure(message)
        } catch APIError.networkError {
            return .failure("网络连接失败，请检查网络后重试")
        } catch {
            return .failure("登录失败：\(error.localizedDescription)")
        }
    }

    private func tryRegister() async -> RegisterOutcome {
        do {
            let _: RegisterResponse = try await APIClient.shared.request(
                .authRegister(RegisterRequest(mobile: phone, code: code, nickname: "善信\(phone.suffix(4))"))
            )
            return .success
        } catch let APIError.serverError(_, message) {
            // 已注册也视为成功
            if message.contains("已") || message.contains("存在") {
                return .success
            }
            return .failure("注册失败：\(message)")
        } catch APIError.networkError {
            return .failure("网络连接失败，请检查网络后重试")
        } catch {
            return .failure("注册失败：\(error.localizedDescription)")
        }
    }

    private func registerMockDeviceToken(userId: String) async {
        let req = DeviceTokenRegisterRequest(
            userId: userId,
            clientType: AppConfig.clientType,
            platform: "ios",
            deviceToken: "mock-apns-token-customer-\(userId)",
            bundleId: Bundle.main.bundleIdentifier ?? "com.askxuan.customer",
            appVersion: AppConfig.clientVersion
        )
        let _: DeviceTokenResponse? = try? await APIClient.shared.request(.registerDeviceToken(req))
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthStore.shared)
        .preferredColorScheme(.dark)
}
