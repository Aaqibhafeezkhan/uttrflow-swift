import MLXLMCommon
import os
import Testing
import UttrflowPredict

@testable import UttrflowLocalModel

/// Counts what a scorer asks of the buffer cache, in the order it asks.
private final class CacheRecorder: Sendable {
    private let calls = OSAllocatedUnfairLock<[String]>(initialState: [])

    var recorded: [String] { calls.withLock { $0 } }

    var control: BufferCacheControl {
        BufferCacheControl(
            hold: { self.calls.withLock { $0.append("hold") } },
            clear: { self.calls.withLock { $0.append("clear") } })
    }
}

@Suite("The GPU buffer cache around a pass")
struct GPUBufferCacheTests {
    private let situation = GenerationSituation(application: "Mail", surroundings: "the draft looks fine")

    @Test("A generation pass caps the cache before it runs and empties it after")
    func generationHoldsThenClears() async throws {
        let recorder = CacheRecorder()
        let scorer = MLXCandidateScorer(model: .gemma3, maximumTokens: 16, bufferCache: recorder.control)
        for typed in ["Thanks for sending", "Could we move the review to ", "Sounds good, let"] {
            _ = try await scorer.completions(for: typed, in: situation)
        }
        #expect(recorder.recorded == Array(repeating: ["hold", "clear"], count: 3).flatMap { $0 })
    }

    @Test("Every other way into the model does the same")
    func everyEntryHoldsThenClears() async throws {
        let recorder = CacheRecorder()
        let scorer = MLXCandidateScorer(model: .gemma3, maximumTokens: 16, bufferCache: recorder.control)
        _ = try await scorer.pass(for: "git che", in: situation)
        _ = try await scorer.alternatives(for: "git che", in: situation, excluding: "git checkout")
        _ = await scorer.judgedTokens(of: "git checkout main", following: "git che")
        _ = await scorer.logLikelihood(of: "git checkout main", following: "git che")
        #expect(recorder.recorded == Array(repeating: ["hold", "clear"], count: 4).flatMap { $0 })
    }

    @Test("A pass cancelled before it starts still empties the cache")
    func cancelledPassClears() async {
        let recorder = CacheRecorder()
        let scorer = MLXCandidateScorer(model: .gemma3, maximumTokens: 16, bufferCache: recorder.control)
        let situation = situation
        let work = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await scorer.completions(for: "Thanks for sending", in: situation)
        }
        _ = try? await work.value
        #expect(recorder.recorded == ["hold", "clear"])
    }

    @Test("Loading the model caps the cache and empties it after, even when the load fails")
    func loadHoldsThenClears() async throws {
        let cache = try FakeCache()
        try cache.addConfiguration()
        try cache.add("model.safetensors", FakeCache.weights(bytes: 512))
        let recorder = CacheRecorder()
        let scorer = MLXCandidateScorer(
            model: cache.model(), maximumTokens: 16, bufferCache: recorder.control, cache: cache.root)
        await #expect(throws: (any Error).self) { try await scorer.prepare() }
        #expect(recorder.recorded == ["hold", "clear"])
        #expect(await scorer.isReady == false)
    }

    @Test("Releasing the model empties the cache and leaves nothing to answer with")
    func releaseClears() async {
        let recorder = CacheRecorder()
        let scorer = MLXCandidateScorer(model: .gemma3, maximumTokens: 16, bufferCache: recorder.control)
        await scorer.release()
        #expect(recorder.recorded == ["clear"])
        #expect(await scorer.isReady == false)
    }

    @Test("The cap is a quarter of a gigabyte")
    func limitIsMeasured() {
        #expect(GPUBufferCache.limit == 256 * 1_048_576)
    }
}

/// Counts builds and holds each one until the test lets it fail.
private final class GatedBuilds: Sendable {
    private let count = OSAllocatedUnfairLock(initialState: 0)
    private let gate: AsyncStream<Void>
    private let opener: AsyncStream<Void>.Continuation
    let started: AsyncStream<Void>
    private let starter: AsyncStream<Void>.Continuation

    init() {
        (gate, opener) = AsyncStream.makeStream()
        (started, starter) = AsyncStream.makeStream()
    }

    var builds: Int { count.withLock { $0 } }

    func open() { opener.finish() }

    var loading: WeightLoading<ModelContainer> {
        WeightLoading(
            build: { _ in
                self.count.withLock { $0 += 1 }
                self.starter.yield()
                for await _ in self.gate {}
                throw CancellationError()
            },
            refill: { _, _ in }, empty: { _ in })
    }
}

@Suite("Loading the scorer's weights")
struct ScorerLoadTests {
    @Test("Two callers at once share one load")
    func concurrentPreparesLoadOnce() async throws {
        let cache = try FakeCache()
        try cache.addConfiguration()
        try cache.add("model.safetensors", FakeCache.weights(bytes: 512))
        let builds = GatedBuilds()
        let scorer = MLXCandidateScorer(
            model: cache.model(), maximumTokens: 16, bufferCache: CacheRecorder().control, cache: cache.root,
            loading: builds.loading)
        let first = Task { try await scorer.prepare() }
        for await _ in builds.started { break }
        let second = Task { try await scorer.prepare() }
        for _ in 0..<200 { await Task.yield() }
        builds.open()
        _ = try? await first.value
        _ = try? await second.value
        #expect(builds.builds == 1)
    }
}
