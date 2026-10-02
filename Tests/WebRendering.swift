import Cocoa
import WebKit

@main
final class WebRenderingTest: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var webView: WKWebView!
    static var retained: WebRenderingTest!
    static func main() {
        retained = WebRenderingTest()
        NSApplication.shared.delegate = retained
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.run()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 1000), configuration: configuration)
        webView.navigationDelegate = self
        do {
            let html = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
            webView.loadHTMLString(html, baseURL: nil)
        } catch { print(error); exit(1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { print("Web rendering timed out"); exit(1) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.callAsyncJavaScript("""
        await window.previewRenderPromise;
        return {state: window.previewRenderState,
                mathSVGs: document.querySelectorAll('mjx-container svg').length,
                diagramSVGs: document.querySelectorAll('.mermaid-diagram svg').length,
                errors: document.querySelectorAll('.render-error').length,
                background: getComputedStyle(document.body).backgroundColor,
                visibleAssistiveMath: Array.from(document.querySelectorAll('mjx-assistive-mml')).some(x=>getComputedStyle(x).position !== 'absolute'),
                resources: performance.getEntriesByType('resource').map(x=>x.name),
                codeLiteral: Array.from(document.querySelectorAll('code')).some(x=>x.textContent.includes('$x_i$')),
                pending: document.querySelector('main').textContent.includes('正在渲染公式')};
        """, arguments: [:], in: nil, in: .page) { result in
            switch result {
            case .success(let value):
                do {
                    let data = try JSONSerialization.data(withJSONObject: value as Any, options: [.prettyPrinted, .sortedKeys])
                    print(String(decoding: data, as: UTF8.self))
                    guard let dictionary = value as? [String: Any],
                          let math = dictionary["mathSVGs"] as? Int,
                          let diagrams = dictionary["diagramSVGs"] as? Int,
                          let errors = dictionary["errors"] as? Int,
                          let resources = dictionary["resources"] as? [String],
                          resources.isEmpty, dictionary["visibleAssistiveMath"] as? Bool == false, dictionary["pending"] as? Bool == false else { exit(1) }
                    if CommandLine.arguments[1].contains("rich-dark") {
                        guard dictionary["background"] as? String == "rgb(13, 17, 23)" else { exit(1) }
                    }
                    let errorFixture = CommandLine.arguments[1].contains("render-errors")
                    if errorFixture { exit(math == 1 && diagrams == 1 && errors == 2 ? 0 : 1) }
                    exit(math == 8 && diagrams == 2 && errors == 0 && dictionary["codeLiteral"] as? Bool == true ? 0 : 1)
                } catch { print(error); exit(1) }
            case .failure(let error): print("WebKit rendering failed: \(error)"); exit(1)
            }
        }
    }
}
