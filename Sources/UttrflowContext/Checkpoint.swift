/// Thrown when a caller has moved on, so a read stops before its next question to another application.
struct Superseded: Error {}

/// Runs `read` only while the caller still wants the answer.
func unlessSuperseded<T>(_ isWanted: () -> Bool, _ read: () -> T) throws(Superseded) -> T {
    guard isWanted() else { throw Superseded() }
    return read()
}
