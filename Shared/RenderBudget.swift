import Foundation

/// Cooperative limits: checks surround synchronous C parsing and file I/O.
/// These operations cannot be preempted mid-call; size limits bound their input.
struct RenderBudget {
    let deadline: TimeInterval
    let cancelled: () -> Bool
    init(seconds: TimeInterval = 8, cancelled: @escaping () -> Bool = { false }) {
        deadline = ProcessInfo.processInfo.systemUptime + seconds
        self.cancelled = cancelled
    }
    func check() throws {
        if cancelled() { throw CancellationError() }
        if ProcessInfo.processInfo.systemUptime >= deadline { throw LimitError.timeout }
    }
    enum LimitError: LocalizedError {
        case timeout, outputTooLarge
        var errorDescription: String? {
            switch self {
            case .timeout: return "预览生成超过 8 秒，已停止。请缩小文档后重试。"
            case .outputTooLarge: return "预览内容超过 48 MB，已停止。请减少图片或拆分文档。"
            }
        }
    }
}
