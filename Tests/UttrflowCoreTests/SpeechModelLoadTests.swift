// Tests the words every surface uses for the speech model's load, and when the minutes are said.
import Testing

@testable import UttrflowCore

@Suite("What is said while the speech model loads")
struct SpeechModelLoadTests {
    @Test(
        "a load in its first seconds claims no minutes, since a warm load is over in two",
        arguments: [Duration.zero, .seconds(2), .milliseconds(4_999)])
    func fastLoadClaimsNoMinutes(elapsed: Duration) {
        let load = SpeechModelLoad.loading(elapsed: elapsed)

        #expect(!load.showsEstimate)
        #expect(!load.message.contains("minute"))
        #expect(!load.detail.contains("min"))
        #expect(!load.accessibilityLabel.contains("minute"))
    }

    @Test(
        "a load that runs on gives the estimate, and says it is the first load after a restart",
        arguments: [Duration.seconds(5), .seconds(154)])
    func slowLoadGivesTheEstimate(elapsed: Duration) {
        let load = SpeechModelLoad.loading(elapsed: elapsed)

        #expect(load.showsEstimate)
        #expect(load.message.contains("first load after a restart can take about 2–3 minutes"))
        #expect(load.detail == "First load after restart: about 2–3 min")
    }

    @Test("says the speech model is loading, with nothing to press")
    func loadingCopy() {
        let load = SpeechModelLoad.loading(elapsed: .seconds(1))

        #expect(load.isLoading)
        #expect(load.title == "Loading the speech model…")
        #expect(load.message == "Dictation starts working as soon as it’s ready.")
        #expect(load.status == "Loading speech model")
        #expect(load.recovery == nil)
    }

    @Test("a first failed load says so and offers to load it again")
    func failedCopy() {
        let load = SpeechModelLoad.failed

        #expect(!load.isLoading)
        #expect(!load.showsEstimate)
        #expect(load.title == "The speech model didn’t load")
        #expect(load.line == "Speech model didn’t load")
        #expect(load.status == "Speech model didn’t load")
        #expect(load.recovery == .retry)
        #expect(load.message.contains("Try loading it again"))
    }

    @Test("a damaged model says so and offers a fresh download")
    func brokenCopy() {
        let load = SpeechModelLoad.broken

        #expect(!load.isLoading)
        #expect(load.title == "The speech model is damaged")
        #expect(load.line == "Speech model is damaged")
        #expect(load.status == "Speech model is damaged")
        #expect(load.recovery == .downloadSpeechModel)
        #expect(load.message.contains("Download it again"))
        #expect(load.accessibilityLabel.hasSuffix("Download it again to repair it."))
    }

    @Test("a missing model says it was never downloaded and offers the download")
    func missingCopy() {
        let load = SpeechModelLoad.missing

        #expect(!load.isLoading)
        #expect(!load.showsEstimate)
        #expect(load.title == "The speech model isn’t downloaded")
        #expect(load.line == "Speech model not downloaded")
        #expect(load.detail == "Dictation can’t start without it")
        #expect(load.status == "Speech model not downloaded")
        #expect(load.message == "Dictation can’t start without it. Download it to start dictating.")
        #expect(load.recovery == .downloadSpeechModel)
    }

    @Test("the spoken form carries no ellipsis and no dash a screen reader would skip")
    func spokenForm() {
        let label = SpeechModelLoad.loading(elapsed: .seconds(60)).accessibilityLabel

        #expect(!label.contains("…"))
        #expect(!label.contains("–"))
        #expect(label.hasPrefix("Loading the speech model, "))
        #expect(label.contains("about 1 minute left"))
        #expect(!SpeechModelLoad.loading(elapsed: .seconds(1)).accessibilityLabel.contains("minute"))
    }

    @Test("a load gives an estimate only once it has run past the silent first seconds")
    func loadGivesTheEstimate() {
        #expect(SpeechModelLoad.loading(elapsed: .seconds(4)).estimate == nil)
        #expect(
            SpeechModelLoad.loading(elapsed: .seconds(5)).estimate
                == SpeechModelLoadEstimate(elapsed: .seconds(5)))
        #expect(SpeechModelLoad.failed.estimate == nil)
        #expect(SpeechModelLoad.missing.estimate == nil)
    }

    @Test("VoiceOver hears the minutes written out once the estimate shows")
    func spokenLabel() {
        let label = SpeechModelLoad.loading(elapsed: .seconds(90)).accessibilityLabel

        #expect(
            label
                == "Loading the speech model, about 1 minute left. Dictation starts working as soon as it’s ready."
        )
        #expect(!label.contains("~"))
    }
}
