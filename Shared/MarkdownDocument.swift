import Foundation

struct MarkdownDocument {
    enum DocumentError: LocalizedError {
        case invalidBundle(String)
        var errorDescription: String? {
            if case .invalidBundle(let reason) = self { return "TextBundle 无法预览：\(reason)" }
            return nil
        }
    }
    static func contentURL(for url: URL) throws -> URL {
        guard url.pathExtension.lowercased() == "textbundle" else { return url }
        let root = url.resolvingSymlinksInPath()
        guard (try root.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else {
            throw DocumentError.invalidBundle("不是目录包")
        }
        let infoURL = root.appendingPathComponent("info.json")
        guard (try infoURL.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0 < 1024 * 1024 else {
            throw DocumentError.invalidBundle("info.json 超过 1 MB")
        }
        struct Info: Decodable { let version: Int; let type: String? }
        let info = try JSONDecoder().decode(Info.self, from: Data(contentsOf: infoURL))
        guard [1, 2].contains(info.version), info.type == nil || ["net.daringfireball.markdown", "public.markdown"].contains(info.type!) else {
            throw DocumentError.invalidBundle("不支持的版本或内容类型")
        }
        let candidates = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey]).filter {
            $0.deletingPathExtension().lastPathComponent == "text" && ["md", "markdown", "mdown", "mkd"].contains($0.pathExtension)
        }
        guard candidates.count == 1 else { throw DocumentError.invalidBundle("需要且只能有一个 text.md 或 text.markdown 正文") }
        let content = candidates[0].resolvingSymlinksInPath()
        guard content.path.hasPrefix(root.path + "/"), (try content.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else {
            throw DocumentError.invalidBundle("正文不是包内的普通文件")
        }
        return content
    }

    /// Preserve YAML verbatim; do not evaluate tags or claim to interpret its schema.
    static func splitFrontMatter(_ source: String) -> (body: String, yaml: String?) {
        let normalized = source.hasPrefix("\u{FEFF}") ? String(source.dropFirst()) : source
        let lines = normalized.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return (source, nil) }
        guard let end = lines.indices.dropFirst().first(where: { ["---", "..."].contains(lines[$0].trimmingCharacters(in: .whitespacesAndNewlines)) }) else { return (source, nil) }
        return (lines.dropFirst(end + 1).joined(separator: "\n"), lines[1..<end].joined(separator: "\n"))
    }
}
