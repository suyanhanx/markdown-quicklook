import Foundation
import UniformTypeIdentifiers

/// GFM parsing and preview composition are shared by the extension and verification tool.
final class MarkdownRenderer {
    enum RenderError: LocalizedError {
        case invalidUTF8, fileTooLarge, parserFailure, missingResource(String), invalidImage(String)
        var errorDescription: String? {
            switch self {
            case .invalidUTF8: return "文件不是有效的 UTF-8 Markdown。"
            case .fileTooLarge: return "文件超过 20 MB，无法预览。"
            case .parserFailure: return "Markdown 解析失败。"
            case .missingResource(let name): return "缺少预览资源：\(name)"
            case .invalidImage(let name): return "无法加载本地图片：\(name)"
            }
        }
    }
    private static let registerExtensions: Void = cmark_gfm_core_extensions_ensure_registered()
    let resourceURL: URL
    init(resourceURL: URL) { self.resourceURL = resourceURL }

    func render(file: URL, settings: PreviewSettings = .load()) throws -> String {
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 20 * 1024 * 1024 else { throw RenderError.fileTooLarge }
        let data = try Data(contentsOf: file)
        guard data.count <= 20 * 1024 * 1024 else { throw RenderError.fileTooLarge }
        guard let markdown = String(data: data, encoding: .utf8) else { throw RenderError.invalidUTF8 }
        return try render(markdown: markdown, title: file.lastPathComponent, baseURL: file.deletingLastPathComponent(), settings: settings)
    }

    func render(markdown: String, title: String, baseURL: URL, settings: PreviewSettings) throws -> String {
        _ = Self.registerExtensions
        let options = CMARK_OPT_DEFAULT | CMARK_OPT_FOOTNOTES | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
        guard let parser = cmark_parser_new(options) else { throw RenderError.parserFailure }
        defer { cmark_parser_free(parser) }
        for name in ["table", "strikethrough", "autolink", "tagfilter", "tasklist"] {
            guard let ext = cmark_find_syntax_extension(name), cmark_parser_attach_syntax_extension(parser, ext) != 0 else {
                throw RenderError.parserFailure
            }
        }
        markdown.withCString { cmark_parser_feed(parser, $0, markdown.utf8.count) }
        guard let document = cmark_parser_finish(parser) else { throw RenderError.parserFailure }
        defer { cmark_node_free(document) }
        guard let rendered = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else {
            throw RenderError.parserFailure
        }
        defer { free(rendered) }
        var body = String(cString: rendered)
        body = try embedLocalImages(in: body, baseURL: baseURL)
        let css = try resource("preview.css")
        let highlighter = try resource("highlight.min.js")
        let nonce = UUID().uuidString
        let theme = ["auto", "light", "dark"].contains(settings.appearance) ? settings.appearance : "auto"
        return """
        <!doctype html>
        <html lang="zh" data-theme="\(theme)">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src 'nonce-\(nonce)'; base-uri 'none'; form-action 'none'">
        <title>\(escape(title))</title>
        <style>\(css)
        :root { --font-size: \(min(24, max(12, settings.fontSize)))px; --content-width: \(min(1400, max(480, settings.contentWidth)))px; }
        </style></head>
        <body><main class="markdown-body">\(body)</main>
        <script nonce="\(nonce)">\(highlighter)</script>
        <script nonce="\(nonce)">hljs.highlightAll();</script>
        </body></html>
        """
    }

    private func resource(_ name: String) throws -> String {
        let url = resourceURL.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { throw RenderError.missingResource(name) }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func embedLocalImages(in html: String, baseURL: URL) throws -> String {
        let pattern = try NSRegularExpression(pattern: #"<img\b[^>]*\bsrc="([^"]*)"[^>]*>"#)
        var result = html
        for match in pattern.matches(in: html, range: NSRange(html.startIndex..., in: html)).reversed() {
            guard let sourceRange = Range(match.range(at: 1), in: html), let tagRange = Range(match.range, in: html) else { continue }
            let source = unescape(String(html[sourceRange]))
            if source.hasPrefix("data:image/") { continue }
            if source.hasPrefix("https:") || source.hasPrefix("http:") || source.hasPrefix("//") {
                result.replaceSubrange(tagRange, with: "<span class=\"image-notice\">远程图片未加载：\(escape(source))</span>")
                continue
            }
            guard let url = URL(string: source, relativeTo: baseURL.appendingPathComponent("", isDirectory: true))?.absoluteURL,
                  url.isFileURL,
                  let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
                  let mime = type.preferredMIMEType,
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 10 * 1024 * 1024,
                  let data = try? Data(contentsOf: url), data.count <= 10 * 1024 * 1024 else {
                result.replaceSubrange(tagRange, with: "<span class=\"image-notice\">本地图片无法读取：\(escape(source))</span>")
                continue
            }
            result.replaceSubrange(sourceRange, with: "data:\(mime);base64,\(data.base64EncodedString())")
        }
        return result
    }
    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    private func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&amp;", with: "&")
    }
}
