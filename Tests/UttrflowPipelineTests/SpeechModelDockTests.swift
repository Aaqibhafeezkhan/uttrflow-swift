// Tests what the floating button shows while the speech model downloads or loads, and after it failed to.
import Testing

@testable import UttrflowCore
@testable import UttrflowPipeline

@Suite("The floating button during the speech model's load")
struct SpeechModelDockTests {
    @Test("resting during a load says it is getting ready, with no minutes in its first seconds")
    func restingShowsTheLoad() {
        let dock = DictationPresenter.dock(for: .idle, speechModel: .loading(elapsed: .seconds(2)))

        #expect(dock.setup == .loading)
        #expect(dock.primaryLine == "Getting ready…")
        #expect(dock.secondaryLine == nil)
        #expect(dock.action == nil)
        #expect(!dock.showsProgress, "the spinner ring is the setup form's, not the working orb")
        #expect(!dock.accessibilityLabel.contains("minutes"))
    }

    @Test("keeps the minutes for the pointer and VoiceOver once the load has run long enough to need them")
    func longLoadGivesTheEstimate() {
        let dock = DictationPresenter.dock(for: .idle, speechModel: .loading(elapsed: .seconds(30)))

        #expect(dock.primaryLine == "Getting ready…")
        #expect(dock.secondaryLine == "First load after restart: about 2–3 min")
        #expect(dock.accessibilityLabel.contains("2 to 3 minutes"))
    }

    @Test("resting after a failed load says so and offers Retry, which loads it again")
    func failedLoadOffersRetry() {
        let dock = DictationPresenter.dock(for: .idle, speechModel: .failed)

        #expect(dock.setup == .failed)
        #expect(dock.primaryLine == "Speech model didn’t load")
        #expect(dock.action == .retry)
        #expect(dock.setup?.actionTitle == "Retry")
        #expect(dock.accessibilityLabel.hasSuffix("Try loading it again."))
    }

    @Test("resting with no model on disk says one is needed and offers Download")
    func missingModelOffersDownload() {
        let dock = DictationPresenter.dock(for: .idle, speechModel: .missing)

        #expect(dock.setup == .missing)
        #expect(dock.primaryLine == "Speech model needed")
        #expect(dock.action == .downloadSpeechModel)
        #expect(dock.setup?.actionTitle == "Download")
        #expect(dock.accessibilityLabel.hasPrefix("The speech model isn’t downloaded."))
    }

    @Test("resting during a download says it is setting up, with the percentage beside a ring")
    func downloadShowsItsShare() {
        let dock = DictationPresenter.dock(for: .idle, speechModel: nil, download: 0.42)

        #expect(dock.setup == .downloading(0.42))
        #expect(dock.primaryLine == "Setting up")
        #expect(dock.secondaryLine == "42%")
        #expect(dock.action == nil)
        #expect(dock.setup?.actionTitle == nil)
        #expect(dock.accessibilityLabel == "Setting up. Downloading the speech model, 42 percent.")
    }

    @Test("a download's ring never runs past either end")
    func downloadIsClamped() {
        #expect(DictationPresenter.dock(for: .idle, speechModel: nil, download: 1.3).setup == .downloading(1))
        #expect(DictationPresenter.dock(for: .idle, speechModel: nil, download: -1).secondaryLine == "0%")
        #expect(DockModelSetup.percentage(of: 0.426) == 43)
    }

    @Test("a dictation under way is never covered by a download")
    func downloadLeavesBusyStatesAlone() {
        let recording = DictationPresenter.dock(for: .recording, speechModel: nil, download: 0.5)

        #expect(recording == DictationPresenter.dock(for: .recording))
        #expect(recording.setup == nil)
    }

    @Test("a failure while no model is on disk keeps exactly its own form")
    func missingLeavesFailuresAlone() {
        let failure = DictationFailure(SpeechEngineError.modelLoadFailed(description: "fixture"))

        #expect(
            DictationPresenter.dock(for: .failed(failure), speechModel: .missing)
                == DictationPresenter.dock(for: .failed(failure)))
    }

    @Test("a refused attempt is drawn wide, with its words and why")
    func refusalIsDrawnWithWords() {
        let dock = DictationPresenter.dock(
            for: .failed(.stillLoading), speechModel: .loading(elapsed: .seconds(40)))

        #expect(dock.symbolName == "hourglass", "the quiet disc would drop the sentence")
        #expect(dock.primaryLine == "Speech model still loading…")
        #expect(dock.secondaryLine == "First load after restart: about 2–3 min")
        #expect(dock.accessibilityLabel.hasPrefix("Loading the speech model."))
    }

    @Test("the refusal still reads without the load beside it")
    func refusalAlone() {
        let dock = DictationPresenter.dock(for: .failed(.stillLoading))

        #expect(dock.primaryLine == "Speech model still loading…")
        #expect(dock.accessibilityLabel == "Speech model still loading.")
    }

    @Test("a failure with words to salvage keeps its own second line")
    func salvagedWordsKeepTheirLine() {
        let failure = DictationFailure(
            message: "Couldn’t tidy that.", recovery: .pasteManually, severity: .degraded,
            transcript: "The words.")
        let dock = DictationPresenter.dock(for: .failed(failure), speechModel: .failed)

        #expect(dock == DictationPresenter.dock(for: .failed(failure)))
    }

    @Test("another failure during the load keeps its button and gains the reason")
    func otherFailureGainsTheReason() {
        let failure = DictationFailure(SpeechEngineError.modelLoadFailed(description: "fixture"))
        let dock = DictationPresenter.dock(for: .failed(failure), speechModel: .failed)

        #expect(dock.primaryLine == failure.message)
        #expect(dock.action == .retry)
        #expect(dock.secondaryLine == "Dictation can’t start without it")
        #expect(dock.accessibilityLabel.hasSuffix("Download it again to repair it."))
    }

    @Test(
        "once loaded, every state is drawn exactly as before",
        arguments: [
            DictationState.idle, .recording, .transcribing, .tidying, .inserting,
            .inserted(DictationOutcome(text: "Done.", method: .accessibility, cleanedBy: .rules)),
        ])
    func loadedChangesNothing(state: DictationState) {
        #expect(DictationPresenter.dock(for: state, speechModel: nil) == DictationPresenter.dock(for: state))
    }

    @Test("a dictation under way is never covered by the load")
    func busyStatesAreNotCovered() {
        let load = SpeechModelLoad.loading(elapsed: .seconds(60))
        #expect(DictationPresenter.dock(for: .recording, speechModel: load).isRecording)
        #expect(DictationPresenter.dock(for: .tidying, speechModel: load).showsProgress)
    }
}
