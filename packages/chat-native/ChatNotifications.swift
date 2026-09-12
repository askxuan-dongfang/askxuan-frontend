import SwiftUI
import UserNotifications
import UIKit

struct ChatNotificationIdentity { let role: String; let accountID: String; let userID: String; let token: String; let nickname: String }
struct ChatNotificationDestination: Identifiable { let id: String }

@MainActor final class NativeChatNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NativeChatNotifications()
    @Published var destination: ChatNotificationDestination?
    @Published private(set) var enabled = false
    @Published private(set) var chatUnread = 0
    @Published private(set) var denied = false
    @Published private(set) var error: String?
    var identity: () -> ChatNotificationIdentity? = { nil }
    private var deviceToken: String?
    var openConversation: String?
    private var seenCall: String?
    private var pendingConversation: String?
    private var registeredIdentity = ""
    static var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
    func configure(_ identity: @escaping () -> ChatNotificationIdentity?) { self.identity = identity; UNUserNotificationCenter.current().delegate = self }
    func requestPermission() async {
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound])
            if allowed { UIApplication.shared.registerForRemoteNotifications() }
            await refresh()
        } catch { self.error = "暂时无法开启消息提醒，请稍后重试。" }
    }
    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        enabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        denied = settings.authorizationStatus == .denied
        if enabled, identity() != nil { UIApplication.shared.registerForRemoteNotifications(); await register() }
        if let pendingConversation, identity() != nil { self.pendingConversation = nil; destination = .init(id: pendingConversation) }
    }
    func received(token: Data) { deviceToken = token.map { String(format: "%02x", $0) }.joined(); Task { await register() } }
    func registrationFailed() { error = "系统消息提醒暂未连接，请稍后重试。" }
    private func register() async {
        guard let who = identity(), let deviceToken else { return }
        let key = "\(who.role):\(who.accountID):\(deviceToken)"
        guard registeredIdentity != key else { return }
        do {
            let payload: [String: String] = ["userId":who.userID,"clientType":who.role,"platform":"ios","deviceToken":deviceToken,
                "bundleId":Bundle.main.bundleIdentifier ?? "","appVersion":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.0","environment":Self.environment]
            try await deviceRequest(method:"POST",who:who,payload:payload)
            if identity()?.accountID == who.accountID { registeredIdentity = key; error = nil }
        } catch {
            if AuthStore.shared.isLoggedIn, !(error is CancellationError), (error as? APIError)?.isCancellation != true {
                self.error = "消息提醒连接失败，点击重试。"
            }
        }
    }
    func monitor() async {
        while !Task.isCancelled {
            if identity() != nil,UIApplication.shared.applicationState == .active {
                struct Count:Decodable{let count:Int}
                if let result:Count=try? await ChatNativeAPI.get("chats/unread"){chatUnread=result.count}
                struct Incoming:Decodable{struct Call:Decodable{let id:String;let conversationId:String};let call:Call?}
                if let result:Incoming=try? await ChatNativeAPI.get("chats/incoming-call"),let call=result.call,seenCall != call.id {
                    seenCall=call.id
                    if openConversation != call.conversationId {destination = .init(id:call.conversationId)}
                }
            }else if identity()==nil{chatUnread=0}
            try? await Task.sleep(for:.seconds(4))
        }
    }
    func unbind() {
        registeredIdentity = ""; destination = nil; openConversation = nil
        pendingConversation = nil; seenCall = nil; chatUnread = 0; error = nil
        guard let who = identity(), let deviceToken else { return }
        Task { try? await deviceRequest(method:"DELETE",who:who,payload:["userId":who.userID,"deviceToken":deviceToken]) }
    }
    private func deviceRequest(method:String,who:ChatNotificationIdentity,payload:[String:String]) async throws {
        var request = URLRequest(url:AppConfig.baseURL.appendingPathComponent("messages/device-token"))
        request.httpMethod = method; request.setValue("Bearer \(who.token)",forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody = try JSONSerialization.data(withJSONObject:payload)
        let data: Data
        let response: URLResponse
        if method == "DELETE" {
            // Best-effort cleanup with the departing account's captured token. Never refresh or log out a newer login.
            (data,response) = try await URLSession.shared.data(for:request)
        } else {
            let context = AuthStore.shared.requestSession
            guard context.accessToken == who.token else { throw CancellationError() }
            (data,response) = try await APIClient.shared.sessionData(for:request, context:context)
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let body = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              (body["code"] as? Int ?? 0) == 0 else { throw URLError(.badServerResponse) }
    }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void) { completionHandler([.banner,.sound]) }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping ()->Void) {
        let id = response.notification.request.content.userInfo["conversationId"] as? String
        Task { @MainActor in
            if let id, !id.isEmpty, id.count <= 64 {
                if self.identity() != nil { self.destination = .init(id:id) } else { self.pendingConversation = id }
            }
            completionHandler()
        }
    }
}
final class ChatAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application:UIApplication,didRegisterForRemoteNotificationsWithDeviceToken deviceToken:Data) { Task { @MainActor in NativeChatNotifications.shared.received(token:deviceToken) } }
    func application(_ application:UIApplication,didFailToRegisterForRemoteNotificationsWithError error:Error) { Task { @MainActor in NativeChatNotifications.shared.registrationFailed() } }
}
struct ChatNotificationPrompt: View {
    @ObservedObject private var notifications = NativeChatNotifications.shared
    var body: some View {
        if !notifications.enabled || notifications.error != nil {
            Button {
                if notifications.denied,let url=URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                else { Task { await notifications.requestPermission() } }
            } label: {
                HStack(spacing:9) { Image(systemName:"bell.badge");Text(notifications.error ?? (notifications.denied ? "前往设置，开启新消息提醒" : "开启新消息提醒"));Spacer();Image(systemName:"chevron.right").font(.caption2) }
                .font(.system(size:12)).foregroundStyle(Color.accentDefault)
                .padding(14).background(Color.bgSecondary,in:RoundedRectangle(cornerRadius:13))
            }.buttonStyle(.plain).padding(.horizontal,18).padding(.vertical,8).task { await notifications.refresh() }
        }
    }
}
