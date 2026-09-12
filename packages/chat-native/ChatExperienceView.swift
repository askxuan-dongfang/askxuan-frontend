import SwiftUI
import WebKit
import CryptoKit
import UniformTypeIdentifiers

/// One maintained conversation UI across H5 and the native apps. Authentication
/// is bootstrapped only into the first-party main frame, never into a URL.
struct ChatExperienceView: View {
    let conversationID: String
    let role: String
    let accountID: String
    let userID: String
    let token: String
    let nickname: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var failure: String?
    @State private var loading = true
    @State private var reload = UUID()
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            ConversationWebView(conversationID: conversationID, role: role, accountID: accountID,
                                userID: userID, token: token, nickname: nickname,
                                theme: colorScheme == .dark ? "dark" : "light",
                                onClose: { dismiss() }, onFailure: { failure = $0; loading = false },
                                onReady: { loading = false })
                .id(reload)
            if loading { ProgressView("正在打开对话…").tint(Color.accentDefault).foregroundStyle(Color.textSecondary) }
            if let failure {
                VStack(spacing: 18) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 30))
                    Text(failure).font(.subheadline).multilineTextAlignment(.center)
                    Button("重新加载") { self.failure = nil; loading = true; reload = UUID() }
                        .buttonStyle(.borderedProminent).tint(Color.brandDefault)
                    Button("返回") { dismiss() }
                }.padding(30).foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bgPrimary)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(.keyboard)
        .onAppear {NativeChatNotifications.shared.openConversation=conversationID}
        .onDisappear {if NativeChatNotifications.shared.openConversation==conversationID{NativeChatNotifications.shared.openConversation=nil}}
    }
}

