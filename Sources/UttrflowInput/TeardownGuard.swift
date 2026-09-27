/// Runs a teardown once per object per call chain, so a release inside it cannot call back into the same teardown.
enum TeardownGuard {
    /// The objects whose teardown is running further up this thread's or task's call chain.
    @TaskLocal private static var running: Set<ObjectIdentifier> = []

    /// Runs `body` unless `owner`'s teardown is already running below this call; another thread still runs it.
    static func once(for owner: AnyObject, _ body: () -> Void) {
        let id = ObjectIdentifier(owner)
        guard !running.contains(id) else { return }
        $running.withValue(running.union([id]), operation: body)
    }
}
