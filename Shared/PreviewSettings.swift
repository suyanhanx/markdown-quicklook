import Foundation

struct PreviewSettings {
    static let suite = "group.local.yan.markdownquicklook"
    var fontSize: Double = 16
    var contentWidth: Double = 860
    var appearance = "auto"
    var showTOC = false
    var renderHTML = false
    var loadRemoteImages = false

    static func load() -> Self {
        let defaults = UserDefaults(suiteName: suite)!
        var settings = Self()
        if let size = defaults.object(forKey: "fontSize") as? Double {
            settings.fontSize = min(24, max(12, size))
        }
        if let width = defaults.object(forKey: "contentWidth") as? Double {
            settings.contentWidth = min(1400, max(480, width))
        }
        if let appearance = defaults.string(forKey: "appearance"), ["auto", "light", "dark"].contains(appearance) {
            settings.appearance = appearance
        }
        settings.showTOC = defaults.bool(forKey: "showTOC")
        settings.renderHTML = defaults.bool(forKey: "renderHTML")
        settings.loadRemoteImages = defaults.bool(forKey: "loadRemoteImages")
        return settings
    }
}
