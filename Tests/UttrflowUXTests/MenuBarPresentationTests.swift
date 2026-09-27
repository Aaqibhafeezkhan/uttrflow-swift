import Testing
import UttrflowClipboard

@testable import UttrflowCore
@testable import UttrflowUX

// MARK: - Fixtures

/// A blocking failure: the microphone is off, so nothing can be dictated at all.
private let microphoneOff = FailurePresenter.present(PermissionError.microphoneDenied)

/// A degraded one: the words arrived, just on the clipboard rather than in the app.
private let clipboardFallback = FailurePresenter.present(
    TextInsertionError.insertionRejected(description: "read-only field"))

/// One with nothing to offer, to prove the menu does not invent a row for it.
private let noWayOut = FailurePresenter.present(AudioCaptureError.unsupportedInputFormat)

private let twoRecents = [
    MenuBarRecent(
        title: "Hey John, I'll probably be about 20 minutes…",
        fullText: "Hey John, I'll probably be about 20 minutes late, sorry."),
    MenuBarRecent(
        title: "The deployment is still running, so I'll…",
        fullText: "The deployment is still running, so I'll follow up this afternoon."),
]

extension MenuBarPresentation {
    /// The command whose intent is this one, if the menu is offering it at all.
    fileprivate func command(_ intent: MenuBarIntent) -> MenuBarCommand? {
        commands.first { $0.intent == intent }
    }

    fileprivate var titles: [String] { commands.map(\.title) }
}

// MARK: - The icon

@Suite("What the menu bar icon shows")
struct MenuBarIconTests {
    /// The icon is always on screen, so it carries the state for a user who never opens the menu.
    @Test("shows a different icon for resting, listening, working and done")
    func iconFollowsActivity() {
        let icons = DictationActivity.allCases.map {
            MenuBarPresenter.present(MenuBarState(activity: $0)).icon
        }
        #expect(
            icons == [
                .mark, .symbol("mic.fill"), .symbol("sparkles"), .symbol("checkmark"),
            ])
        #expect(Set(icons).count == DictationActivity.allCases.count)
    }

    /// Resting has nothing to report, so it says whose app this is; every other state has news.
    @Test("carries the mark only while nothing is happening")
    func restIsTheMark() {
        #expect(MenuBarPresenter.present(MenuBarState(activity: .idle)).icon == .mark)
        for activity in DictationActivity.allCases where activity != .idle {
            #expect(MenuBarPresenter.present(MenuBarState(activity: activity)).icon != .mark)
        }
    }

    @Test("overrides every activity when something needs fixing")
    func attentionOutranksActivity() {
        for activity in DictationActivity.allCases {
            let shown = MenuBarPresenter.present(
                MenuBarState(activity: activity, failure: microphoneOff))
            #expect(shown.icon == .symbol("exclamationmark.triangle.fill"))
            #expect(shown.isAttentionNeeded)
            #expect(shown.emphasis == .attention)
        }
    }

    /// A failure shown beside the work is already seen, and need not light the menu bar too.
    @Test("stays calm about a failure the floating button already reported")
    func degradedFailureDoesNotLightTheMenuBar() {
        let shown = MenuBarPresenter.present(MenuBarState(failure: clipboardFallback))
        #expect(!shown.isAttentionNeeded)
        #expect(shown.icon == .mark)
        // It is still the news of the moment, so it still leads the menu.
        #expect(shown.statusLine == clipboardFallback.headline)
    }

    @Test("marks a live microphone even with nothing wrong")
    func listeningIsItsOwnEmphasis() {
        #expect(MenuBarPresenter.present(MenuBarState(activity: .listening)).emphasis == .live)
        #expect(MenuBarPresenter.present(MenuBarState(activity: .idle)).emphasis == .normal)
        #expect(MenuBarPresenter.present(MenuBarState(activity: .finished)).emphasis == .normal)
    }
}

// MARK: - The status line

@Suite("What the menu bar says")
struct MenuBarStatusTests {
    @Test("names each moment in the user's words, not the machinery's")
    func statusLinePerActivity() {
        let lines = DictationActivity.allCases.map {
            MenuBarPresenter.present(MenuBarState(activity: $0)).statusLine
        }
        #expect(lines == ["Ready", "Listening…", "Tidying up…", "Inserted"])
    }

