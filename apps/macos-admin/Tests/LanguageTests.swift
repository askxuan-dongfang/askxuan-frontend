import Testing
import Foundation
@testable import AskXuanAdmin

struct LanguageTests {
    @Test(arguments: [(["zh-CN"], "zh-Hans"), (["zh-TW"], "zh-Hant"), (["zh-HK"], "zh-Hant"), (["zh-MO"], "zh-Hant"), (["zh-Hans-TW"], "zh-Hans"), (["zh_Hant_CN"], "zh-Hant"), (["en", "zh-TW"], "zh-Hant"), (["en"], "zh-Hans")])
    func systemLanguage(_ item: ([String], String)) {
        #expect(LanguagePreference.system.resolved(languages: item.0) == item.1)
    }
    @Test func explicitLanguageWins() {
        #expect(LanguagePreference.traditional.resolved(languages: ["zh-CN"]) == "zh-Hant")
        #expect(LanguagePreference.simplified.resolved(languages: ["zh-TW"]) == "zh-Hans")
    }
}
