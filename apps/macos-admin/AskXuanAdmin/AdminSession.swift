import AppKit
import WebKit
import Combine

@MainActor
final class AdminSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler {
    let portal: AdminPortal
    let webView: WKWebView
    @Published private(set) var loading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var failure: String?
    @Published var downloadMessage: String?
    var switchPortal: ((AdminPortal, URL) -> Void)?
    var languageChanged: (() -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var started = false
    private var activeDownloads: [ObjectIdentifier: WKDownload] = [:]
    private var destinations: [ObjectIdentifier: URL] = [:]

    init(portal: AdminPortal) {
        self.portal = portal
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: portal.storeID)
        configuration.applicationNameForUserAgent = "AskXuanAdmin/0.0.1"
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(WeakLanguageHandler(self), name: "askxuanLanguage")
        configureLanguageScript()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in Task { @MainActor in self?.loading = view.isLoading } },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in Task { @MainActor in self?.progress = view.estimatedProgress } },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in Task { @MainActor in self?.canGoBack = view.canGoBack } },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in Task { @MainActor in self?.canGoForward = view.canGoForward } }
        ]
    }
    private func configureLanguageScript() {
        let preference = L10n.store.preference.rawValue
        let source = """
        if (location.origin === \(String(data: try! JSONEncoder().encode(AdminEnvironment.origin.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), encoding: .utf8)!)) {
          try { localStorage.setItem('askxuan-language', '\(preference)'); } catch (_) {}
          window.addEventListener('askxuan:language-change', event => {
            window.webkit.messageHandlers.askxuanLanguage.postMessage(event.detail.preference);
          });
        }
        """
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }
    func updateLanguage() {
        configureLanguageScript()
        guard let url = webView.url, AdminPortal.sameOrigin(url, AdminEnvironment.origin) else { return }
        let preference = L10n.store.preference.rawValue
        webView.evaluateJavaScript("if (localStorage.getItem('askxuan-language') !== '\(preference)') { localStorage.setItem('askxuan-language', '\(preference)'); window.dispatchEvent(new StorageEvent('storage', { key: 'askxuan-language' })); }")
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let url = message.frameInfo.request.url,
              AdminPortal.sameOrigin(url, AdminEnvironment.origin),
              let raw = message.body as? String, let preference = LanguagePreference(rawValue: raw),
              preference != L10n.store.preference else { return }
        L10n.store.preference = preference
        languageChanged?()
    }
    func startIfNeeded() { if !started { started = true; home() } }
    func load(_ url: URL) {
        guard portal.owns(url, origin: AdminEnvironment.origin) else { return }
        failure = nil
        webView.load(URLRequest(url: url))
    }
    func home() { load(AdminEnvironment.origin.appendingPathComponent(portal.path)) }
    func reload() { failure = nil; if webView.url == nil { home() } else { webView.reload() } }
    func zoom(by delta: Double) { webView.pageZoom = min(2, max(0.5, webView.pageZoom + delta)) }
    func openInBrowser() { if let url = webView.url, portal.owns(url, origin: AdminEnvironment.origin) { NSWorkspace.shared.open(url) } }
    func printPage() {
        guard let window = webView.window else { return }
        let operation = webView.printOperation(with: NSPrintInfo.shared)
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { failure = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { show(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { show(error) }
    private func show(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        failure = error.localizedDescription
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failure = "页面进程已暂停，请重新载入。" }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        // Exports produced by the current first-party page may be blob URLs.
        let firstParty = AdminPortal.sameOrigin(url, AdminEnvironment.origin)
        let firstPartyBlob = url.scheme == "blob" && url.absoluteString.hasPrefix("blob:" + AdminEnvironment.origin.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/")
        if action.shouldPerformDownload && (firstParty || firstPartyBlob) { decisionHandler(.download); return }
        if action.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
        if portal.owns(url, origin: AdminEnvironment.origin) { decisionHandler(.allow); return }
        if let other = AdminPortal.matching(url, origin: AdminEnvironment.origin) {
            switchPortal?(other, url); decisionHandler(.cancel); return
        }
        if firstParty || firstPartyBlob { decisionHandler(.allow); return } // same-origin exports/PDFs
        if action.navigationType == .linkActivated && ["https", "mailto", "tel"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
            failure = "服务器返回 \(http.statusCode)，请稍后重试。"; decisionHandler(.cancel); return
        }
        let disposition = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        decisionHandler(!response.canShowMIMEType || disposition.lowercased().contains("attachment") ? .download : .allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url else { return nil }
        if portal.owns(url, origin: AdminEnvironment.origin) { load(url) }
        else if let other = AdminPortal.matching(url, origin: AdminEnvironment.origin) { switchPortal?(other, url) }
        else if AdminPortal.sameOrigin(url, AdminEnvironment.origin) || url.scheme == "blob" { webView.load(action.request) }
        else if action.navigationType == .linkActivated && url.scheme == "https" { NSWorkspace.shared.open(url) }
        return nil
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        present(panel) { result in completionHandler(result == .OK ? panel.urls : nil) }
    }
    private func present(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = webView.window { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alert(L10n.lookup(message), buttons: ["好"]) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        alert(L10n.lookup(message), buttons: ["确定", "取消"]) { completionHandler($0 == .alertFirstButtonReturn) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let field = NSTextField(string: defaultText ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert(L10n.lookup(prompt), buttons: ["确定", "取消"], accessory: field) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }
    private func alert(_ message: String, buttons: [String], accessory: NSView? = nil, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        let alert = NSAlert(); alert.messageText = L10n.lookup(portal.title); alert.informativeText = L10n.lookup(message)
        buttons.forEach { alert.addButton(withTitle: L10n.lookup($0)) }; alert.accessoryView = accessory
        if let window = webView.window { alert.beginSheetModal(for: window, completionHandler: completion) }
        else { completion(.alertSecondButtonReturn) }
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { track(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { track(download) }
    private func track(_ download: WKDownload) { activeDownloads[ObjectIdentifier(download)] = download; download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = (suggestedFilename as NSString).lastPathComponent
        present(panel) { [weak self] result in
            let url = result == .OK ? panel.url : nil
            if let url { self?.destinations[ObjectIdentifier(download)] = url }
            completionHandler(url)
        }
    }
    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        if let url = destinations.removeValue(forKey: key) { downloadMessage = "已保存：\(url.lastPathComponent)" }
        activeDownloads.removeValue(forKey: key)
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download); destinations.removeValue(forKey: key); activeDownloads.removeValue(forKey: key)
        if (error as NSError).code != NSURLErrorCancelled { downloadMessage = "下载失败：\(error.localizedDescription)" }
    }
}

@MainActor
private final class WeakLanguageHandler: NSObject, WKScriptMessageHandler {
    weak var session: AdminSession?
    init(_ session: AdminSession) { self.session = session }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        session?.userContentController(userContentController, didReceive: message)
    }
}