    /// "Ready" over an undownloaded model is found out by pressing the shortcut and getting nothing.
    @Test("says setting up rather than ready while the model is still coming")
    func setupOutranksReady() {
        #expect(
            MenuBarPresenter.present(MenuBarState(speechModel: .downloading(fractionCompleted: nil)))
                .statusLine == "Setting up…")
        #expect(
            MenuBarPresenter.present(
                MenuBarState(speechModel: .downloading(fractionCompleted: 0.42))
            ).statusLine == "Setting up… 42%")
        #expect(
            MenuBarPresenter.present(MenuBarState(speechModel: .notInstalled)).statusLine
                == "Speech model not downloaded")
    }

    /// A downloader reporting 140% is the downloader's bug, and not the menu bar's to show.
    @Test("keeps a nonsense percentage out of the menu bar")
    func percentageIsClamped() {
        #expect(MenuBarPresenter.percentage(of: -3) == 0)
        #expect(MenuBarPresenter.percentage(of: 1.4) == 100)
        #expect(MenuBarPresenter.percentage(of: 0.005) == 1)
    }

    @Test("leads with the failure, whatever else is happening")
    func failureOutranksEverything() {
        let shown = MenuBarPresenter.present(
            MenuBarState(
                activity: .listening, failure: microphoneOff,
                speechModel: .downloading(fractionCompleted: 0.5)))
        #expect(shown.statusLine == microphoneOff.headline)
    }

    /// VoiceOver reads a sentence built from the status line's own string, so the two cannot drift.
    @Test("says the same thing aloud that it says on screen")
    func accessibilityLabelFollowsTheStatusLine() {
        #expect(
            MenuBarPresenter.present(MenuBarState()).accessibilityLabel == "Uttrflow. Ready.")
        #expect(
            MenuBarPresenter.present(MenuBarState(activity: .listening)).accessibilityLabel
                == "Uttrflow. Listening.")
        #expect(
            MenuBarPresenter.present(MenuBarState(activity: .working)).accessibilityLabel
                == "Uttrflow. Tidying up.")
        // The failure's sentence ends in a full stop; a second is read out as a second pause.
        #expect(
            MenuBarPresenter.present(MenuBarState(failure: microphoneOff)).accessibilityLabel
                == "Uttrflow. \(microphoneOff.headline)")
    }
}

// MARK: - What the popover and its menu contain

