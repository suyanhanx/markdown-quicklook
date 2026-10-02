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
            var html = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
            if CommandLine.arguments[1].contains("cancel.html") {
                html = html.replacingOccurrences(of: "window.previewRenderPromise =", with: "setTimeout(() => window.cancelPreview(), 0); window.previewRenderPromise =")
            }
            if CommandLine.arguments[1].contains("timeout.html") {
                html = html.replacingOccurrences(of: "window.previewRenderPromise =", with: "window.mermaid.parse = () => new Promise(() => {}); window.previewRenderPromise =")
            }
            if CommandLine.arguments[1].contains("skeleton.html") {
                html = html.replacingOccurrences(of: "window.previewRenderPromise =", with: "const realParse = window.mermaid.parse.bind(window.mermaid); window.mermaid.parse = async (...args) => {await new Promise(r=>setTimeout(r,600)); return realParse(...args);}; window.previewRenderPromise =")
            }
            if CommandLine.arguments[1].contains("scrollpause.html") {
                html = html.replacingOccurrences(of: "window.previewRenderPromise =", with: "window.parseStartTimes = []; window.pauseTestStarted = performance.now(); const originalParse = mermaid.parse.bind(mermaid); mermaid.parse = (...args) => {window.parseStartTimes.push(performance.now()-window.pauseTestStarted); return originalParse(...args);}; window.dispatchEvent(new Event('scroll')); const scrolling = setInterval(()=>window.dispatchEvent(new Event('scroll')),30); setTimeout(()=>clearInterval(scrolling),300); window.previewRenderPromise =")
            }
            webView.loadHTMLString(html, baseURL: nil)
        } catch { print(error); exit(1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { print("Web rendering timed out"); exit(1) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if CommandLine.arguments[1].contains("skeleton.html") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                webView.takeSnapshot(with: nil) { image, error in
                    guard error == nil, let image, let tiff = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiff),
                          let png = bitmap.representation(using: .png, properties: [:]) else { print("Skeleton snapshot failed"); exit(1) }
                    do { try png.write(to: URL(fileURLWithPath: "build/skeleton-preview.png")) }
                    catch { print("Skeleton snapshot save failed: \(error)"); exit(1) }
                }
            }
        }
        webView.callAsyncJavaScript("""
        let skeletonBefore = null;
        if (document.title === 'Skeleton test') {
          await new Promise(resolve=>setTimeout(resolve,100));
          skeletonBefore = {
            total:document.querySelectorAll('.render-placeholder[aria-busy="true"]').length,
            active:document.querySelectorAll('.placeholder-active').length,
            queued:Array.from(document.querySelectorAll('.placeholder-label')).filter(x=>x.textContent.includes('排队中')).length,
            raw:document.querySelectorAll('pre > code.language-mermaid').length,
            text:document.querySelector('.preview-progress-label')?.textContent
          };
        }
        await window.previewRenderPromise;
        await Promise.all(Array.from(document.images).map(img => img.complete ? Promise.resolve() : new Promise(resolve => {img.addEventListener('load',resolve,{once:true}); img.addEventListener('error',resolve,{once:true});})));
        const viewport = document.querySelector('.diagram-viewport');
        const toolbar = document.querySelector('.diagram-toolbar');
        let zoomWorks = false, scrollWorks = false, fitWorks = false;
        if (toolbar) {
          const buttons = Array.from(toolbar.querySelectorAll('button'));
          const svg = viewport.querySelector('.diagram-image');
          buttons.find(b=>b.textContent === '实际大小').click();
          const before = svg.getBoundingClientRect().width;
          buttons.find(b=>b.textContent === '放大').click();
          zoomWorks = svg.getBoundingClientRect().width > before;
          viewport.style.width = '200px';
          scrollWorks = viewport.scrollWidth > viewport.clientWidth;
          viewport.scrollLeft = 100;
          scrollWorks = scrollWorks && viewport.scrollLeft > 0;
          buttons.find(b=>b.textContent === '适应宽度').click();
          fitWorks = svg.getBoundingClientRect().width <= viewport.clientWidth + 1;
        }
        const completed = Array.from(document.querySelectorAll('.diagram-image,.math-image'));
        const sources = completed.map(x=>x.src);
        for (const y of [100000,0,50000,0,100000,0]) {
          window.scrollTo(0,y);
          await new Promise(resolve=>setTimeout(resolve,20));
        }
        const retainedAfterScroll = completed.every((x,i)=>x.isConnected && x.complete && x.naturalWidth > 0 && x.src === sources[i]);
        return {parseStartTimes:window.parseStartTimes || [], retainedAfterScroll, domNodes:document.querySelectorAll('*').length, svgNodes:document.querySelectorAll('svg *').length, state: window.previewRenderState, skeletonBefore,
                skeletonsLeft:document.querySelectorAll('.render-placeholder,[aria-busy="true"]').length, zoomWorks, scrollWorks, fitWorks,
                highlightSkipped:Array.from(document.querySelectorAll('.html-notice')).some(x=>x.textContent.includes('跳过高亮')),
                text:document.querySelector('main').textContent.slice(0,2000),
                alerts:document.querySelectorAll('.markdown-alert').length,
                headings:Array.from(document.querySelectorAll('h1,h2')).map(x=>x.id),
                toc:document.querySelectorAll('.document-toc a').length,
                yaml:document.querySelector('.front-matter code')?.textContent || '',
                details:!!document.querySelector('details:not(.front-matter) summary'),
                task:document.querySelector('input[type="checkbox"]')?.disabled === true,
                unsafe:!!document.querySelector('main script, main iframe, main [onerror], main a[href^="javascript:"]'),
                pwned:window.PWNED === 1,
                images:Array.from(document.images).filter(x=>x.naturalWidth>0 && !x.matches('.math-image,.diagram-image')).length,
                imageErrors:Array.from(document.querySelectorAll('.image-notice')).filter(x=>x.textContent.includes('图片加载失败')).length,
                mathSVGs: document.querySelectorAll('.math-image').length,
                diagramSVGs: document.querySelectorAll('.diagram-image').length,
                errors: document.querySelectorAll('.render-error').length,
                background: getComputedStyle(document.body).backgroundColor,
                visibleAssistiveMath: Array.from(document.querySelectorAll('mjx-assistive-mml')).some(x=>getComputedStyle(x).position !== 'absolute'),
                resources: performance.getEntriesByType('resource').map(x=>x.name).filter(x=>!x.startsWith('data:')),
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
                          dictionary["visibleAssistiveMath"] as? Bool == false, dictionary["pending"] as? Bool == false else { exit(1) }
                    guard dictionary["retainedAfterScroll"] as? Bool == true else { exit(1) }
                    guard dictionary["skeletonsLeft"] as? Int == 0 else { exit(1) }
                    let path = CommandLine.arguments[1]
                    if path.contains("scrollpause.html") {
                        guard let starts = dictionary["parseStartTimes"] as? [Double] else { exit(1) }
                        exit(starts.count == 2 && starts[0] >= 400 && errors == 0 && diagrams == 2 ? 0 : 1)
                    }
                    if path.contains("skeleton.html") {
                        guard let before = dictionary["skeletonBefore"] as? [String:Any] else { exit(1) }
                        exit(before["total"] as? Int == 2 && before["active"] as? Int == 1 && before["queued"] as? Int == 1 && before["raw"] as? Int == 0 && (before["text"] as? String)?.contains("0 / 2") == true && diagrams == 2 && errors == 0 ? 0 : 1)
                    }
                    if path.contains("navigation.html") {
                        exit(diagrams == 2 && errors == 0 && dictionary["zoomWorks"] as? Bool == true && dictionary["scrollWorks"] as? Bool == true && dictionary["fitWorks"] as? Bool == true ? 0 : 1)
                    }
                    if path.contains("limits.html") {
                        let text = dictionary["text"] as? String ?? ""
                        exit(errors == 1 && text.contains("图表超过限制") && dictionary["highlightSkipped"] as? Bool == true ? 0 : 1)
                    }
                    if path.contains("cancel.html") || path.contains("timeout.html") {
                        let text = dictionary["text"] as? String ?? ""
                        exit(errors >= 1 && diagrams == 0 && (text.contains("已取消") || text.contains("超时")) ? 0 : 1)
                    }
                    if path.contains("remote-live") {
                        exit(dictionary["images"] as? Int == 1 && dictionary["imageErrors"] as? Int == 1 && resources.count == 2 ? 0 : 1)
                    }
                    guard resources.isEmpty else { exit(1) }
                    if path.contains("features.html") {
                        guard let headings = dictionary["headings"] as? [String] else { exit(1) }
                        exit(dictionary["alerts"] as? Int == 5 && dictionary["toc"] as? Int == headings.count &&
                             headings.contains("中文-标题") && headings.contains("中文-标题-1") &&
                             dictionary["details"] as? Bool == true && dictionary["task"] as? Bool == true &&
                             dictionary["unsafe"] as? Bool == false && dictionary["pwned"] as? Bool == false &&
                             (dictionary["yaml"] as? String)?.contains("title:") == true && math == 1 && errors == 0 ? 0 : 1)
                    }
                    if path.contains("textbundle.html") {
                        exit(dictionary["images"] as? Int == 1 && dictionary["alerts"] as? Int == 1 && errors == 0 ? 0 : 1)
                    }
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
