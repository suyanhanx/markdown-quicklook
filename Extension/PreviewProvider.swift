import Cocoa
import Quartz
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        guard let resources = Bundle.main.resourceURL else {
            throw MarkdownRenderer.RenderError.missingResource("Extension resources")
        }
        let settings = PreviewSettings.load()
        let html = try MarkdownRenderer(resourceURL: resources).render(file: request.fileURL, settings: settings)
        return QLPreviewReply(dataOfContentType: .html, contentSize: NSSize(width: settings.contentWidth + 64, height: 720)) { reply in
            reply.stringEncoding = .utf8
            return Data(html.utf8)
        }
    }
}
