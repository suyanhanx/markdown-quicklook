import Cocoa
import WebKit

@main final class RenderSnapshot: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    static var retained: RenderSnapshot!
    var view: WKWebView!
    static func main() {
        retained = RenderSnapshot()
        NSApplication.shared.delegate = retained
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.run()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 1700))
        view.navigationDelegate = self
        do { view.loadHTMLString(try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8), baseURL: nil) }
        catch { print(error); exit(1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { print("Snapshot timed out"); exit(1) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.callAsyncJavaScript("await window.previewRenderPromise; return true;", arguments: [:], in: nil, in: .page) { result in
            guard case .success = result else { print(result); exit(1) }
            webView.takeSnapshot(with: nil) { image, error in
                guard error == nil, let data = image?.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) else { print("Snapshot failed"); exit(1) }
                do { try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2])); exit(0) }
                catch { print(error); exit(1) }
            }
        }
    }
}
