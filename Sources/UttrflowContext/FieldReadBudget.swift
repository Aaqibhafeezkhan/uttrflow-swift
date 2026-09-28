// How long one read of the focused field may run, and how long a field that ran past it is left alone.

private import Synchronization

/// One read's allowance in all, counted on the uptime clock, since each message's own timeout only stops the waiting. See `Docs/predict.md`.
struct FieldReadBudget: Sendable {
    /// The whole read's allowance, under one message's timeout, since a field that answers at all answers in a few milliseconds.
    static let allowanceInNanoseconds: UInt64 = 40_000_000

    /// When the read began, in uptime nanoseconds.
    let started: UInt64

    /// Whether the read has run past its allowance by `now`, in uptime nanoseconds.
    func isSpent(at now: UInt64) -> Bool {
        now >= started && now - started >= Self.allowanceInNanoseconds
    }
}

/// The fields whose last read ran past its budget, each left alone for a while so the application is not asked again every turn.
final class SlowFields: Sendable {
    /// One field of one application, as Accessibility hashes the element.
    struct Key: Hashable, Sendable {
        let process: Int32
        let element: UInt
    }

    /// How long a field is first left alone, in uptime nanoseconds.
    static let firstRestInNanoseconds: UInt64 = 10_000_000_000
    /// The longest a field is left alone, however often its reads run over.
    static let longestRestInNanoseconds: UInt64 = 300_000_000_000
    /// How many fields are remembered at once, the oldest rest dropped first.
    static let capacity = 64

    /// When each resting field may be read again, and how long its last rest was.
    private struct Rest {
        var until: UInt64
        var length: UInt64
    }

    /// Every field's rest, and each application quieted whole until its resting field may lose focus.
    private struct State {
        var rests: [Key: Rest] = [:]
        var quiet: [Int32: UInt64] = [:]
    }

    private let state = Mutex(State())

    /// Whether this field is still resting at `now`, when no message may be sent to it; one that is quiets its application again.
    func isResting(_ key: Key, at now: UInt64) -> Bool {
        state.withLock { state in
            guard let until = state.rests[key]?.until, until > now else { return false }
            state.quiet[key.process] = until
            return true
        }
    }

    /// Whether an application is quiet at `now` because its focused field rests, so not even its focus is asked for.
    func isQuiet(_ process: Int32, at now: UInt64) -> Bool {
        state.withLock { ($0.quiet[process] ?? 0) > now }
    }

    /// Ends every application's quiet, since a click, a switch or a focus key may have left the resting field.
    func focusMayHaveMoved() {
        state.withLock { $0.quiet = [:] }
    }

    /// Records a read of this field that ran past its budget: the first is forgiven as a cold start, then the rest doubles up to the longest.
    func ranOver(_ key: Key, at now: UInt64) {
        state.withLock { state in
            let length = state.rests[key].map(Self.nextRest) ?? 0
            state.rests[key] = Rest(until: now + length, length: length)
            if length > 0 { state.quiet[key.process] = now + length }
            guard state.rests.count > Self.capacity,
                let oldest = state.rests.filter({ $0.key != key }).min(by: { $0.value.until < $1.value.until }
                )?
                .key
            else { return }
            state.rests[oldest] = nil
        }
    }

    /// The rest after one more overrun: the first rest after a forgiven one, then double the last, up to the longest.
    private static func nextRest(after rest: Rest) -> UInt64 {
        rest.length == 0 ? firstRestInNanoseconds : min(rest.length * 2, longestRestInNanoseconds)
    }

    /// Records a read of this field that kept to its budget, which ends any backing off.
    func answered(_ key: Key) {
        state.withLock { state in
            state.rests[key] = nil
            state.quiet[key.process] = nil
        }
    }
}
