import SwiftUI

@main
struct MarkdownQuickLookApp: App {
    var body: some Scene {
        WindowGroup("Markdown Quick Look") { SettingsView() }
            .windowResizability(.contentSize)
    }
}

struct SettingsView: View {
    @AppStorage("fontSize", store: UserDefaults(suiteName: PreviewSettings.suite)) private var fontSize = 16.0
    @AppStorage("contentWidth", store: UserDefaults(suiteName: PreviewSettings.suite)) private var contentWidth = 860.0
    @AppStorage("appearance", store: UserDefaults(suiteName: PreviewSettings.suite)) private var appearance = "auto"

    @AppStorage("showTOC", store: UserDefaults(suiteName: PreviewSettings.suite)) private var showTOC = false
    @AppStorage("renderHTML", store: UserDefaults(suiteName: PreviewSettings.suite)) private var renderHTML = false
    @AppStorage("loadRemoteImages", store: UserDefaults(suiteName: PreviewSettings.suite)) private var loadRemoteImages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "doc.richtext").font(.system(size: 42)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Markdown Quick Look").font(.title2.bold())
                    Text("在 Finder 里选中 Markdown，按空格预览。").foregroundStyle(.secondary)
                }
            }
            Form {
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("auto")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                HStack { Text("字号"); Slider(value: $fontSize, in: 12...24, step: 1); Text("\(Int(fontSize)) px").monospacedDigit().frame(width: 48) }
                HStack { Text("宽度"); Slider(value: $contentWidth, in: 480...1400, step: 20); Text("\(Int(contentWidth)) px").monospacedDigit().frame(width: 64) }
            }
            Toggle("显示文档目录", isOn: $showTOC)
            Toggle("显示 HTML 排版（不执行脚本）", isOn: $renderHTML)
            Toggle("加载远程图片（需要联网）", isOn: $loadRemoteImages)
            Text("设置自动保存，重新打开预览后生效。支持表格、任务列表、脚注、代码高亮、本地图片、Mermaid 图表和数学公式。远程图片默认不加载；开启后会访问图片网址。").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("打开扩展设置") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                }
                Spacer()
                Text("1.2 · 无广告").foregroundStyle(.secondary).font(.caption)
            }
        }.padding(28).frame(width: 480)
    }
}
