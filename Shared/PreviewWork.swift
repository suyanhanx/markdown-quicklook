@preconcurrency import Foundation

/// Return promptly even if synchronous system I/O stalls. One worker per process
/// prevents timed-out requests from accumulating blocked threads.
final class PreviewWork: @unchecked Sendable {
    static let shared = PreviewWork()
    private let lock = NSLock()
    private var active = false
    private let queue = DispatchQueue(label: "local.yan.markdown-preview", qos: .userInitiated)
    enum Failure: LocalizedError {
        case timeout, busy
        var errorDescription: String? {
            switch self {
            case .timeout: return "预览请求超过 8 秒，已停止等待。请关闭预览后重试。"
            case .busy: return "上一预览仍在结束系统操作，请稍后重试。"
            }
        }
    }
    func run<T>(seconds: TimeInterval = 8, operation: @escaping @Sendable (@escaping () -> Bool) throws -> T) async throws -> T {
        let gate = CompletionGate<T>()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                if gate.finished { return }
                lock.lock()
                let occupied = active
                if !occupied { active = true }
                lock.unlock()
                if occupied { gate.finish(.failure(Failure.busy)); return }
                let timer = DispatchWorkItem { gate.finish(.failure(Failure.timeout)) }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds, execute: timer)
                queue.async {
                    defer {
                        timer.cancel()
                        self.lock.lock(); self.active = false; self.lock.unlock()
                    }
                    do {
                        if gate.finished { throw CancellationError() }
                        let value = try operation({ gate.finished })
                        gate.finish(.success(value))
                    } catch { gate.finish(.failure(error)) }
                }
            }
        }, onCancel: { gate.finish(.failure(CancellationError())) })
    }
}

private final class CompletionGate<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<T, Error>?
    private var continuation: CheckedContinuation<T, Error>?
    var finished: Bool {
        lock.lock(); defer { lock.unlock() }
        return result != nil
    }
    func install(_ continuation: CheckedContinuation<T, Error>) {
        lock.lock()
        let completed = result
        if completed == nil { self.continuation = continuation }
        lock.unlock()
        if let completed { continuation.resume(with: completed) }
    }
    func finish(_ result: Result<T, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let callback = continuation
        continuation = nil
        lock.unlock()
        callback?.resume(with: result)
    }
}
