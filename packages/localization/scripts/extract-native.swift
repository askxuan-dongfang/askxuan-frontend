import Foundation
import SwiftSyntax
import SwiftParser
let root = CommandLine.arguments[1]
let folders = ["apps/ios-customer/DongFangApp", "apps/ios-master/MasterApp", "apps/macos-admin/AskXuanAdmin", "packages/profile-native", "packages/service-journey-native", "packages/chat-native", "packages/localization/native"]
var phrases = Set<String>()
final class Extractor: SyntaxVisitor {
    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        for segment in node.segments {
            guard let source = segment.as(StringSegmentSyntax.self)?.content.text,
                  source.range(of: "[\\u3400-\\u9fff]", options: .regularExpression) != nil else { continue }
            phrases.insert(source.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\t", with: "\t"))
        }
        return .visitChildren
    }
}
for folder in folders {
    let base = root + "/" + folder
    guard let paths = FileManager.default.enumerator(atPath: base) else { continue }
    for case let path as String in paths where path.hasSuffix(".swift") {
        let source = try String(contentsOfFile: base + "/" + path, encoding: .utf8)
        Extractor(viewMode: .sourceAccurate).walk(Parser.parse(source: source))
    }
}
FileHandle.standardOutput.write(try JSONEncoder().encode(phrases.sorted()))
