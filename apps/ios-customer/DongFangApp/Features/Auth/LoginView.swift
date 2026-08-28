//
//  LoginView.swift
//  DongFangApp
//
//  C 端认证页：手机号登录与免真实短信验证注册。
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    private enum AuthMode: String, CaseIterable, Identifiable {
        case login = "登录"
        case register = "注册"

        var id: String { rawValue }
    }

    @State private var mode: AuthMode = .login
    @State private var phone: String = ""
    @State private var code: String = ""
    @State private var nickname: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var countdown: Int = 0
    @State private var countdownTimer: Timer?

    private var isPhoneValid: Bool {
        phone.count == 11 && phone.hasPrefix("1")
    }

    private var canSubmit: Bool {
        switch mode {
        case .login:
            return isPhoneValid && code.count >= 4 && !isLoading
        case .register:
            return isPhoneValid && nickname.count <= 32 && !isLoading
        }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    logoSection
                    modePicker
                    formSection
                    submitButton
                    hintSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, 60)
            }
        }
        .alert(mode == .login ? "登录失败" : "注册失败", isPresented: .init(
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

    private var modePicker: some View {
        Picker("认证方式", selection: $mode) {
            ForEach(AuthMode.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            errorMessage = nil
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

                Image("brand-logo")
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
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
                    .onChange(of: phone) { _, newValue in
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

            if mode == .login {
                codeField
            } else {
                nicknameField
            }
        }
    }

    private var codeField: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 20)

            TextField("请输入验证码", text: $code)
                .keyboardType(.numberPad)
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
                .onChange(of: code) { _, newValue in
                    if newValue.count > 6 { code = String(newValue.prefix(6)) }
                }

            Spacer()
            Button { sendCode() } label: {
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
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    private var nicknameField: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 20)
            TextField("昵称（选填）", text: $nickname)
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
                .onChange(of: nickname) { _, newValue in
                    if newValue.count > 32 { nickname = String(newValue.prefix(32)) }
                }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 14)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 登录按钮
    private var submitButton: some View {
        DFPrimaryButton(title: mode.rawValue,
                        icon: mode == .login ? "arrow.right.circle.fill" : "person.badge.plus",
                        isEnabled: canSubmit,
                        isLoading: isLoading) {
            Task {
                if mode == .login {
                    await performLogin()
                } else {
                    await performRegistration()
                }
            }
        }
    }

    // MARK: - 提示
    private var hintSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(mode == .login ? "演示登录验证码固定为 1234" : "注册不发送或校验真实短信验证码")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)

            Text(mode == .login ? "没有账号？切换到注册" : "注册成功后将自动登录")
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

        let loginResult = await tryLogin()
        switch loginResult {
        case .success:
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        case .userNotFound:
            await MainActor.run {
                isLoading = false
                errorMessage = "该手机号尚未注册，请切换到注册"
            }
        case .failure(let msg):
            await MainActor.run {
                isLoading = false
                errorMessage = msg
            }
        }
    }

    private func performRegistration() async {
        isLoading = true
        errorMessage = nil
        switch await tryRegister() {
        case .success:
            switch await tryLogin(codeOverride: "1234") {
            case .success:
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            case .userNotFound:
                finishWithError("账号已创建，但自动登录失败，请重试")
            case .failure(let message):
                finishWithError("账号已创建，自动登录失败：\(message)")
            }
        case .failure(let message):
            finishWithError(message)
        }
    }

    @MainActor
    private func finishWithError(_ message: String) {
        isLoading = false
        errorMessage = message
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

    private func tryLogin(codeOverride: String? = nil) async -> LoginOutcome {
        do {
            let resp: LoginResponse = try await APIClient.shared.request(
                .authLogin(LoginRequest(phone: phone, code: codeOverride ?? code, account: nil, password: nil))
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
                .authRegister(RegisterRequest(
                    mobile: phone,
                    code: nil,
                    nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nickname
                ))
            )
            return .success
        } catch let APIError.serverError(_, message) {
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