@Suite("What the popover and its menu offer")
struct MenuBarContentsTests {
    /// Talk, Clipboard, Settings and Home, left to right, with only Talk on the white disc.
    @Test("lays the round buttons out the way the design does")
    func buttonOrder() {
        let shown = MenuBarPresenter.present(MenuBarState())
        #expect(shown.buttons.map(\.command.title) == ["Talk", "Clipboard", "Settings", "Home"])
        #expect(
            shown.buttons.map(\.command.intent) == [
                .startDictation, .openClipboard, .open(.settings(.general)), .open(.main(.home)),
            ])
        #expect(shown.buttons.map(\.isPrimary) == [true, false, false, false])
        #expect(shown.buttons.map(\.symbolName) == ["mic", "clipboard", "gearshape", "square.grid.2x2"])
    }

    /// The right-click menu holds what the popover has no room for, with Quit always last.
    @Test("puts the switches, the windows and Quit in the right-click menu")
    func rightClickMenuOrder() {
        let shown = MenuBarPresenter.present(MenuBarState())
        let titles = shown.items.compactMap {
            if case .command(let command) = $0 { command.title } else { nil }
        }
        #expect(
            titles == [
                "Dictation", "Clipboard", "AI Suggestions", "Open Uttrflow", "Settings…", "Quit Uttrflow",
            ])
        guard case .status = shown.items.first else {
            Issue.record("the menu does not begin with the status line")
            return
        }
        #expect(shown.items.contains(.sectionHeader("Turn on and off")))
    }

    /// Update checks live in Settings, so neither the popover nor its menu offers one.
    @Test("offers no update check")
    func noUpdateCheck() {
        let shown = MenuBarPresenter.present(MenuBarState(updateProgress: .idle))
        #expect(!shown.commands.map(\.title).contains { $0.contains("Update") })
    }

    /// The problem and its fix sit together in the header, with nothing between them to hunt past.
    @Test("puts the one fix beside the problem")
    func recoverySitsBesideTheProblem() {
        let shown = MenuBarPresenter.present(MenuBarState(failure: microphoneOff))
        guard case .status(let status) = shown.header, let fix = status.action else {
            Issue.record("the header carries no fix")
            return
        }
        #expect(status.title == microphoneOff.headline)
        #expect(status.emphasis == .attention)
        #expect(fix.title == "Open System Settings…")
        #expect(fix.intent == .recover(.openSystemSettings(.microphone)))
        #expect(fix.isEnabled)
    }

    /// A failure's own fix wins the pill, so the header never offers two at once.
    @Test("puts a failure's fix ahead of the download")
    func failureFixWinsOverSetup() {
        let shown = MenuBarPresenter.present(MenuBarState(failure: microphoneOff, speechModel: .notInstalled))
        #expect(shown.command(.recover(.openSystemSettings(.microphone))) != nil)
        #expect(shown.command(.recover(.downloadSpeechModel)) == nil)
    }

    /// A failure with nothing to offer leaves the pill to the download, so a missing model is never a dead end.
    @Test("offers the download beside a failure that has no fix of its own")
    func setupFillsAnEmptyFix() {
        let shown = MenuBarPresenter.present(MenuBarState(failure: noWayOut, speechModel: .notInstalled))
        #expect(shown.command(.recover(.downloadSpeechModel))?.title == "Download")
    }

    /// A row that opens something else gets an ellipsis; the banner button stays plain either way.
    @Test("adds the ellipsis only where a menu should")
    func menuTitleEllipsis() {
        let shown = MenuBarPresenter.present(MenuBarState(failure: clipboardFallback))
        #expect(shown.command(.recover(.pasteManually))?.title == "Dismiss")
        #expect(clipboardFallback.action?.title == "Dismiss")
    }

    @Test("offers nothing extra for a failure that has no fix")
    func noFixMeansNoPill() {
        let shown = MenuBarPresenter.present(MenuBarState(failure: noWayOut))
        #expect(shown.statusLine == noWayOut.headline)
        #expect(shown.commands.allSatisfy { if case .recover = $0.intent { false } else { true } })
    }

    /// A failure that says why nothing happened is drawn calm, not as a fault.
    @Test("draws an informational failure in teal")
    func informationalIsCalm() {
        let nothingHeard = FailurePresentation(
            headline: "Nothing heard", detail: "Try again closer to the microphone.",
            symbolName: "waveform", severity: .informational, placement: .floatingButton, action: nil)
        let shown = MenuBarPresenter.present(MenuBarState(failure: nothingHeard))
        #expect(
            shown.header
                == .status(
                    MenuBarStatus(title: "Nothing heard", detail: "Try again closer to the microphone.")))
    }

    /// The popover names a ``Destination`` and the app owns the windows, so no callback is added.
    @Test("asks for a window by naming the place, not by opening it")
    func windowsAreNamedAsDestinations() {
        let shown = MenuBarPresenter.present(MenuBarState())
        #expect(shown.command(.open(.main(.home)))?.title == "Home")
        #expect(shown.command(.open(.settings(.general)))?.title == "Settings")
        let menu = shown.items.compactMap { if case .command(let command) = $0 { command } else { nil } }
        #expect(menu.first { $0.intent == .open(.main(.home)) }?.title == "Open Uttrflow")
        #expect(menu.first { $0.intent == .open(.settings(.general)) }?.title == "Settings…")
    }

    /// Every shortcut the right-click menu prints.
    @Test("prints the shortcuts the design prints")
    func shortcuts() {
        let shown = MenuBarPresenter.present(MenuBarState())
        let menu = shown.items.compactMap { if case .command(let command) = $0 { command } else { nil } }
        // ⌃⌥ held has no key to print, so only an earlier install's ⌥Space shows beside Start.
        #expect(shown.command(.startDictation)?.shortcut == nil)
        var earlier = MenuBarState()
        earlier.shortcuts = .earlierDefault
        #expect(
            MenuBarPresenter.present(earlier).command(.startDictation)?.shortcut
                == MenuBarShortcut(key: " ", modifiers: .option))
        #expect(
            menu.first { $0.intent == .open(.main(.home)) }?.shortcut
                == MenuBarShortcut(key: "0", modifiers: .command))
        #expect(
            menu.first { $0.intent == .open(.settings(.general)) }?.shortcut
                == MenuBarShortcut(key: ",", modifiers: .command))
        #expect(shown.command(.quit)?.shortcut == MenuBarShortcut(key: "q", modifiers: .command))
    }

    /// Quitting works whatever else is broken, so no icon is left with nothing to do about it.
    @Test("always lets the user leave")
    func quitIsAlwaysAvailable() {
        for failure in [microphoneOff, clipboardFallback, noWayOut] {
            let shown = MenuBarPresenter.present(
                MenuBarState(activity: .working, failure: failure, speechModel: .notInstalled))
            #expect(shown.command(.quit)?.isEnabled == true)
            #expect(shown.command(.open(.main(.home)))?.isEnabled == true)
            #expect(shown.command(.open(.settings(.general)))?.isEnabled == true)
        }
    }
}

// MARK: - The header

@Suite("The popover's header")
struct MenuBarHeaderTests {
    @Test("hints at the bound shortcut while nothing else needs saying")
    func hintAtRest() {
        var state = MenuBarState()
        state.shortcuts = ShortcutSet([.dictate: [HotkeyBinding(keyCode: 2, modifiers: [.control, .option])]])
        let shown = MenuBarPresenter.present(state)
        #expect(shown.header == .hint(MenuBarHint(verb: "hold", keys: "⌃⌥D")))
    }

