import Foundation

/// Narrow `Sendable` clock seam returning elapsed milliseconds for cooperative `250 ms` and `500 ms` engine deadlines (`AR-007`, `AR-013`, `TEST-004`).
public protocol ElapsedTimeProviding: Sendable {
    func elapsedMilliseconds() -> Int
}

/// Production `ElapsedTimeProviding` timer backed by Swift's monotonic `ContinuousClock`.
public struct ContinuousClockElapsedTimer: ElapsedTimeProviding, Sendable {
    private let startInstant: ContinuousClock.Instant

    public init() {
        self.startInstant = ContinuousClock.now
    }

    public func elapsedMilliseconds() -> Int {
        let duration = ContinuousClock.now - startInstant
        let seconds = duration.components.seconds
        let attoseconds = duration.components.attoseconds
        return Int(seconds * 1000) + Int(attoseconds / 1_000_000_000_000_000)
    }
}

/// Typed degradation or deadline cause returned when an analytical pass is skipped or aborted (`BC-011`, `SEC-012`).
public enum DegradedEvaluationReason: Equatable, Sendable {
    case binarySnapshot
    case degradedPlainTextSnapshot
    case astDepthExceeded(maxDepth: Int)
    case lineLengthExceeded(line: Int, utf16Length: Int)
    case inputTooLarge(byteCount: Int)
    case deadlineExceeded(limitMilliseconds: Int)
}

/// Outcome wrapper returned by `MarkdownLintAndFormatEngine` and `SearchDiffAndBracketEngine` (`BC-011`).
public enum EngineEvaluationOutcome<Value: Equatable & Sendable>: Equatable, Sendable {
    case completed(Value)
    case degradedOrTimedOut(DegradedEvaluationReason)

    /// Unwraps the completed payload when evaluation succeeded without degradation or timeout.
    public var completedValue: Value? {
        if case .completed(let value) = self { return value }
        return nil
    }

    /// Unwraps the degradation or timeout reason when evaluation did not complete normally.
    public var degradedReason: DegradedEvaluationReason? {
        if case .degradedOrTimedOut(let reason) = self { return reason }
        return nil
    }
}
