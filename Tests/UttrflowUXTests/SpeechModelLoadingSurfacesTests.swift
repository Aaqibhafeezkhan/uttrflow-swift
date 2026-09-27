// Tests the home page, the menu bar and the clipboard panel while the speech model downloads or loads.
import Foundation
import Testing
import UttrflowCore
import UttrflowTestSupport

@testable import UttrflowUX

@Suite("Where a person would dictate, while the speech model loads")
struct SpeechModelLoadingSurfacesTests {
    /// The home page with every permission granted and the model at one point in its load.
    private func home(_ load: SpeechModelLoad?) -> HomePresentation {
        HomePresenter.page(
            for: HomeSnapshot(
                permissions: [.microphone: .granted, .accessibility: .granted],
                shortcut: "⌥Space", now: HistoryFixture.now, speechModel: load),
            calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)
    }

    @Test("the hero says the model is getting ready, with a sliding bar and the start pill dimmed")
    func homeShowsTheLoad() throws {
        let page = home(.loading(elapsed: .seconds(1)))
        let status = try #require(page.hero.modelStatus)

        #expect(status.title == "Getting ready…")
        #expect(status.subtitle == "Loading the speech model, usually a few seconds")
        #expect(status.tone == .dictation)
        #expect(status.progress == .sliding)
        #expect(status.action == nil, "the dimmed start pill stands where a button would")
        #expect(!page.hero.canStart)
        #expect(
            status.accessibilityLabel
                == "Loading the speech model. Dictation starts working as soon as it’s ready.")
        #expect(!page.status.isReady)
        #expect(page.status.text == "Loading speech model")
        #expect(page.nextStep == nil, "the hero is the only place the load is shown")
    }

    @Test("the hero gains the minutes only once the load has run on")
    func homeEstimateWaits() throws {
        let early = try #require(home(.loading(elapsed: .seconds(3))).hero.modelStatus)
        let late = try #require(home(.loading(elapsed: .seconds(90))).hero.modelStatus)

        #expect(!early.subtitle.contains("min"))
        #expect(late.subtitle == "First load after restart: about 2–3 min")
        #expect(late.accessibilityLabel.contains("2 to 3 minutes"))
    }

    @Test("the waveform comes back once the model has loaded")
    func homeClearsWhenLoaded() {
        let page = home(nil)

        #expect(page.hero.modelStatus == nil)
        #expect(page.hero.canStart)
        #expect(page.status == HomeStatus(text: "Ready", isReady: true))
        #expect(page.nextStep == nil)
    }

    @Test("a failed load says nothing was lost and offers an amber Try again that loads it again")
    func homeShowsTheFailure() throws {
        let page = home(.failed)
        let status = try #require(page.hero.modelStatus)

        #expect(status.title == "Speech model didn’t load")
        #expect(status.subtitle == "Nothing was lost. Try loading it again.")
        #expect(status.tone == .warning)
        #expect(status.progress == nil)
        #expect(status.action == MainAction(title: "Try again", intent: .recover(.retry)))
        #expect(status.actionTone == .warning)
        #expect(page.status.text == "Speech model didn’t load")
    }

    @Test("a missing permission keeps its card and still leaves the model's state in the hero")
    func permissionAndLoadBothShow() throws {
        let page = HomePresenter.page(
            for: HomeSnapshot(
                permissions: [.microphone: .denied], shortcut: "⌥Space", now: HistoryFixture.now,
                speechModel: .loading(elapsed: .seconds(1))),
            calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)

        #expect(page.nextStep != nil)
        #expect(page.status.text == "Not ready")
        #expect(try #require(page.hero.modelStatus).title == "Getting ready…")
        #expect(!page.hero.canStart)
    }

    @Test("readiness tells the load from the injected clock, and nothing once ready")
    func readinessTimesTheLoad() {
        let clock = ManualClock()
        let started = clock.now
        clock.advance(by: .seconds(12))
        let now = clock.now

        #expect(
            SpeechModelReadiness.loading.load(since: started, now: now) == .loading(elapsed: .seconds(12)))
        #expect(SpeechModelReadiness.loading.load(since: nil, now: now) == .loading(elapsed: .zero))
        #expect(SpeechModelReadiness.loadFailed.load(since: started, now: now) == .failed)
        #expect(SpeechModelReadiness.ready.load(since: started, now: now) == nil)
        #expect(SpeechModelReadiness.notInstalled.load(since: started, now: now) == .missing)
        #expect(
            SpeechModelReadiness.downloading(fractionCompleted: 0.5).load(since: started, now: now) == nil)
    }

    @Test("a missing model offers a teal Download speech model, puts the ring out and invites no talking")
    func homeShowsTheMissingModel() throws {
        let page = home(.missing)
        let status = try #require(page.hero.modelStatus)

        #expect(status.title == "Speech model not installed")
        #expect(status.subtitle == "Dictation needs it · works offline after")
        #expect(status.tone == .warning)
        #expect(
            status.action
                == MainAction(title: "Download speech model", intent: .recover(.downloadSpeechModel)))
        #expect(status.actionTone == .dictation)
        #expect(page.status == HomeStatus(text: "Speech model not downloaded", isReady: false))
        #expect(page.subtitle == "Uttrflow cannot listen yet.")
    }

    /// The home page with every permission granted while the model downloads.
    private func home(downloading fraction: Double) -> HomePresentation {
        HomePresenter.page(
            for: HomeSnapshot(
                permissions: [.microphone: .granted, .accessibility: .granted],
                shortcut: "⌥Space", now: HistoryFixture.now, speechDownload: fraction),
            calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)
    }

    @Test("a download shows its percentage, a bar filled to it, and the start pill dimmed")
    func homeShowsTheDownload() throws {
        let page = home(downloading: 0.42)
        let status = try #require(page.hero.modelStatus)

        #expect(status.title == "Setting up… 42%")
        #expect(status.subtitle == "Downloading the speech model")
        #expect(status.tone == .dictation)
        #expect(status.progress == .fraction(0.42))
        #expect(status.action == nil)
        #expect(status.accessibilityLabel == "Setting up. Downloading the speech model, 42 percent.")
        #expect(!page.hero.canStart)
        #expect(page.status == HomeStatus(text: "Setting up… 42%", isReady: false))
        #expect(page.subtitle == "Uttrflow cannot listen yet.")
    }

    @Test("a download's bar never runs past either end")
    func downloadIsClamped() {
        #expect(HomeModelStatus.downloading(1.4).progress == .fraction(1))
        #expect(HomeModelStatus.downloading(1.4).title == "Setting up… 100%")
        #expect(HomeModelStatus.downloading(-0.2).progress == .fraction(0))
    }

    @Test("a download under way outranks a load that has not started")
    func downloadOutranksTheLoad() throws {
        let snapshot = HomeSnapshot(
            shortcut: "⌥Space", now: HistoryFixture.now, speechModel: .missing, speechDownload: 0.1)

        #expect(try #require(snapshot.modelStatus).title == "Setting up… 10%")
    }

    @Test("readiness gives the download's share, zero while unmeasured, and nothing otherwise")
    func readinessGivesTheDownload() {
        #expect(SpeechModelReadiness.downloading(fractionCompleted: 0.3).download == 0.3)
        #expect(SpeechModelReadiness.downloading(fractionCompleted: nil).download == 0)
        #expect(SpeechModelReadiness.ready.download == nil)
        #expect(SpeechModelReadiness.loading.download == nil)
        #expect(SpeechModelReadiness.notInstalled.download == nil)
    }

    @Test("home and the menu bar say the same words during a download")
    func downloadAgreesWithTheMenuBar() {
        let readiness = SpeechModelReadiness.downloading(fractionCompleted: 0.42)
        let menu = MenuBarPresenter.present(MenuBarState(speechModel: readiness))

        #expect(home(downloading: 0.42).status.text == menu.statusLine)
        #expect(!MenuBarPresenter.canStartDictation(in: MenuBarState(speechModel: readiness)))
    }

    /// The Dictation page with every permission granted, nothing dictated, and the model at one point.
    private func dictation(_ load: SpeechModelLoad?) -> DictationPresentation {
        DictationPresenter.page(
            for: DictationSnapshot(
                permissions: [.microphone: .granted, .accessibility: .granted],
                shortcut: "⌥Space", now: HistoryFixture.now, speechModel: load),
            calendar: HistoryFixture.calendar, locale: HistoryFixture.locale)
    }

    @Test("the Dictation page says the model is missing in place of the invitation to talk")
    func dictationShowsTheMissingModel() throws {
        let empty = try #require(dictation(.missing).emptyState)

        #expect(empty.title == "The speech model isn’t downloaded")
        #expect(empty.action == MainAction(title: "Download", intent: .recover(.downloadSpeechModel)))
        #expect(!empty.message.contains("anywhere and talk"))
    }

    @Test("the Dictation page says a load is under way, with nothing to press")
    func dictationShowsTheLoad() throws {
        let empty = try #require(dictation(.loading(elapsed: .seconds(1))).emptyState)

        #expect(empty.title == "Loading the speech model…")
        #expect(empty.symbolName == "hourglass")
        #expect(empty.action == nil)
    }

    @Test("the Dictation page invites talking once the model is ready")
    func dictationInvitesOnceReady() throws {
        let empty = try #require(dictation(nil).emptyState)

        #expect(empty.message.contains("anywhere and talk"))
    }

    /// Two surfaces that disagree about whether dictation works leave the person to find out by trying.
    @Test(
        "home, the Dictation page and the menu bar agree on whether the model can dictate",
        arguments: [
            SpeechModelReadiness.notInstalled, .loading, .loadFailed, .ready,
        ])
    func surfacesAgree(readiness: SpeechModelReadiness) {
        let load = readiness.load(since: nil as ContinuousClock.Instant?, now: .now)
        let homeReady = home(load).status.isReady
        let dictationInvites = dictation(load).emptyState?.message.contains("anywhere and talk") == true
        let menuReady = MenuBarPresenter.canStartDictation(in: MenuBarState(speechModel: readiness))

        #expect(homeReady == (readiness == .ready))
        #expect(dictationInvites == homeReady)
        #expect(menuReady == homeReady)
        if let load {
            #expect(MenuBarPresenter.present(MenuBarState(speechModel: readiness)).statusLine != "Ready")
            #expect(home(load).status.text == load.status)
        }
    }

    @Test("the menu bar names a failed load rather than calling setup unfinished")
    func menuBarNamesTheFailure() {
        let menu = MenuBarPresenter.present(MenuBarState(speechModel: .loadFailed))

        #expect(menu.statusLine == "Speech model didn't load")
        #expect(!MenuBarPresenter.canStartDictation(in: MenuBarState(speechModel: .loadFailed)))
    }

    @Test("the clipboard panel's microphone says loading, not downloading, during a load")
    func panelSaysLoading() {
        var snapshot = PanelFixture.panel()
        snapshot.dictation = .unavailable(.modelLoading)
        let mic = PanelPresenter.present(snapshot).microphone

        #expect(!mic.isEnabled)
        #expect(mic.label == "The speech model is still loading")
        #expect(mic.status == "Speech model still loading")
    }
}