    @Test("says press when the shortcut toggles")
    func pressWhenToggling() {
        let shown = MenuBarPresenter.present(MenuBarState(activation: .pressToToggle))
        #expect(shown.header == .hint(MenuBarHint(verb: "press", keys: "⌃⌥")))
    }

    @Test("falls back to fn when nothing is bound")
    func fnWhenUnbound() {
        var state = MenuBarState()
        state.shortcuts = ShortcutSet([:])
        #expect(MenuBarPresenter.hint(for: state).keys == "fn")
    }

    @Test("keeps the hint once the words have gone in")
    func hintAfterInsertion() {
        let shown = MenuBarPresenter.present(MenuBarState(activity: .finished))
        guard case .hint = shown.header else {
            Issue.record("a finished dictation replaced the hint")
            return
        }
    }

    @Test("says it is listening in red, and working in teal")
    func activityStatus() {
        #expect(
            MenuBarPresenter.present(MenuBarState(activity: .listening)).header
                == .status(MenuBarStatus(title: "Listening…", emphasis: .live)))
        #expect(
            MenuBarPresenter.present(MenuBarState(activity: .working)).header
                == .status(MenuBarStatus(title: "Tidying up…")))
    }

    @Test("counts a download with a bar, and slides one while the fraction is unknown")
    func settingUp() {
        let shown = MenuBarPresenter.present(MenuBarState(speechModel: .downloading(fractionCompleted: 0.42)))
        #expect(
            shown.header
                == .status(
                    MenuBarStatus(
                        title: "Setting up… 42%", detail: "Downloading the speech model",
                        progress: .fraction(0.42))))
        let unknown = MenuBarPresenter.present(
            MenuBarState(speechModel: .downloading(fractionCompleted: nil)))
        guard case .status(let status) = unknown.header else {
            Issue.record("no status while downloading")
            return
        }
        #expect(status.progress == .indeterminate)
        #expect(status.title == "Setting up…")
    }

    @Test("clamps a nonsense fraction before it reaches the bar")
    func fractionIsClamped() {
        let shown = MenuBarPresenter.present(MenuBarState(speechModel: .downloading(fractionCompleted: 1.7)))
        guard case .status(let status) = shown.header else {
            Issue.record("no status while downloading")
            return
        }
        #expect(status.progress == .fraction(1))
    }

    @Test("slides a bar while the model loads")
    func gettingReady() {
        let shown = MenuBarPresenter.present(MenuBarState(speechModel: .loading))
        #expect(
            shown.header
                == .status(
                    MenuBarStatus(
                        title: "Getting ready…", detail: "Loading the speech model", progress: .indeterminate)
                ))
    }

    @Test("offers one amber Try again when the model did not load")
    func didNotLoad() {
        let shown = MenuBarPresenter.present(MenuBarState(speechModel: .loadFailed))
        #expect(
            shown.header
                == .status(
                    MenuBarStatus(
                        title: "Model didn’t load", detail: "Nothing was lost", emphasis: .attention,
                        action: MenuBarCommand(title: "Try again", intent: .recover(.retry)),
                        actionEmphasis: .attention)))
    }

    @Test(
        "offers Download again, not another reload, once the model is incomplete or failed twice",
        arguments: [SpeechModelReadiness.loadFailedAgain, .incomplete])
    func damaged(readiness: SpeechModelReadiness) {
        let shown = MenuBarPresenter.present(MenuBarState(speechModel: readiness))
        #expect(
            shown.header
                == .status(
                    MenuBarStatus(
                        title: "Model is damaged", detail: "Download it again to repair it",
                        emphasis: .attention,
                        action: MenuBarCommand(
                            title: "Download again", intent: .recover(.downloadSpeechModel)),
                        actionEmphasis: .attention)))
    }

    @Test("offers one teal Download, with the real size, when the model is missing")
    func needed() {
        let shown = MenuBarPresenter.present(
            MenuBarState(speechModel: .notInstalled, speechModelBytes: 645_668_913))
        #expect(
            shown.header
                == .status(
                    MenuBarStatus(
                        title: "Speech model needed", detail: "646 MB · works offline after",
                        emphasis: .attention,
                        action: MenuBarCommand(title: "Download", intent: .recover(.downloadSpeechModel)),
                        actionEmphasis: .normal)))
        let unsized = MenuBarPresenter.present(MenuBarState(speechModel: .notInstalled))
        guard case .status(let status) = unsized.header else {
            Issue.record("no status for a missing model")
            return
        }
        #expect(status.detail == "Works offline after")
    }

    @Test("dims Talk in every one of the four model states")
    func talkDimmedDuringSetup() {
        let states: [SpeechModelReadiness] = [
            .downloading(fractionCompleted: 0.4), .loading, .loadFailed, .notInstalled,
        ]
        for readiness in states {
            let talk = MenuBarPresenter.present(MenuBarState(speechModel: readiness)).buttons.first
            #expect(talk?.command.isEnabled == false)
        }
    }

    @Test("reads a download's size the way a person does, never undersold")
    func sizes() {
        #expect(MenuBarPresenter.size(of: 645_668_913) == "646 MB")
        #expect(MenuBarPresenter.size(of: 1_000_000) == "1 MB")
        #expect(MenuBarPresenter.size(of: 1_400_000_000) == "1.4 GB")
        #expect(MenuBarPresenter.size(of: 1_400_000_001) == "1.5 GB")
        #expect(MenuBarPresenter.size(of: -5) == "0 MB")
    }

    @Test("draws an update's progress as the model's is drawn")
    func updateProgress() {
        #expect(MenuBarPresenter.progress(of: .idle) == nil)
        #expect(MenuBarPresenter.progress(of: .readyToInstall) == nil)
        #expect(MenuBarPresenter.progress(of: .checking) == .indeterminate)
        #expect(MenuBarPresenter.progress(of: .installing) == .indeterminate)
        #expect(MenuBarPresenter.progress(of: .downloading(fraction: nil)) == .indeterminate)
        #expect(MenuBarPresenter.progress(of: .downloading(fraction: 0.5)) == .fraction(0.5))
        let shown = MenuBarPresenter.present(MenuBarState(updateProgress: .downloading(fraction: 0.5)))
        #expect(
            shown.header == .status(MenuBarStatus(title: "Downloading update… 50%", progress: .fraction(0.5)))
        )
    }
}