private struct ConversationWebView: UIViewRepresentable {
    let conversationID: String; let role: String; let accountID: String; let userID: String
    let token: String; let nickname: String
    let theme: String
    let onClose: () -> Void; let onFailure: (String) -> Void; let onReady: () -> Void
    static var origin: URL {
        // The deployed web entry shares the API origin. A build may override it
        // for local UI tests without changing production credentials.
        if let value = Bundle.main.object(forInfoDictionaryKey: "ASKXUAN_WEB_BASE_URL") as? String,
           let url = URL(string: value) { return url }
        var parts = URLComponents(url: AppConfig.baseURL, resolvingAgainstBaseURL: false)!
        parts.path = ""; parts.query = nil; parts.fragment = nil
        return parts.url!
    }
    /// Keep the embedded conversation in the host appearance without reloading it.
    /// The same origin guard as authentication limits writes to our own main frame.
    private var themeScript: String {
        let quotedOrigin = String(decoding: try! JSONSerialization.data(withJSONObject: [Self.origin.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]), as: UTF8.self)
        let resolved = theme == "dark" ? "dark" : "light"
        return """
        if (window.location.origin === \(quotedOrigin)[0]) {
            const theme = '\(resolved)';
            try { localStorage.setItem('askxuan-theme', theme); } catch (_) {}
            if (document.documentElement) {
                document.documentElement.dataset.theme = theme;
                document.documentElement.style.colorScheme = theme;
            }
            window.dispatchEvent(new StorageEvent('storage', { key: 'askxuan-theme', newValue: theme }));
        }
        """
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Website storage is scoped to a signed-in account, including drafts and
        // retry IDs. Customer and master apps have separate app containers.
        let digest = SHA256.hash(data: Data("chat:\(role):\(accountID)".utf8))
        let bytes = Array(digest.prefix(16))
        let identifier = UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: identifier)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "chatNative")
        let state: [String: Any] = ["token": token, "role": role, "userId": Int(userID) ?? 0,
                                    "masterId": role == "master" ? (Int(accountID) ?? 0) : 0,
                                    "displayName": nickname]
        let data = try! JSONSerialization.data(withJSONObject: ["state": state, "version": 0])
        let auth = String(decoding: data, as: UTF8.self)
        let quotedToken = String(decoding: try! JSONSerialization.data(withJSONObject: [token]), as: UTF8.self)
        let quotedOrigin = String(decoding: try! JSONSerialization.data(withJSONObject: [Self.origin.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]), as: UTF8.self)
        let script = "if(window.location.origin===\(quotedOrigin)[0]){localStorage.setItem('h5_token',\(quotedToken)[0]);localStorage.setItem('h5-auth',JSON.stringify(\(auth)));window.__ASKXUAN_NATIVE_CHAT__=true;}"
        context.coordinator.bootstrapScript = script
        context.coordinator.appliedTheme = theme
        config.userContentController.addUserScript(WKUserScript(source: script + "\n" + themeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator; web.uiDelegate = context.coordinator
        web.overrideUserInterfaceStyle = theme == "dark" ? .dark : .light
        web.isOpaque = false; web.backgroundColor = AppPalette.bgPrimary
        web.scrollView.backgroundColor = .clear; web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.web = web
        let prefix = role == "master" ? "m" : "c"
        var url = Self.origin.appendingPathComponent(prefix).appendingPathComponent("chats").appendingPathComponent(conversationID)
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "embedded", value: "1")]; url = parts.url!
        web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.appliedTheme != theme else { return }
        context.coordinator.appliedTheme = theme
        uiView.overrideUserInterfaceStyle = theme == "dark" ? .dark : .light
        // This WKWebView owns a single combined bootstrap script. Keep subsequent
        // navigations in sync as well as the currently loaded conversation.
        let controller = uiView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: context.coordinator.bootstrapScript + "\n" + themeScript,
                                              injectionTime: .atDocumentStart, forMainFrameOnly: true))
        uiView.evaluateJavaScript(themeScript, completionHandler: nil)
    }
    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.evaluateJavaScript("window.dispatchEvent(new Event('chat:native-close'))", completionHandler: nil)
        web.stopLoading(); web.configuration.userContentController.removeScriptMessageHandler(forName: "chatNative")
        web.navigationDelegate = nil; web.uiDelegate = nil
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: ConversationWebView; weak var web: WKWebView?
        var bootstrapScript = ""
        var appliedTheme = ""
        init(_ parent: ConversationWebView) { self.parent = parent }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(parent.themeScript, completionHandler: nil)
            parent.onReady()
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.onFailure("聊天页面暂时无法打开，请检查网络后重试。") }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.onFailure("连接中断，请重新加载对话。") }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { parent.onFailure("聊天页面已暂停，重新加载即可恢复草稿。") }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.targetFrame?.isMainFrame != false else { decisionHandler(.cancel); return }
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            guard url.scheme == ConversationWebView.origin.scheme, url.host == ConversationWebView.origin.host, url.port == ConversationWebView.origin.port else {
                decisionHandler(.cancel); return
            }
            let root = parent.role == "master" ? "/m/chats" : "/c/chats"
            if url.path == root || url.path == root + "/" { decisionHandler(.cancel); parent.onClose(); return }
            guard url.path == root + "/" + parent.conversationID else {
                decisionHandler(.cancel)
                if url.path.hasSuffix("/login") { parent.onFailure("登录已失效，请返回并重新登录。") }
                return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            guard frame.isMainFrame, origin.host == ConversationWebView.origin.host else { decisionHandler(.deny); return }
            decisionHandler(.prompt)
        }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.host == ConversationWebView.origin.host,
                  let body = message.body as? [String: String], let action = body["action"] else { return }
            if action == "close" { parent.onClose() }
            if action == "download", let id = body["attachmentId"], UUID(uuidString: id) != nil {
                let name = (body["name"] ?? "附件") as NSString
                let safeName = String(name.lastPathComponent.prefix(180))
                Task { await download(attachmentID: id, name: safeName) }
            }
        }
        private func download(attachmentID: String, name: String) async {
            let url = AppConfig.baseURL.appendingPathComponent("chats").appendingPathComponent(parent.conversationID).appendingPathComponent("attachments").appendingPathComponent(attachmentID)
            var request = URLRequest(url: url); request.setValue("Bearer \(parent.token)", forHTTPHeaderField: "Authorization")
            do {
                let (data,response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200, response.mimeType != "application/json", data.count <= 20 * 1024 * 1024 else { throw URLError(.badServerResponse) }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appendingPathComponent(name.isEmpty ? "附件" : name)
                try data.write(to: file, options: .completeFileProtection)
                let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
                sheet.completionWithItemsHandler = { _,_,_,_ in try? FileManager.default.removeItem(at: folder) }
                guard let scene = web?.window?.windowScene, let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
                var top = root; while let presented = top.presentedViewController { top = presented }
                sheet.popoverPresentationController?.sourceView = web
                top.present(sheet, animated: true)
            } catch { parent.onFailure("附件下载失败，请返回对话后重试。") }
        }
    }
}
