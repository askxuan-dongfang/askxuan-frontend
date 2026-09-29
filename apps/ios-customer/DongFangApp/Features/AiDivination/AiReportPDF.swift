import SwiftUI
import UIKit

/// Explicit user export only. Uses the unlocked API snapshot; never fetches hidden content.
@MainActor enum AiReportPDF {
    static func export(_ report: AiReport) throws -> URL {
        guard report.unlocked, report.status == "ready" else { throw CocoaError(.fileReadNoPermission) }
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("问玄报告-\(report.id).pdf")
        var renderFailed = false
        try renderer.writePDF(to: url) { context in
            var cursor: CGFloat = 40
            var pageNumber = 0
            func page() {
                context.beginPage(); UIColor.white.setFill(); context.cgContext.fill(bounds); cursor = 40; pageNumber += 1
                let footer = report.reportNo + " · " + String(pageNumber)
                (footer as NSString).draw(at: CGPoint(x: 40, y: 812), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])
            }
            @MainActor func add<V: View>(_ view: V) {
                let imageRenderer = ImageRenderer(content: view.frame(width: 515, alignment: .leading).fixedSize(horizontal: false, vertical: true).padding(1).foregroundStyle(Color.black).environment(\.colorScheme, .light))
                imageRenderer.scale = 2
                guard let image = imageRenderer.uiImage, image.size.height > 0 else { renderFailed = true; return }
                let height = image.size.height
                if cursor >= 795 || (height < 750 && cursor + height > 795) { page() }
                var consumed: CGFloat = 0
                while consumed < height {
                    let available = min(795 - cursor, height - consumed)
                    context.cgContext.saveGState()
                    context.cgContext.clip(to: CGRect(x: 39, y: cursor, width: 518, height: available))
                    image.draw(at: CGPoint(x: 39, y: cursor - consumed))
                    context.cgContext.restoreGState()
                    consumed += available; cursor += available
                    if consumed < height { page() }
                }
                cursor += 14
            }
            page()
            add(Text(report.title).font(.title.bold()))
            add(Text(report.reportNo).font(.caption))
            add(Text(report.summary).font(.body))
            for block in report.document?.blocks ?? [] {
                if cursor > 690 { page() }
                if block.kind == "table" {
                    add(Text(block.title).font(.headline))
                    let header = block.columns?.joined(separator: " / ") ?? ""
                    add(Text(header).font(.caption.bold()))
                    for row in block.rows ?? [] { add(Text(row.joined(separator: " / ")).font(.caption)) }
                } else if ["timeline", "palaces", "pillars", "pairs", "cards"].contains(block.kind) {
                    add(Text(block.title).font(.headline))
                    if let note = block.note { add(Text(note).font(.caption)) }
                    for item in block.items ?? [] { add(AiReportBlockView(block: block).tile(item)) }
                } else { add(AiReportBlockView(block: block, expanded: true)) }
            }
            for paragraph in report.content.components(separatedBy: "\n\n") {
                add(AiMarkdownText(text: paragraph, exporting: true))
            }
            add(Text("传统文化参考，不替代医疗、法律或财务建议。").font(.caption))
        }
        if renderFailed { try? FileManager.default.removeItem(at: url); throw CocoaError(.fileWriteUnknown) }
        return url
    }
}