// MARK: - What may be chosen

@Suite("What the popover lets the user do")
struct MenuBarEnablementTests {
    /// Disabled rather than failing silently, which is what a refused microphone would look like.
    @Test("refuses to start a dictation that cannot happen")
    func startDictationEnablement() {
        #expect(MenuBarPresenter.canStartDictation(in: MenuBarState()))
        #expect(MenuBarPresenter.canStartDictation(in: MenuBarState(activity: .finished)))

        // Already dictating.
        #expect(!MenuBarPresenter.canStartDictation(in: MenuBarState(activity: .listening)))
        #expect(!MenuBarPresenter.canStartDictation(in: MenuBarState(activity: .working)))
        // A permission in the way.
        #expect(!MenuBarPresenter.canStartDictation(in: MenuBarState(failure: microphoneOff)))
        // Nothing to transcribe with yet.
        #expect(!MenuBarPresenter.canStartDictation(in: MenuBarState(speechModel: .notInstalled)))
        #expect(
            !MenuBarPresenter.canStartDictation(
                in: MenuBarState(speechModel: .downloading(fractionCompleted: 0.9))))
    }

    /// A degraded failure keeps dictation, which is the whole of what degraded means.
    @Test("still lets a degraded failure be dictated past")
    func degradedFailureDoesNotBlock() {
        #expect(MenuBarPresenter.canStartDictation(in: MenuBarState(failure: clipboardFallback)))
        let shown = MenuBarPresenter.present(MenuBarState(failure: clipboardFallback))
        #expect(shown.command(.startDictation)?.isEnabled == true)
    }

    @Test("greys Talk rather than hiding it")
    func talkIsAlwaysPresent() {
        let shown = MenuBarPresenter.present(
            MenuBarState(activity: .idle, failure: microphoneOff, speechModel: .notInstalled))
        #expect(shown.command(.startDictation)?.isEnabled == false)
        #expect(shown.buttons.first?.command.title == "Talk")
    }

    /// A dictation begun from the popover is endable from the popover, not only by the shortcut.
    @Test("turns Talk into Stop while listening")
    func stopIsOfferedWhileListening() {
        let shown = MenuBarPresenter.present(MenuBarState(activity: .listening))
        #expect(shown.buttons.first?.command.title == "Stop")
        #expect(shown.buttons.first?.symbolName == "stop.fill")
        #expect(shown.command(.startDictation) == nil)
        #expect(shown.command(.stopDictation)?.isEnabled == true)
    }

    /// A blocking failure does not grey out the only thing that closes an open microphone.
    @Test("still offers stop when a blocking failure would refuse a start")
    func stopSurvivesABlockingFailure() {
        let shown = MenuBarPresenter.present(
            MenuBarState(activity: .listening, failure: microphoneOff, speechModel: .notInstalled))
        #expect(shown.command(.stopDictation)?.isEnabled == true)
    }

    /// Transcription cannot be interrupted, so an enabled Stop would do nothing at all.
    @Test("offers no stop once the words are being worked on")
    func noStopWhileWorking() {
        let shown = MenuBarPresenter.present(MenuBarState(activity: .working))
        #expect(shown.command(.stopDictation) == nil)
        #expect(shown.command(.startDictation)?.isEnabled == false)
    }

    /// No greyed "No recent dictations" row, which spends a line saying what is already visible.
    @Test("leaves out Last dictation entirely when there is none")
    func noRecentsMeansNoSection() {
        let shown = MenuBarPresenter.present(MenuBarState())
        #expect(shown.lastDictation == nil)
        #expect(shown.commands.allSatisfy { if case .insertRecent = $0.intent { false } else { true } })
    }

    /// One row only, the newest, however many the list keeps.
    @Test("shows only the newest dictation, pasting it on click and copying it on request")
    func lastDictationIsTheNewest() {
        let shown = MenuBarPresenter.present(MenuBarState(recents: twoRecents))
        #expect(
            shown.lastDictation
                == MenuBarRow(
                    title: twoRecents[0].title, tooltip: twoRecents[0].fullText,
                    insert: MenuBarCommand(
                        title: "Paste", intent: .insertRecent(index: 0), tooltip: twoRecents[0].fullText),
                    copy: MenuBarCommand(
                        title: "Copy", intent: .copyRecent(index: 0), tooltip: twoRecents[0].fullText)))
        #expect(shown.command(.insertRecent(index: 1)) == nil)
    }

    /// Reaching for an old dictation mid-insertion would race the one already on its way.
    @Test("will not paste a row in the middle of a dictation")
    func rowsAreDisabledWhileBusy() {
        let clips = [PanelFixture.clip("The first thing")]
        for activity in [DictationActivity.listening, .working] {
            let shown = MenuBarPresenter.present(
                MenuBarState(activity: activity, recents: twoRecents, clips: clips))
            #expect(shown.command(.insertRecent(index: 0))?.isEnabled == false)
            #expect(shown.command(.copyRecent(index: 0))?.isEnabled == false)
            #expect(shown.command(.insertClip(index: 0))?.isEnabled == false)
        }
        for activity in [DictationActivity.idle, .finished] {
            let shown = MenuBarPresenter.present(
                MenuBarState(activity: activity, recents: twoRecents, clips: clips))
            #expect(shown.command(.insertRecent(index: 0))?.isEnabled == true)
            #expect(shown.command(.insertClip(index: 0))?.isEnabled == true)
        }
    }

    /// Two presentations of one moment compare equal, which is how redrawing is decided.
    @Test("presents the same state as the same thing twice")
    func presentationsAreValues() {
        let state = MenuBarState(activity: .listening, recents: twoRecents)
        #expect(MenuBarPresenter.present(state) == MenuBarPresenter.present(state))
        #expect(MenuBarPresenter.present(state) != MenuBarPresenter.present(MenuBarState()))
    }

    /// The status line is a label, and a clickable label is a promise the menu cannot keep.
    @Test("never makes the status line clickable")
    func statusLineIsNotACommand() {
        let shown = MenuBarPresenter.present(MenuBarState(failure: microphoneOff))
        #expect(shown.items.contains(.status(text: microphoneOff.headline, emphasis: .attention)))
        #expect(!shown.commands.map(\.title).contains(microphoneOff.headline))
    }
}

