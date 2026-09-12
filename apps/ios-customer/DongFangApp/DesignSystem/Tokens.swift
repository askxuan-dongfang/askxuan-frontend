// ================================================================
//  问玄东方App - Design Tokens (Auto-generated + 项目扩展)
//  Source: packages/design-tokens/tokens.json
//  Do not edit manually; run `npm run gen:ios` to regenerate.
// ================================================================

import SwiftUI
import UIKit

// MARK: - Colors
enum AppPalette {
    static let bgPrimary = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 28/255.0, green: 18/255.0, blue: 16/255.0, alpha: 1) : UIColor(red: 246/255.0, green: 243/255.0, blue: 236/255.0, alpha: 1)
    }
    static let bgSecondary = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 42/255.0, green: 30/255.0, blue: 26/255.0, alpha: 1) : UIColor(red: 255/255.0, green: 253/255.0, blue: 248/255.0, alpha: 1)
    }
    static let bgTertiary = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 58/255.0, green: 44/255.0, blue: 37/255.0, alpha: 1) : UIColor(red: 239/255.0, green: 237/255.0, blue: 227/255.0, alpha: 1)
    }
    static let bgElevated = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 68/255.0, green: 52/255.0, blue: 44/255.0, alpha: 1) : UIColor(red: 231/255.0, green: 231/255.0, blue: 218/255.0, alpha: 1)
    }
    static let brandDefault = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 196/255.0, green: 90/255.0, blue: 60/255.0, alpha: 1) : UIColor(red: 40/255.0, green: 77/255.0, blue: 67/255.0, alpha: 1)
    }
    static let brandLight = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 212/255.0, green: 115/255.0, blue: 90/255.0, alpha: 1) : UIColor(red: 66/255.0, green: 106/255.0, blue: 89/255.0, alpha: 1)
    }
    static let brandDark = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 166/255.0, green: 72/255.0, blue: 48/255.0, alpha: 1) : UIColor(red: 30/255.0, green: 60/255.0, blue: 52/255.0, alpha: 1)
    }
    static let accentDefault = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 200/255.0, green: 169/255.0, blue: 110/255.0, alpha: 1) : UIColor(red: 132/255.0, green: 103/255.0, blue: 61/255.0, alpha: 1)
    }
    static let accentLight = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 212/255.0, green: 188/255.0, blue: 138/255.0, alpha: 1) : UIColor(red: 137/255.0, green: 107/255.0, blue: 64/255.0, alpha: 1)
    }
    static let accentDark = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 168/255.0, green: 138/255.0, blue: 80/255.0, alpha: 1) : UIColor(red: 114/255.0, green: 86/255.0, blue: 47/255.0, alpha: 1)
    }
    static let cinnabarDefault = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 181/255.0, green: 69/255.0, blue: 58/255.0, alpha: 1) : UIColor(red: 160/255.0, green: 75/255.0, blue: 58/255.0, alpha: 1)
    }
    static let cinnabarLight = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 204/255.0, green: 90/255.0, blue: 79/255.0, alpha: 1) : UIColor(red: 181/255.0, green: 97/255.0, blue: 77/255.0, alpha: 1)
    }
    static let textPrimary = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 240/255.0, green: 230/255.0, blue: 218/255.0, alpha: 1) : UIColor(red: 37/255.0, green: 62/255.0, blue: 54/255.0, alpha: 1)
    }
    static let textSecondary = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 197/255.0, green: 176/255.0, blue: 151/255.0, alpha: 1) : UIColor(red: 102/255.0, green: 115/255.0, blue: 108/255.0, alpha: 1)
    }
    static let textTertiary = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 138/255.0, green: 122/255.0, blue: 106/255.0, alpha: 1) : UIColor(red: 116/255.0, green: 128/255.0, blue: 120/255.0, alpha: 1)
    }
    static let textOnBrand = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1) : UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1)
    }
    static let textOnAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 28/255.0, green: 18/255.0, blue: 16/255.0, alpha: 1) : UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 1)
    }
    static let borderDefault = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 200/255.0, green: 169/255.0, blue: 110/255.0, alpha: 0.15) : UIColor(red: 40/255.0, green: 77/255.0, blue: 67/255.0, alpha: 0.14)
    }
    static let borderStrong = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 200/255.0, green: 169/255.0, blue: 110/255.0, alpha: 0.3) : UIColor(red: 40/255.0, green: 77/255.0, blue: 67/255.0, alpha: 0.3)
    }
    static let borderDivider = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 200/255.0, green: 169/255.0, blue: 110/255.0, alpha: 0.08) : UIColor(red: 40/255.0, green: 77/255.0, blue: 67/255.0, alpha: 0.08)
    }
    static let stateSuccess = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 91/255.0, green: 140/255.0, blue: 90/255.0, alpha: 1) : UIColor(red: 53/255.0, green: 112/255.0, blue: 82/255.0, alpha: 1)
    }
    static let stateWarning = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 212/255.0, green: 168/255.0, blue: 67/255.0, alpha: 1) : UIColor(red: 144/255.0, green: 109/255.0, blue: 55/255.0, alpha: 1)
    }
    static let stateError = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 196/255.0, green: 90/255.0, blue: 60/255.0, alpha: 1) : UIColor(red: 160/255.0, green: 75/255.0, blue: 58/255.0, alpha: 1)
    }
    static let stateInfo = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 143/255.0, green: 174/255.0, blue: 203/255.0, alpha: 1) : UIColor(red: 66/255.0, green: 106/255.0, blue: 137/255.0, alpha: 1)
    }
}

