import Foundation
import UniformTypeIdentifiers
import ImageIO

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

    func render(file requestedFile: URL, settings: PreviewSettings = .load(), budget: RenderBudget = RenderBudget()) throws -> String {
        try budget.check()
        let file = try MarkdownDocument.contentURL(for: requestedFile)
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 20 * 1024 * 1024 else { throw RenderError.fileTooLarge }
        let data = try Data(contentsOf: file)
        guard data.count <= 20 * 1024 * 1024 else { throw RenderError.fileTooLarge }
        guard let markdown = String(data: data, encoding: .utf8) else { throw RenderError.invalidUTF8 }
        let source: String
        if file.pathExtension.lowercased() == "mermaid" {
            let longestRun = markdown.split(whereSeparator: { $0 != "`" }).map(\.count).max() ?? 0
            let fence = String(repeating: "`", count: max(3, longestRun + 1))
            source = fence + "mermaid\n" + markdown + "\n" + fence
        } else { source = markdown }
        return try render(markdown: source, title: requestedFile.lastPathComponent, baseURL: file.deletingLastPathComponent(), settings: settings, budget: budget)
    }

    func render(markdown: String, title: String, baseURL: URL, settings: PreviewSettings, budget: RenderBudget = RenderBudget()) throws -> String {
        try budget.check()
        guard markdown.utf8.count <= 20 * 1024 * 1024 else { throw RenderError.fileTooLarge }
        _ = Self.registerExtensions
        let options = CMARK_OPT_DEFAULT | CMARK_OPT_FOOTNOTES | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE | (settings.renderHTML ? CMARK_OPT_UNSAFE : 0)
        guard let parser = cmark_parser_new(options) else { throw RenderError.parserFailure }
        defer { cmark_parser_free(parser) }
        for name in ["table", "strikethrough", "autolink", "tagfilter", "tasklist"] {
            guard let ext = cmark_find_syntax_extension(name), cmark_parser_attach_syntax_extension(parser, ext) != 0 else {
                throw RenderError.parserFailure
            }
        }
        let frontMatter = MarkdownDocument.splitFrontMatter(markdown)
        let mathMarkup = MathMarkup(frontMatter.body)
        try budget.check()
        try mathMarkup.markdown.withCString { bytes in
            let length = mathMarkup.markdown.utf8.count
            for offset in stride(from: 0, to: length, by: 65536) {
                try budget.check()
                cmark_parser_feed(parser, bytes.advanced(by: offset), min(65536, length - offset))
            }
        }
        guard let document = cmark_parser_finish(parser) else { throw RenderError.parserFailure }
        defer { cmark_node_free(document) }
        guard let rendered = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else {
            throw RenderError.parserFailure
        }
        defer { free(rendered) }
        try budget.check()
        var body = mathMarkup.restore(in: String(cString: rendered))
        body = try embedLocalImages(in: body, baseURL: baseURL, loadRemoteImages: settings.loadRemoteImages, budget: budget)
        if let yaml = frontMatter.yaml {
            body = "<details class=\"front-matter\"><summary>YAML 元信息</summary><pre><code class=\"language-yaml\">" + escape(yaml) + "</code></pre></details>" + body
        }
        try budget.check()
        guard body.utf8.count <= 48 * 1024 * 1024 else { throw RenderBudget.LimitError.outputTooLarge }
        let css = try resource("preview.css")
        let highlighter = try resource("highlight.min.js")
        let hasMath = body.contains("class=\"math-expression") || body.contains("class=\"language-math\"")
        let hasMermaid = body.contains("class=\"language-mermaid\"")
        let mathLibrary = hasMath ? try resource("mathjax-tex-svg.js") : ""
        let mermaidLibrary = hasMermaid ? try resource("mermaid.min.js") : ""
        let runtime = try resource("preview.js")
        let sanitizer = settings.renderHTML ? try resource("purify.min.js") : ""
        let encodedBody = Data(body.utf8).base64EncodedString()
        let initialBody = settings.renderHTML ? "正在处理 HTML…" : body
        let bootstrap = settings.renderHTML ? "window.previewHTML = '\(encodedBody)';" : ""
        let imageSources = settings.loadRemoteImages ? "data: https: http:" : "data:"
        let nonce = UUID().uuidString
        func script(_ source: String) -> String {
            // Avoid closing the HTML script element from a library string literal.
            let escaped = source.replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
            return "<script nonce=\"\(nonce)\">\(escaped)</script>"
        }
        let mathConfig = #"window.MathJax = {startup:{typeset:false}, tex:{packages:['base','ams','newcommand','configmacros','boldsymbol','mathtools','cases','cancel','color','unicode'], maxBuffer:20480, maxMacros:1000, formatError:(_jax,error)=>{throw error}}, svg:{fontCache:'local'}, options:{enableMenu:false}, loader:{load:[]}};"#
        let theme = ["auto", "light", "dark"].contains(settings.appearance) ? settings.appearance : "auto"
        return """
        <!doctype html>
        <html lang="zh" data-theme="\(theme)">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src \(imageSources); script-src 'nonce-\(nonce)'; base-uri 'none'; form-action 'none'">
        <title>\(escape(title))</title>
        <style>\(css)
        :root { --font-size: \(min(24, max(12, settings.fontSize)))px; --content-width: \(min(1400, max(480, settings.contentWidth)))px; }
        </style></head>
        <body data-toc="\(settings.showTOC ? "true" : "false")"><main class="markdown-body">\(initialBody)</main>
        \(settings.renderHTML ? script(sanitizer) + script(bootstrap) : "")
        \(script(highlighter))
        \(hasMath ? script(mathConfig) + script(mathLibrary) : "")
        \(hasMermaid ? script(mermaidLibrary) : "")
        \(script(runtime))
        </body></html>
        """
    }

    private func resource(_ name: String) throws -> String {
        let url = resourceURL.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { throw RenderError.missingResource(name) }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func embedLocalImages(in html: String, baseURL: URL, loadRemoteImages: Bool, budget: RenderBudget) throws -> String {
        let pattern = try NSRegularExpression(pattern: #"<img\b[^>]*\bsrc\s*=\s*(["'])(.*?)\1[^>]*>"#, options: [.caseInsensitive])
        var result = html
        var embeddedBytes = 0
        for match in pattern.matches(in: html, range: NSRange(html.startIndex..., in: html)).reversed() {
            try budget.check()
            guard let sourceRange = Range(match.range(at: 2), in: html), let tagRange = Range(match.range, in: html) else { continue }
            let source = unescape(String(html[sourceRange]))
            if source.hasPrefix("data:image/") { continue }
            if source.hasPrefix("https:") || source.hasPrefix("http:") || source.hasPrefix("//") {
                if loadRemoteImages { continue }
                result.replaceSubrange(tagRange, with: "<span class=\"image-notice\">远程图片未加载：\(escape(source))</span>")
                continue
            }
            guard let url = URL(string: source, relativeTo: baseURL.appendingPathComponent("", isDirectory: true))?.absoluteURL,
                  url.isFileURL,
                  let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
                  let mime = type.preferredMIMEType,
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size <= 10 * 1024 * 1024,
                  embeddedBytes + size <= 20 * 1024 * 1024,
                  let data = try? Data(contentsOf: url), data.count <= 10 * 1024 * 1024 else {
                result.replaceSubrange(tagRange, with: "<span class=\"image-notice\">本地图片无法读取或超过限制（单图 10 MB，累计 20 MB）：\(escape(source))</span>")
                continue
            }
            if !type.conforms(to: .svg) {
                guard let image = CGImageSourceCreateWithData(data as CFData, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
                      let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                      let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                      width.doubleValue > 0, height.doubleValue > 0,
                      width.doubleValue * height.doubleValue <= 40_000_000 else {
                    result.replaceSubrange(tagRange, with: "<span class=\"image-notice\">图片无效或超过 4000 万像素：\(escape(source))</span>")
                    continue
                }
            }
            embeddedBytes += data.count
            guard embeddedBytes <= 20 * 1024 * 1024 else { throw RenderBudget.LimitError.outputTooLarge }
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