// MARK: - The clipboard list

@Suite("The popover's clipboard list")
struct MenuBarClipListTests {
    private func clips(_ count: Int) -> [Clip] {
        (0..<count).map { PanelFixture.clip("Clip number \($0)", minutesAgo: $0) }
    }

    @Test("shows the five newest, each by its position")
    func fiveNewest() {
        let shown = MenuBarPresenter.present(MenuBarState(clips: clips(7)))
        #expect(shown.clips.map(\.title) == (0..<5).map { "Clip number \($0)" })
        #expect(shown.clips.map(\.insert.intent) == (0..<5).map { .insertClip(index: $0) })
        #expect(shown.clips.map(\.copy.intent) == (0..<5).map { .copyClip(index: $0) })
    }

    @Test("is absent while the clipboard is switched off")
    func absentWhenOff() {
        let shown = MenuBarPresenter.present(
            MenuBarState(clips: clips(3), features: MenuBarFeatures(clipboard: false)))
        #expect(shown.clips.isEmpty)
    }

    @Test("shows the first line of a clip, and the whole of it as the tooltip")
    func firstLine() {
        let clip = PanelFixture.clip("Line one\nLine two")
        let row = MenuBarPresenter.present(MenuBarState(clips: [clip])).clips.first
        #expect(row?.title == "Line one")
        #expect(row?.tooltip == "Line one\nLine two")
    }