extension Color {
    static let bgPrimary = Color(uiColor: AppPalette.bgPrimary)
    static let bgSecondary = Color(uiColor: AppPalette.bgSecondary)
    static let bgTertiary = Color(uiColor: AppPalette.bgTertiary)
    static let bgElevated = Color(uiColor: AppPalette.bgElevated)
    static let brandDefault = Color(uiColor: AppPalette.brandDefault)
    static let brandLight = Color(uiColor: AppPalette.brandLight)
    static let brandDark = Color(uiColor: AppPalette.brandDark)
    static let accentDefault = Color(uiColor: AppPalette.accentDefault)
    static let accentLight = Color(uiColor: AppPalette.accentLight)
    static let accentDark = Color(uiColor: AppPalette.accentDark)
    static let cinnabarDefault = Color(uiColor: AppPalette.cinnabarDefault)
    static let cinnabarLight = Color(uiColor: AppPalette.cinnabarLight)
    static let textPrimary = Color(uiColor: AppPalette.textPrimary)
    static let textSecondary = Color(uiColor: AppPalette.textSecondary)
    static let textTertiary = Color(uiColor: AppPalette.textTertiary)
    static let textOnBrand = Color(uiColor: AppPalette.textOnBrand)
    static let textOnAccent = Color(uiColor: AppPalette.textOnAccent)
    static let borderDefault = Color(uiColor: AppPalette.borderDefault)
    static let borderStrong = Color(uiColor: AppPalette.borderStrong)
    static let borderDivider = Color(uiColor: AppPalette.borderDivider)
    static let stateSuccess = Color(uiColor: AppPalette.stateSuccess)
    static let stateWarning = Color(uiColor: AppPalette.stateWarning)
    static let stateError = Color(uiColor: AppPalette.stateError)
    static let stateInfo = Color(uiColor: AppPalette.stateInfo)

