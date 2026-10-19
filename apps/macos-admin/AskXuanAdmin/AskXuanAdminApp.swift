import SwiftUI
import WebKit

@main
struct AskXuanAdminApp: App {
    @StateObject private var workspace = AdminWorkspace()
    var body: some Scene {
        Window(L10n.text("问玄管理台"), id: "workspace") {
            AdminWorkspaceView(workspace: workspace)
                .appLanguage()
                .frame(minWidth: 720, minHeight: 540)
        }
        .defaultSize(width: 1380, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appSettings) {
                Menu(L10n.text("语言")) {
                    ForEach(LanguagePreference.allCases) { language in
                        Button { L10n.store.preference = language; workspace.updateLanguage() } label: {
                            Text(verbatim: (L10n.store.preference == language ? "✓ " : "") + language.title)
                        }
                    }
                }
            }
            CommandMenu(L10n.text("管理台")) {
                ForEach(Array(AdminPortal.allCases.enumerated()), id: \.element.id) { index, portal in
                    Button(L10n.lookup(portal.title)) { workspace.select(portal) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Divider()
                Button(L10n.text("后退")) { workspace.current.webView.goBack() }.keyboardShortcut("[", modifiers: .command)
                Button(L10n.text("前进")) { workspace.current.webView.goForward() }.keyboardShortcut("]", modifiers: .command)
                Button(L10n.text("重新载入")) { workspace.current.reload() }.keyboardShortcut("r", modifiers: .command)
                Button(L10n.text("返回后台首页")) { workspace.current.home() }.keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button(L10n.text("放大")) { workspace.current.zoom(by: 0.1) }.keyboardShortcut("+", modifiers: .command)
                Button(L10n.text("缩小")) { workspace.current.zoom(by: -0.1) }.keyboardShortcut("-", modifiers: .command)
                Button(L10n.text("实际大小")) { workspace.current.webView.pageZoom = 1 }.keyboardShortcut("0", modifiers: .command)
                Button(L10n.text("打印当前页…")) { workspace.current.printPage() }.keyboardShortcut("p", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AdminWorkspace: ObservableObject {
    @Published private(set) var selection: AdminPortal
    let sessions: [AdminPortal: AdminSession]
    var current: AdminSession { sessions[selection]! }
    init() {
        let initial = AdminPortal(rawValue: UserDefaults.standard.string(forKey: "selectedPortal") ?? "") ?? .platform
        selection = initial
        sessions = Dictionary(uniqueKeysWithValues: AdminPortal.allCases.map { ($0, AdminSession(portal: $0)) })
        for session in sessions.values { session.switchPortal = { [weak self] portal, url in self?.select(portal); self?.current.load(url) } }
        for session in sessions.values { session.languageChanged = { [weak self] in self?.updateLanguage() } }
        current.startIfNeeded()
    }
    func updateLanguage() {
        for session in sessions.values { session.updateLanguage() }
    }
    func select(_ portal: AdminPortal) {
        selection = portal
        UserDefaults.standard.set(portal.rawValue, forKey: "selectedPortal")
        current.startIfNeeded()
    }
}

struct AdminWorkspaceView: View {
    @ObservedObject var workspace: AdminWorkspace
    var body: some View {
        AdminPageView(session: workspace.current)
            .id(workspace.selection)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Picker(L10n.text("管理平台"), selection: Binding(get: { workspace.selection }, set: workspace.select)) {
                        ForEach(AdminPortal.allCases) { portal in Text(L10n.lookup(portal.title)).tag(portal) }
                    }.pickerStyle(.segmented).frame(width: 260).accessibilityIdentifier("portal-switcher")
                }
            }
    }
}

struct AdminPageView: View {
    @ObservedObject var session: AdminSession
    var body: some View {
        ZStack(alignment: .top) {
            AdminWebView(webView: session.webView)
            if session.loading { ProgressView(value: session.progress).progressViewStyle(.linear).accessibilityLabel(L10n.text("页面加载中")) }
            if let failure = session.failure {
                ContentUnavailableView {
                    Label(L10n.text("暂时无法打开\(session.portal.title)"), systemImage: "wifi.exclamationmark")
                } description: { Text(L10n.lookup(failure)) } actions: {
                    Button(L10n.text("重新载入")) { session.reload() }.buttonStyle(.borderedProminent)
                    Button(L10n.text("返回首页")) { session.home() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
            }
        }
        .navigationTitle(L10n.lookup(session.portal.title))
        .toolbar {
            ToolbarItemGroup {
                Button { session.webView.goBack() } label: { Label(L10n.text("后退"), systemImage: "chevron.left") }.disabled(!session.canGoBack)
                Button { session.webView.goForward() } label: { Label(L10n.text("前进"), systemImage: "chevron.right") }.disabled(!session.canGoForward)
                Button { session.reload() } label: { Label(L10n.text("重新载入"), systemImage: "arrow.clockwise") }
                Button { session.home() } label: { Label(L10n.text("首页"), systemImage: "house") }
                Button { session.openInBrowser() } label: { Label(L10n.text("在浏览器中打开"), systemImage: "safari") }
            }
        }
        .alert(L10n.text("下载"), isPresented: Binding(get: { session.downloadMessage != nil }, set: { if !$0 { session.downloadMessage = nil } })) {
            Button(L10n.text("好"), role: .cancel) { session.downloadMessage = nil }
        } message: { Text(L10n.lookup(session.downloadMessage ?? "")) }
    }
}

struct AdminWebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
