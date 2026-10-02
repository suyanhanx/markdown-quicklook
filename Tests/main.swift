import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let renderer = MarkdownRenderer(resourceURL: root.appendingPathComponent("Resources"))
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    checks += 1
}
let fixture = try renderer.render(file: root.appendingPathComponent("Fixtures/preview.md"), settings: PreviewSettings())
check(fixture.contains("<table>"), "GFM tables")
check(fixture.contains("type=\"checkbox\""), "Task lists")
check(fixture.contains("<del>删除线</del>"), "Strikethrough")
check(fixture.contains("language-swift"), "Fenced code language")
check(fixture.contains("data:image/svg+xml;base64,"), "Embedded local image")
check(fixture.contains("footnotes"), "Footnotes")
check(fixture.contains("中文"), "UTF-8")
check(!fixture.contains("buymeacoffee"), "No donation footer")
check(!fixture.contains("QLMarkdown"), "Independent document")
let evil = try renderer.render(markdown: "<script>window.PWNED=1</script>\n\n[x](javascript:alert(1))\n\n![remote](https://example.com/a.png)\n\n![missing](missing.png)", title: "<unsafe>\"", baseURL: root, settings: PreviewSettings())
check(!evil.contains("window.PWNED"), "Raw scripts are not emitted")
check(!evil.contains("href=\"javascript:"), "Unsafe links are stripped")
check(evil.contains("远程图片未加载"), "Remote image policy is visible")
check(evil.contains("本地图片无法读取"), "Missing image errors are visible")
check(evil.contains("<title>&lt;unsafe&gt;&quot;</title>"), "Title escaping")
let temp = root.appendingPathComponent("build/renderer-tests")
try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
try Data([0xff, 0xfe, 0x00]).write(to: temp.appendingPathComponent("invalid.md"))
do {
    _ = try renderer.render(file: temp.appendingPathComponent("invalid.md"))
    fatalError("Invalid UTF-8 must fail explicitly")
} catch MarkdownRenderer.RenderError.invalidUTF8 { checks += 1 }
for count in 1...101 {
    let html = try renderer.render(markdown: "# Preview \(count)", title: "Test", baseURL: root, settings: PreviewSettings())
    check(html.contains("<h1>Preview \(count)</h1>"), "Repeated rendering is stable")
    check(!html.contains("buymeacoffee"), "No recurring donation banner")
}
try fixture.write(to: root.appendingPathComponent("build/preview.html"), atomically: true, encoding: .utf8)
print("Passed \(checks) renderer checks; wrote build/preview.html")
let rich = try renderer.render(file: root.appendingPathComponent("Fixtures/rich-preview.md"))
check(rich.contains("data-tex=\""), "TeX is protected before Markdown parsing")
check(rich.contains("$20 和 $30"), "Currency stays literal")
check(rich.contains("<code>$x_i$</code>"), "Inline code is not parsed as math")
check(rich.contains("language-python"), "Ordinary fences stay intact")
let markup = MathMarkup(#"$x_i$ and \(\frac{1}{2}\) and ` $no$ ` and \$100"#)
check(markup.expressions.count == 2, "Only actual math delimiters are consumed")
check(markup.expressions[0].tex == "x_i", "TeX underscores preserved")
check(markup.expressions[1].tex == #"\frac{1}{2}"#, "TeX commands preserved")
check(MathMarkup("    $code$\n\n~~~swift\n$code$\n~~~\n").expressions.isEmpty, "Indented and tilde-fenced code stay literal")
let errors = try renderer.render(file: root.appendingPathComponent("Fixtures/render-errors.md"))
try rich.write(to: root.appendingPathComponent("build/rich-preview.html"), atomically: true, encoding: .utf8)
try errors.write(to: root.appendingPathComponent("build/render-errors.html"), atomically: true, encoding: .utf8)

check(MathMarkup("[link](https://example.com/$x$/) ![$alt$](x.png) <https://example.com/$x$/>").expressions.isEmpty, "URLs and image alt text stay literal")

let directDiagram = try renderer.render(file: root.appendingPathComponent("Fixtures/sample.mermaid"))
check(directDiagram.contains("language-mermaid"), "Standalone Mermaid files render as diagrams")
let dark = try renderer.render(file: root.appendingPathComponent("Fixtures/rich-preview.md"), settings: PreviewSettings(appearance: "dark"))
try dark.write(to: root.appendingPathComponent("build/rich-dark.html"), atomically: true, encoding: .utf8)
print("Passed \(checks) total renderer checks including math preservation")

let bundle = try renderer.render(file: root.appendingPathComponent("Fixtures/Notebook.textbundle"))
check(bundle.contains("TextBundle 笔记"), "TextBundle body")
check(bundle.contains("data:image/svg+xml;base64,"), "TextBundle relative image")
let badBundle = temp.appendingPathComponent("bad.textbundle")
try FileManager.default.createDirectory(at: badBundle, withIntermediateDirectories: true)
try Data(#"{"version":2,"type":"net.daringfireball.markdown"}"#.utf8).write(to: badBundle.appendingPathComponent("info.json"))
do {
    _ = try renderer.render(file: badBundle)
    fatalError("Missing bundle body must fail explicitly")
} catch MarkdownDocument.DocumentError.invalidBundle { checks += 1 }
let features = try renderer.render(file: root.appendingPathComponent("Fixtures/features.md"), settings: PreviewSettings(showTOC: true, renderHTML: true))
try features.write(to: root.appendingPathComponent("build/features.html"), atomically: true, encoding: .utf8)
try bundle.write(to: root.appendingPathComponent("build/textbundle.html"), atomically: true, encoding: .utf8)
let frontMatter = MarkdownDocument.splitFrontMatter("---\ntitle: value\n---\n# Body")
check(frontMatter.yaml == "title: value" && frontMatter.body == "# Body", "Front matter is separated from body")
check(MarkdownDocument.splitFrontMatter("---\nNo closing delimiter").yaml == nil, "Unterminated front matter remains content")
let remote = try renderer.render(markdown: "![成功](http://127.0.0.1:54321/ok.png)\n\n![失败](http://127.0.0.1:54321/missing.png)", title: "Remote test", baseURL: root, settings: PreviewSettings(loadRemoteImages: true))
try remote.write(to: root.appendingPathComponent("build/remote-template.html"), atomically: true, encoding: .utf8)
print("Passed \(checks) total renderer checks including TextBundle and front matter")