    /// Initialize a Color from a hex string (3 or 6 digits, leading # optional).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255,
                             (int >> 8) * 17,
                             (int >> 4 & 0xF) * 17,
                             (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ShapeStyle 便捷扩展（支持 .foregroundStyle(.textPrimary) 简写）
extension ShapeStyle where Self == Color {
    static var bgPrimary: Color { .bgPrimary }
    static var bgSecondary: Color { .bgSecondary }
    static var bgTertiary: Color { .bgTertiary }
    static var bgElevated: Color { .bgElevated }
    static var brandDefault: Color { .brandDefault }
    static var brandLight: Color { .brandLight }
    static var brandDark: Color { .brandDark }
    static var accentDefault: Color { .accentDefault }
    static var accentLight: Color { .accentLight }
    static var accentDark: Color { .accentDark }
    static var cinnabarDefault: Color { .cinnabarDefault }
    static var cinnabarLight: Color { .cinnabarLight }
    static var textPrimary: Color { .textPrimary }
    static var textSecondary: Color { .textSecondary }
    static var textTertiary: Color { .textTertiary }
    static var textOnBrand: Color { .textOnBrand }
    static var textOnAccent: Color { .textOnAccent }
    static var stateInfo: Color { .stateInfo }
    static var borderDefault: Color { .borderDefault }
    static var borderStrong: Color { .borderStrong }
    static var borderDivider: Color { .borderDivider }
    static var stateSuccess: Color { .stateSuccess }
    static var stateWarning: Color { .stateWarning }
    static var stateError: Color { .stateError }
}

// MARK: - Fonts
enum AppFont {
    static let serif = [AppTypography.serifName ?? "TimesNewRomanPSMT"]
    static let sans = ["Noto Sans SC", "PingFang SC", "Microsoft YaHei"]
}

// MARK: - Corner Radius
enum AppRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

// MARK: - Spacing
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let navTop: CGFloat = 44
    static let navBottom: CGFloat = 60
}

// MARK: - Product typography (shared roles with design-tokens/tokens.json)
// Resolve installed font names explicitly: Font.custom does not accept a fallback array.
enum AppTypography {
    static let serifName = ["AskXuanSerif-Semibold", "NotoSerifSC-SemiBold", "SongtiSC-Regular", "STSongti-SC-Regular"]
        .first { UIFont(name: $0, size: 17) != nil }

    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if let name = serifName { return .custom(name, size: size, relativeTo: .headline).weight(weight) }
        return .system(size: size, weight: weight, design: .serif)
    }
    static func numeric(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("HelveticaNeue", size: size, relativeTo: .body).weight(weight).monospacedDigit()
    }
    static let body = Font.custom("HelveticaNeue", size: 14, relativeTo: .body)
    static let caption = Font.custom("HelveticaNeue", size: 12, relativeTo: .caption)
    static let navigation = title(17)
    static let hero = title(28)
    static let page = title(24)
    static let section = title(20)
    static let card = title(18)
    static let control = Font.custom("HelveticaNeue", size: 15, relativeTo: .body).weight(.semibold)
}

extension Font {
    static let brandTitle = AppTypography.page
    static let cardTitle = AppTypography.card
    static let sectionTitle = AppTypography.section
}

// MARK: - Appearance preference
/// A device-local preference shared by the root scene and appearance settings.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    static let storageKey = "askxuan.appearance"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func configureAppearance() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = AppPalette.bgPrimary.withAlphaComponent(0.95)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = AppPalette.textTertiary
            item.normal.titleTextAttributes = [.foregroundColor: AppPalette.textTertiary]
            item.selected.iconColor = AppPalette.accentDefault
            item.selected.titleTextAttributes = [.foregroundColor: AppPalette.accentDefault]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = AppPalette.accentDefault
        UITabBar.appearance().unselectedItemTintColor = AppPalette.textTertiary

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = AppPalette.bgPrimary
        navigation.titleTextAttributes = [
            .foregroundColor: AppPalette.accentDefault,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigation.largeTitleTextAttributes = [.foregroundColor: AppPalette.textPrimary]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = AppPalette.accentDefault
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(AppTheme.storageKey) private var themeValue = AppTheme.system.rawValue
    private var selection: AppTheme { AppTheme(rawValue: themeValue) ?? .system }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 0) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            themeValue = theme.rawValue
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: theme.symbol)
                                    .frame(width: 24)
                                    .foregroundStyle(Color.accentDefault)
                                Text(theme.title).foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandDefault)
                                    .opacity(selection == theme ? 1 : 0)
                            }
                            .font(AppTypography.body)
                            .padding(16)
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == theme ? [.isSelected] : [])
                        if theme != AppTheme.allCases.last {
                            Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 52)
                        }
                    }
                }
                .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
                Text("选择跟随系统后，外观将随设备设置自动切换。")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(16)
        }
        .background(Color.bgPrimary)
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
