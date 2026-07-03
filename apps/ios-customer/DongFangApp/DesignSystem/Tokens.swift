// ================================================================
//  问玄东方App - Design Tokens (Auto-generated + 项目扩展)
//  Source: packages/design-tokens/tokens.json
//  Do not edit manually; run `npm run gen:ios` to regenerate.
// ================================================================

import SwiftUI

// MARK: - Colors
extension Color {
    static let bgPrimary = Color(hex: "1C1210")
    static let bgSecondary = Color(hex: "2A1E1A")
    static let bgTertiary = Color(hex: "3A2C25")
    static let bgElevated = Color(hex: "44342C")
    static let brandDefault = Color(hex: "C45A3C")
    static let brandLight = Color(hex: "D4735A")
    static let brandDark = Color(hex: "A64830")
    static let accentDefault = Color(hex: "C8A96E")
    static let accentLight = Color(hex: "D4BC8A")
    static let accentDark = Color(hex: "A88A50")
    static let cinnabarDefault = Color(hex: "B5453A")
    static let cinnabarLight = Color(hex: "CC5A4F")
    static let textPrimary = Color(hex: "F0E6DA")
    static let textSecondary = Color(hex: "C5B097")
    static let textTertiary = Color(hex: "8A7A6A")
    static let borderDefault = Color(.sRGB, red: 200/255.0, green: 169/255.0, blue: 110/255.0, opacity: 0.15)
    static let borderStrong = Color(.sRGB, red: 200/255.0, green: 169/255.0, blue: 110/255.0, opacity: 0.3)
    static let borderDivider = Color(.sRGB, red: 200/255.0, green: 169/255.0, blue: 110/255.0, opacity: 0.08)
    static let stateSuccess = Color(hex: "5B8C5A")
    static let stateWarning = Color(hex: "D4A843")
    static let stateError = Color(hex: "C45A3C")

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
    static var borderDefault: Color { .borderDefault }
    static var borderStrong: Color { .borderStrong }
    static var borderDivider: Color { .borderDivider }
    static var stateSuccess: Color { .stateSuccess }
    static var stateWarning: Color { .stateWarning }
    static var stateError: Color { .stateError }
}

// MARK: - Fonts
enum AppFont {
    static let serif = ["Noto Serif SC", "STSong", "SimSun"]
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

// MARK: - Font 便捷扩展（项目内统一文字层级）
extension Font {
    /// 品牌标题（首页顶部「问玄东方」）
    static let brandTitle = Font.custom(AppFont.serif[0], size: 22).weight(.bold)
    /// 卡片标题
    static let cardTitle = Font.system(size: 15, weight: .semibold)
    /// 区块标题
    static let sectionTitle = Font.custom(AppFont.serif[0], size: 17).weight(.semibold)
}
