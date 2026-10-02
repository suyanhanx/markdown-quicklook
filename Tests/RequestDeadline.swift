import Foundation

@main struct RequestDeadlineTest {
    static func main() async throws {
        let worker = PreviewWork()
        let release = DispatchSemaphore(value: 0)
        let first = Task {
            try await worker.run(seconds: 0.1) { _ in
                release.wait()
                return 1
            }
        }
        do { _ = try await first.value; fatalError("Blocked I/O must time out") }
        catch PreviewWork.Failure.timeout { }
        do { _ = try await worker.run { _ in 2 }; fatalError("Blocked worker must reject another request") }
        catch PreviewWork.Failure.busy { }
        release.signal()
        try await Task.sleep(nanoseconds: 50_000_000)
        let recovered = try await worker.run { _ in 3 }
        precondition(recovered == 3)
        let cancellationWorker = PreviewWork()
        let cancelled = Task {
            try await cancellationWorker.run { isCancelled in
                while !isCancelled() { Thread.sleep(forTimeInterval: 0.005) }
                throw CancellationError()
            } as Int
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("Cancellation must propagate") }
        catch is CancellationError { }
        print("Request deadline, bounded worker, recovery and cancellation passed")
    }
}
