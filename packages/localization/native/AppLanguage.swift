import Foundation
import Observation
import SwiftUI

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system, simplified = "zh-Hans", traditional = "zh-Hant"
    static let storageKey = "askxuan.language"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return L10n.lookup("跟随系统")
        case .simplified: return "简体中文"
        case .traditional: return "繁體中文"
        }
    }
    func resolved(languages: [String]) -> String {
        guard self == .system else { return rawValue }
        let parts = (languages.first(where: { $0.lowercased() == "zh" || $0.lowercased().hasPrefix("zh-") || $0.lowercased().hasPrefix("zh_") }) ?? "").replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-")
        guard parts.first == "zh" else { return "zh-Hans" }
        if parts.contains("hant") { return "zh-Hant" }
        if parts.contains("hans") { return "zh-Hans" }
        return parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) ? "zh-Hant" : "zh-Hans"
    }
}

/// Observation tracks reads from every localized view without rebuilding its navigation or drafts.
@Observable
final class AppLanguageStore {
    static let shared = AppLanguageStore()
    var preference: LanguagePreference {
        didSet { UserDefaults.standard.set(preference.rawValue, forKey: LanguagePreference.storageKey) }
    }
    private var systemLanguages = Locale.preferredLanguages
    var resolved: String { preference.resolved(languages: systemLanguages) }
    var locale: Locale { Locale(identifier: resolved) }
    init() {
        preference = LanguagePreference(rawValue: UserDefaults.standard.string(forKey: LanguagePreference.storageKey) ?? "") ?? .system
    }
    func refreshSystemLanguage() { systemLanguages = Locale.preferredLanguages }
}

enum L10n {
    static let store = AppLanguageStore.shared
    private static let traditional: [String: String] = {
        guard let url = Bundle.main.url(forResource: "zh-Hant", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return result
    }()

    /// Exact UI catalog lookup; arbitrary service data and user content are never transliterated.
    static func lookup<T>(_ value: T) -> T {
        guard store.resolved == "zh-Hant", let source = value as? String,
              let target = traditional[source] else { return value }
        return (target as? T) ?? value
    }

    static func text(_ message: Message) -> String { message.rendered }
    struct Message: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
        let rendered: String
        init(stringLiteral value: String) { rendered = L10n.lookup(value) }
        init(stringInterpolation: StringInterpolation) { rendered = stringInterpolation.rendered }
        struct StringInterpolation: StringInterpolationProtocol {
            var rendered = ""
            init(literalCapacity: Int, interpolationCount: Int) { rendered.reserveCapacity(literalCapacity) }
            mutating func appendLiteral(_ value: String) { rendered += L10n.lookup(value) }
            mutating func appendInterpolation<T>(_ value: T) { rendered += String(describing: value) }
            mutating func appendInterpolation<T: CVarArg>(_ value: T, specifier: String) { rendered += String(format: specifier, value) }
        }
    }
}

struct LanguageSettingsView: View {
    var body: some View {
        @Bindable var language = L10n.store
        Form {
            Picker(L10n.text("语言"), selection: $language.preference) {
                ForEach(LanguagePreference.allCases) { choice in
                    Text(verbatim: choice.title).tag(choice)
                }
            }
            .pickerStyle(.inline)
            Text(L10n.text("跟随系统时自动选择简体或繁体中文，其他系统语言使用简体中文。"))
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle(L10n.text("语言"))
    }
}

struct AppLanguageModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content
            .environment(\.locale, L10n.store.locale)
            .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in L10n.store.refreshSystemLanguage() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { L10n.store.refreshSystemLanguage() } }
    }
}

extension View {
    func appLanguage() -> some View { modifier(AppLanguageModifier()) }
}
