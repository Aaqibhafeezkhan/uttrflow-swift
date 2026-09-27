import Foundation

/// How a model's modules are built once, and how their weights are emptied and read back in afterwards.
struct WeightLoading<Modules: Sendable>: Sendable {
    /// Builds the modules and reads the weights into them, quantising the layers that are stored quantised.
    let build: @Sendable (URL) async throws -> Modules
    /// Reads the weights from disk into modules that were emptied.
    let refill: @Sendable (Modules, URL) async throws -> Void
    /// Swaps every weight for a placeholder that holds no memory, keeping the modules.
    let empty: @Sendable (Modules) async -> Void
}

/// Builds a model's modules on the first load only, so a reload after a release never quantises again. See `Docs/performance.md`.
actor ReloadableWeights<Modules: Sendable> {
    private let loading: WeightLoading<Modules>
    private var modules: Modules?
    private var isFilled = false
    /// How many unloads have been asked for, so a load that one follows knows its modules are already on their way out.
    private var unloadsAsked = 0
    /// The latest load or unload, which the next one waits for so they land in the order they were asked.
    private var last: Task<Void, Never>?

    init(loading: WeightLoading<Modules>) {
        self.loading = loading
    }

    /// Whether any unload has been asked for; internal so a test can wait for one.
    var hasPendingUnload: Bool { unloadsAsked > 0 }

    /// The modules with their weights read in, or nil when an unload was asked for before they landed.
    func load(from directory: URL) async throws -> Modules? {
        let asked = unloadsAsked
        let previous = last
        let step = Task { () throws -> Modules? in
            await previous?.value
            // A load an unload overtook, or one its caller stopped, reads nothing.
            guard self.unloadsAsked == asked else { return nil }
            try Task.checkCancellation()
            return try await self.fill(from: directory)
        }
        last = Task { _ = try? await step.value }
        let loaded = try await withTaskCancellationHandler(
            operation: { try await step.value }, onCancel: { step.cancel() })
        return unloadsAsked == asked ? loaded : nil
    }

    /// Lets the weights go and keeps the modules for the next load.
    func unload() async {
        unloadsAsked += 1
        let previous = last
        let step = Task {
            await previous?.value
            await self.drain()
        }
        last = step
        await step.value
    }

    /// Reads the weights into the modules, building them only when nothing was built before.
    private func fill(from directory: URL) async throws -> Modules {
        if let modules {
            if !isFilled {
                try await loading.refill(modules, directory)
                isFilled = true
            }
            return modules
        }
        let built = try await loading.build(directory)
        modules = built
        isFilled = true
        return built
    }

    /// Empties the modules when they hold weights.
    private func drain() async {
        guard let modules, isFilled else { return }
        isFilled = false
        await loading.empty(modules)
    }
}