    @Test("masks a secret and gives it no tooltip")
    func secretIsMasked() {
        let secret = PanelFixture.clip("AKIAIOSFODNN7EXAMPLE", kind: .secret)
        let row = MenuBarPresenter.present(MenuBarState(clips: [secret])).clips.first
        #expect(row?.title == PanelPresenter.mask)
        #expect(row?.tooltip == nil)
    }

    @Test("names a picture by its size")
    func pictureIsNamed() {
        let picture = Clip(
            text: "", kind: .image, copiedAt: PanelFixture.now,
            image: ClipImage(file: "a.png", width: 1200, height: 800, bytes: 10))
        #expect(MenuBarPresenter.title(of: picture) == "Picture · 1200 × 800")
    }
}

/// A printed shortcut is a promise about which keys do the thing; these keep it.
@Suite("What the menu's shortcuts say")
struct MenuBarShortcutTests {
    @Test("the clipboard is reachable from the menu, with its real shortcut")
    func clipboardShortcut() {
        let shown = MenuBarPresenter.present(MenuBarState())
        guard let clipboard = shown.command(.openClipboard) else {
            Issue.record("the popover has no way to the clipboard")
            return
        }
        #expect(clipboard.title == "Clipboard")
        #expect(clipboard.shortcut?.key == "v")
        #expect(clipboard.shortcut?.modifiers == [.command, .shift])
    }

    /// #142: a printed shortcut is a promise that pressing it will reach Uttrflow.
    @Test("an unarmed clipboard shortcut is not advertised")
    func unarmedClipboardShortcut() {
        let shown = MenuBarPresenter.present(MenuBarState(unarmedShortcuts: [.clipboard]))
        guard let clipboard = shown.command(.openClipboard) else {
            Issue.record("the popover has no way to the clipboard")
            return
        }
        #expect(clipboard.title == "Clipboard")
        #expect(clipboard.shortcut == nil)
    }

    /// Shift is named rather than left to a set comparison, which passes even when it is ignored.
    @Test("shift is a modifier this model can express")
    func shiftIsExpressible() {
        let both: MenuBarModifiers = [.command, .shift]
        #expect(both.contains(.shift))
        #expect(both.contains(.command))
        #expect(!both.contains(.option))
    }

    /// A duplicate value would silently bind two modifiers to one AppKit flag.
    @Test("every modifier is a distinct single value, and answers to itself")
    func everyModifierIsItsOwn() {
        let each = MenuBarModifier.allCases.map { MenuBarModifiers.one($0) }
        #expect(Set(each.map(\.rawValue)).count == MenuBarModifier.allCases.count)
        for modifier in MenuBarModifier.allCases {
            #expect(MenuBarModifiers.one(modifier).contains(modifier))
            for other in MenuBarModifier.allCases where other != modifier {
                #expect(!MenuBarModifiers.one(modifier).contains(other))
            }
        }
    }
}

/// Saying that an update is happening, which it never did before.
@Suite("Updating, in the menu bar")
struct MenuBarUpdateTests {
    private func line(_ progress: UpdateProgress) -> String {
        MenuBarPresenter.present(MenuBarState(updateProgress: progress)).statusLine
    }

    @Test("an install about to happen says so")
    func installingIsVisible() {
        #expect(line(.installing) == "Updating…")
    }

    /// The wait is named, since "Ready" with nothing happening for a minute looks stuck.
    @Test("a staged update says what it is waiting for")
    func readyExplainsTheWait() {
        #expect(line(.readyToInstall).contains("when you pause"))
    }

    @Test("a download reports its progress, and copes with not knowing it yet")
    func downloading() {
        #expect(line(.downloading(fraction: 0.42)) == "Downloading update… 42%")
        #expect(line(.downloading(fraction: nil)) == "Downloading update…")
    }

    @Test("nothing happening says nothing about updates")
    func idleIsSilent() {
        #expect(line(.idle) == "Ready")
    }

    /// A failure is why the menu was opened, so an update does not get to hide one.
    @Test("a failure still outranks an update")
    func failureWins() {
        var state = MenuBarState(updateProgress: .installing)
        state.failure = FailurePresentation(
            headline: "Something went wrong", detail: nil, symbolName: "exclamationmark.triangle",
            severity: .blocking, placement: .menuBar, action: nil)
        #expect(MenuBarPresenter.present(state).statusLine == "Something went wrong")
    }

