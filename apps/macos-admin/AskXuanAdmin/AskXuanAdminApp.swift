import SwiftUI
import WebKit

@main
struct AskXuanAdminApp: App {
    @StateObject private var workspace = AdminWorkspace()
    var body: some Scene {
        Window("问玄管理台", id: "workspace") {
            AdminWorkspaceView(workspace: workspace)
                .frame(minWidth: 720, minHeight: 540)
        }
        .defaultSize(width: 1380, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("管理台") {
                ForEach(Array(AdminPortal.allCases.enumerated()), id: \.element.id) { index, portal in
                    Button(portal.title) { workspace.select(portal) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Divider()
                Button("后退") { workspace.current.webView.goBack() }.keyboardShortcut("[", modifiers: .command)
                Button("前进") { workspace.current.webView.goForward() }.keyboardShortcut("]", modifiers: .command)
                Button("重新载入") { workspace.current.reload() }.keyboardShortcut("r", modifiers: .command)
                Button("返回后台首页") { workspace.current.home() }.keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button("放大") { workspace.current.zoom(by: 0.1) }.keyboardShortcut("+", modifiers: .command)
                Button("缩小") { workspace.current.zoom(by: -0.1) }.keyboardShortcut("-", modifiers: .command)
                Button("实际大小") { workspace.current.webView.pageZoom = 1 }.keyboardShortcut("0", modifiers: .command)
                Button("打印当前页…") { workspace.current.printPage() }.keyboardShortcut("p", modifiers: .command)
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
        current.startIfNeeded()
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
                    Picker("管理平台", selection: Binding(get: { workspace.selection }, set: workspace.select)) {
                        ForEach(AdminPortal.allCases) { portal in Text(portal.title).tag(portal) }
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
            if session.loading { ProgressView(value: session.progress).progressViewStyle(.linear).accessibilityLabel("页面加载中") }
            if let failure = session.failure {
                ContentUnavailableView {
                    Label("暂时无法打开\(session.portal.title)", systemImage: "wifi.exclamationmark")
                } description: { Text(failure) } actions: {
                    Button("重新载入") { session.reload() }.buttonStyle(.borderedProminent)
                    Button("返回首页") { session.home() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.background)
            }
        }
        .navigationTitle(session.portal.title)
        .toolbar {
            ToolbarItemGroup {
                Button { session.webView.goBack() } label: { Label("后退", systemImage: "chevron.left") }.disabled(!session.canGoBack)
                Button { session.webView.goForward() } label: { Label("前进", systemImage: "chevron.right") }.disabled(!session.canGoForward)
                Button { session.reload() } label: { Label("重新载入", systemImage: "arrow.clockwise") }
                Button { session.home() } label: { Label("首页", systemImage: "house") }
                Button { session.openInBrowser() } label: { Label("在浏览器中打开", systemImage: "safari") }
            }
        }
        .alert("下载", isPresented: Binding(get: { session.downloadMessage != nil }, set: { if !$0 { session.downloadMessage = nil } })) {
            Button("好", role: .cancel) { session.downloadMessage = nil }
        } message: { Text(session.downloadMessage ?? "") }
    }
}

struct AdminWebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
