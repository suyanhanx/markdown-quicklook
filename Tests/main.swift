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