    /// Below a failure and above the rest: an update is about to take the app away.
    @Test("an update outranks the ordinary activity line")
    func updateOutranksActivity() {
        let state = MenuBarState(activity: .listening, updateProgress: .installing)
        #expect(MenuBarPresenter.present(state).statusLine == "Updating…")
    }

    @Test("VoiceOver reads it as a sentence")
    func spoken() {
        let spoken = MenuBarPresenter.present(MenuBarState(updateProgress: .installing))
            .accessibilityLabel
        #expect(spoken == "Uttrflow. Updating.")
    }
}

@Suite("The shortcut the menu prints")
struct MenuBarPrintedShortcutTests {
    /// #157: the menu showed the shipped default, so anybody who rebound was told the wrong key.
    @Test("is the one the user bound, not the one the product ships with")
    func followsTheBinding() {
        var state = MenuBarState()
        state.shortcuts = ShortcutSet([.dictate: [.optionSpace]])
        let dictate = MenuBarPresenter.present(state).command(.startDictation)
        #expect(dictate?.shortcut == MenuBarShortcut(key: " ", modifiers: .option))
    }

    @Test("is absent rather than wrong when the key cannot be a menu equivalent")
    func absentWhenUnprintable() {
        var state = MenuBarState()
        state.shortcuts = ShortcutSet([.dictate: [.functionHold]])
        let dictate = MenuBarPresenter.present(state).command(.startDictation)
        #expect(dictate != nil)
        #expect(dictate?.shortcut == nil, "fn has no character, so the menu must not invent one")
    }

    @Test("and a modifier the menu cannot carry takes the whole shortcut with it")
    func absentWhenAModifierCannotBeCarried() {
        let control = HotkeyBinding(keyCode: 9, modifiers: [.control, .command])
        #expect(MenuBarShortcut.forBinding(control) == nil)
        #expect(MenuBarShortcut.forBinding(.shiftCommandV)?.key == "v")
    }

    @Test(
        "the AI suggestions switch says what its model is waiting on, in the words Settings uses",
        arguments: [
            (SuggestionModelReadiness.loading, "AI Suggestions — Getting ready"),
            (.downloading(fractionCompleted: nil), "AI Suggestions — Getting ready"),
            (.downloading(fractionCompleted: 0.42), "AI Suggestions — Getting ready — 42%"),
            (.downloading(fractionCompleted: 1.7), "AI Suggestions — Getting ready — 100%"),
            (.releasedForMemory, "AI Suggestions — Paused to free memory"),
            (.failed, "AI Suggestions — The model could not be fetched"),
            (.ready, "AI Suggestions"),
            (.notAsked, "AI Suggestions"),
        ])
    func suggestionsSwitchShowsTheModel(model: SuggestionModelReadiness, title: String) {
        let shown = MenuBarPresenter.present(
            MenuBarState(features: MenuBarFeatures(suggestions: true), suggestionModel: model))
        let item = shown.commands.first { $0.intent == .setFeature(.suggestions, isOn: false) }
        #expect(item?.title == title)
        #expect(item?.isChecked == true)
    }

    @Test("a switched-off AI suggestions item says nothing about a model it is not using")
    func offSuggestionsSwitchIsPlain() {
        let shown = MenuBarPresenter.present(
            MenuBarState(features: MenuBarFeatures(suggestions: false), suggestionModel: .failed))
        let item = shown.commands.first { $0.intent == .setFeature(.suggestions, isOn: true) }
        #expect(item?.title == "AI Suggestions")
    }
}

@Suite("A shortcut that cannot be heard")
struct MenuBarUnheardShortcutTests {
    private let reason = "Another app has turned on secure keyboard entry, so the shortcut can't be heard."

    @Test("is said in the header, and Talk still works")
    func saysWhyAndKeepsTheTalkButton() {
        let shown = MenuBarPresenter.present(MenuBarState(shortcutUnheard: reason))
        #expect(
            shown.header
                == .status(
                    MenuBarStatus(title: "Shortcut can’t be heard", detail: reason, emphasis: .attention)))
        #expect(shown.command(.startDictation)?.isEnabled == true)
    }

    @Test("says nothing when the shortcut can be heard")
    func silentWhenHeard() {
        guard case .hint = MenuBarPresenter.present(MenuBarState()).header else {
            Issue.record("the hint is missing")
            return
        }
    }

    @Test("says nothing while dictation is switched off, since there is no shortcut to miss")
    func silentWhenDictationIsOff() {
        let state = MenuBarState(features: MenuBarFeatures(dictation: false), shortcutUnheard: reason)
        guard case .hint = MenuBarPresenter.present(state).header else {
            Issue.record("the unheard shortcut was said while dictation is off")
            return
        }
    }
}
