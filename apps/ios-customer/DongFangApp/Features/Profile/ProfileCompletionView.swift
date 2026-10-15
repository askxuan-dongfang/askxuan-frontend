import SwiftUI

struct ProfileCompletionView: View {
    let onDone: () -> Void
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var avatar = AvatarDraftState()
    @State private var nickname = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("注册成功").font(.caption).foregroundStyle(Color.accentDefault)
                Text("认识一下你").font(.title2.weight(.semibold)).foregroundStyle(Color.textPrimary)
                Text("选一张头像，填上喜欢的称呼。也可以稍后在“我的”中修改。")
                    .font(.callout).foregroundStyle(Color.textSecondary)
                AvatarPhotoField(draft: avatar, disabled: busy)
                TextField("昵称", text: $nickname).textContentType(.nickname).textFieldStyle(.roundedBorder).disabled(busy)
                if let error { Text(error).font(.callout).foregroundStyle(Color.stateError) }
                Button(busy ? "正在保存…" : error == nil ? "保存并进入" : "重试保存") { Task { await save() } }
                    .buttonStyle(.borderedProminent).tint(Color.brandDefault).frame(minHeight: 44)
                    .disabled(busy || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("稍后设置", action: onDone).frame(minHeight: 44).tint(Color.accentDefault).disabled(busy)
            }.padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }.background(Color.bgPrimary).navigationBarBackButtonHidden(busy)
        .task { nickname = authStore.nickname ?? "" }
    }
    private func save() async {
        guard !busy else { return }; busy = true; error = nil
        defer { busy = false }
        do {
            let url = try await avatar.resolve()
            let request = UpdateProfileRequest(nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines), avatar: url, gender: nil, birthday: nil, region: nil, bio: nil)
            let profile: UserProfile = try await APIClient.shared.request(.updateProfile(request))
            authStore.updateCachedProfile(nickname: profile.nickname, avatar: profile.avatar, mobile: profile.mobile)
            onDone()
        } catch { self.error = error.localizedDescription }
    }
}
