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

private struct IdentityCaptcha: Decodable {
  let id: String
  let image: String
}
private struct IdentityOptions: Decodable {
  let emailEnabled: Bool
  let smsEnabled: Bool
  let agreementVersion: String
}
private struct IdentityNotice: Decodable {
  let retryAfter: Int?
  let message: String?
  let success: Bool?
}
private struct IdentityLogin: Decodable {
  let accessToken: String
  let refreshToken: String?
  let userInfo: IdentityUser?
  let imToken: String?
}
private struct IdentityUser: Decodable {
  let userId: Int64?
  let nickname: String?
  let avatar: String?
  let mobile: String?
}

struct LoginView: View {
  @EnvironmentObject private var authStore: AuthStore
  @Environment(\.dismiss) private var dismiss
  @State private var mode = "login"
  @State private var account = ""
  @State private var email = ""
  @State private var username = ""
  @State private var password = ""
  @State private var code = ""
  @State private var human = ""
  @State private var agreed = false
  @State private var busy = false
  @State private var captcha: IdentityCaptcha?
  @State private var captchaGeneration = UUID()
  @State private var options: IdentityOptions?
  @State private var message = ""
  @State private var failure = ""
  @State private var retryAt = Date.distantPast
  @State private var legal: String?
  private let master = true
  private var proof: [String: String] { ["captchaId": captcha?.id ?? "", "captchaCode": human] }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Image("brand-logo").resizable().scaledToFit().frame(width: 52, height: 52)
          .accessibilityHidden(true)
        Text("问玄东方 · " + (master ? "师傅工作台" : "与美好相遇")).font(.subheadline).foregroundStyle(
          .secondary)
        Text(mode == "login" ? "欢迎回来" : mode == "register" ? "创建你的账户" : "找回密码").font(
          .largeTitle.bold())
        if !master && mode != "reset" {
          Picker("认证方式", selection: $mode) {
            Text("账号登录").tag("login")
            Text("邮箱注册").tag("register")
          }.pickerStyle(.segmented).disabled(busy)
        }
        Group {
          if mode == "login" {
            TextField("邮箱／用户名", text: $account).textContentType(.username)
          } else {
            TextField("邮箱", text: $email).keyboardType(.emailAddress).textContentType(.emailAddress)
          }
          if mode == "register" {
            TextField("用户名（4–32 位字母、数字或下划线）", text: $username).textContentType(.username)
          }
          SecureField(mode == "reset" ? "新密码（至少 12 个字符）" : "密码", text: $password).textContentType(
            mode == "login" ? .password : .newPassword)
          HStack {
            TextField("图片验证码", text: $human).keyboardType(.numberPad).accessibilityLabel("图片验证码")
            Button {
              Task { await reloadCaptcha() }
            } label: {
              if let raw = captcha?.image.split(separator: ",").last,
                let data = Data(base64Encoded: String(raw)), let image = UIImage(data: data)
              {
                Image(uiImage: image).resizable().scaledToFit().frame(width: 140, height: 48)
              } else {
                Text("加载验证码").frame(width: 140, height: 48)
              }
            }.accessibilityLabel("更换图片验证码").disabled(busy)
          }
          if mode != "login" {
            HStack {
              TextField("邮箱验证码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
              TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = max(0, Int(ceil(retryAt.timeIntervalSince(context.date))))
                Button(seconds > 0 ? "\(seconds) 秒后重发" : "发送验证码") { Task { await sendCode() } }
                  .disabled(
                    busy || seconds > 0 || options?.emailEnabled != true || human.count != 5
                  ).frame(minHeight: 44)
              }
            }
            Text("发送后图片会更新，提交前请输入新图片验证码。").font(.caption).foregroundStyle(.secondary)
          }
        }.textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        if mode == "register" {
          Toggle("我已阅读并同意", isOn: $agreed)
          HStack {
            Button("用户协议") { legal = "用户协议" }
            Button("隐私政策") { legal = "隐私政策" }
          }
        }
        if !failure.isEmpty {
          Text(failure).foregroundStyle(.red).accessibilityLabel("错误：" + failure)
        }
        if !message.isEmpty { Text(message).font(.callout).foregroundStyle(.secondary) }
        if mode != "login" && options?.emailEnabled == false {
          Text("邮箱验证暂未开放，请稍后重试。工作账户可联系管理员。").font(.callout)
        }
        Button {
          Task { await submit() }
        } label: {
          HStack {
            Spacer()
            if busy { ProgressView() }
            Text(busy ? "正在处理…" : mode == "login" ? "登录" : mode == "register" ? "注册并登录" : "重置密码")
            Spacer()
          }.frame(minHeight: 44)
        }.buttonStyle(.borderedProminent).disabled(
          busy || captcha == nil || (mode != "login" && options?.emailEnabled != true))
        Button(mode == "login" ? "忘记密码" : "返回登录") { mode = mode == "login" ? "reset" : "login" }
          .frame(minHeight: 44).disabled(busy)
        if master { Text("工作账户由管理员开通；未绑定验证邮箱请联系管理员。").font(.caption).foregroundStyle(.secondary) }
      }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
    }.background(Color.bgPrimary).task {
      await loadOptions()
      await reloadCaptcha()
    }
    .onChange(of: mode) { _, _ in
      password = ""
      code = ""
      failure = ""
      if mode != "login" { message = "" }
      Task { await reloadCaptcha() }
    }
    .sheet(isPresented: Binding(get: { legal != nil }, set: { if !$0 { legal = nil } })) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text(
              legal == "用户协议"
                ? "请使用本人可访问的邮箱注册并妥善保管密码。请勿冒用他人身份、滥用验证码或发布违法内容。注册账户用于保存个人资料、收藏、设计和服务记录。具体服务内容、价格及履约条件以相应页面和订单约定为准。"
                : "账户系统处理邮箱、用户名和密码哈希，用于身份验证、账户找回和保护账户。密码不以明文保存。验证码限时有效、验证后失效；发送频次和登录尝试记录用于防止滥用。注册成功时记录同意的协议版本。"
            )
          }.padding()
        }.navigationTitle(legal ?? "账户说明").toolbar { Button("完成") { legal = nil } }
      }
    }
  }
  private func loadOptions() async {
    do {
      options = try await APIClient.shared.request(.accountAuth(path: "options", body: nil))
    } catch { failure = error.localizedDescription }
  }
  private func reloadCaptcha() async {
    let generation = UUID()
    captchaGeneration = generation
    human = ""
    captcha = nil
    do {
      let result: IdentityCaptcha = try await APIClient.shared.request(
        .accountAuth(path: "captcha", body: nil))
      guard captchaGeneration == generation else { return }
      captcha = result
    } catch { if captchaGeneration == generation { failure = "验证码加载失败，请重试" } }
  }
  private func sendCode() async {
    guard !busy else { return }
    busy = true
    failure = ""
    defer { busy = false }
    do {
      var body = proof
      body.merge([
        "email": email, "purpose": mode == "register" ? "register" : "reset",
        "domain": master ? "admin" : "user",
      ]) { _, new in new }
      let result: IdentityNotice = try await APIClient.shared.request(
        .accountAuth(path: "email/code", body: body))
      retryAt = Date().addingTimeInterval(Double(result.retryAfter ?? 60))
      message = result.message ?? "请检查邮箱"
    } catch { failure = error.localizedDescription }
    await reloadCaptcha()
  }
  private func submit() async {
    guard !busy else { return }
    failure = ""
    message = ""
    guard human.count == 5 else {
      failure = "请输入五位图片验证码"
      return
    }
    if mode == "register" && !agreed {
      failure = "请阅读并同意用户协议和隐私政策"
      return
    }
    if mode != "login" && !(12...128).contains(password.count) {
      failure = "密码需为 12–128 个字符"
      return
    }
    busy = true
    defer { busy = false }
    do {
      var body = proof
      body.merge([
        "account": account, "password": password, "email": email, "username": username.lowercased(),
        "code": code, "domain": master ? "admin" : "user",
        "agreementVersion": options?.agreementVersion ?? "",
      ]) { _, new in new }
      if mode == "reset" {
        let _: IdentityNotice = try await APIClient.shared.request(
          .accountAuth(path: "password/reset", body: body))
        mode = "login"
        password = ""
        message = "密码已更新，请重新登录"
      } else {
        let result: IdentityLogin = try await APIClient.shared.request(
          .accountAuth(
            path: mode == "register" ? "email/register" : master ? "admin/login" : "login",
            body: body))
        try await accept(result)
        dismiss()
      }
    } catch { failure = error.localizedDescription }
    await reloadCaptcha()
  }
  private func accept(_ result: IdentityLogin) async throws {
    guard let claims = JWTDecoder.payload(of: result.accessToken),
      let roles = claims["roles"] as? [String], roles.contains("master"),
      let masterID = claims["masterId"] as? Int, masterID > 0
    else {
      let _: IdentityNotice? = try? await APIClient.shared.request(
        .accountAuth(path: "logout", body: ["accessToken": result.accessToken]))
      throw NSError(
        domain: "AccountAccess", code: 1, userInfo: [NSLocalizedDescriptionKey: "请使用已开通的师傅账户登录"])
    }
    authStore.didLogin(
      token: result.accessToken, refreshToken: result.refreshToken, imToken: result.imToken)
    if let im = result.imToken, let id = authStore.masterId {
      OpenIMManager.shared.login(userID: "m_" + id, token: im) { _, _ in }
    }
    await NativeChatNotifications.shared.refresh()
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
        .font(AppTypography.caption)
        .foregroundStyle(.textSecondary)
      HStack(spacing: 8) {
        if let icon {
          Image(systemName: icon)
            .font(AppTypography.body)
            .foregroundStyle(.textTertiary)
        }
        TextField(placeholder, text: $text)
          .font(AppTypography.body)
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
        .font(AppTypography.caption)
        .foregroundStyle(.textSecondary)
      HStack(spacing: 8) {
        if let icon {
          Image(systemName: icon)
            .font(AppTypography.body)
            .foregroundStyle(.textTertiary)
        }
        Group {
          if isSecure {
            SecureField(placeholder, text: $text)
          } else {
            TextField(placeholder, text: $text)
          }
        }
        .font(AppTypography.body)
        .foregroundStyle(.textPrimary)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)

        Button {
          isSecure = !isSecure
        } label: {
          Image(systemName: isSecure ? "eye.slash" : "eye")
            .font(AppTypography.body)
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
