// Tests for the onboarding pages: rules that hold on every page, each page's card, keycaps, dots.
import Testing

@testable import UttrflowAccount
@testable import UttrflowCore
@testable import UttrflowSettings
@testable import UttrflowUX

/// Every page the flow can ask for, unreachable combinations included, so a new page meets the rules.
private let everyState: [OnboardingState] = [
    OnboardingState(step: .signIn, detail: .signIn(.offering)),
    OnboardingState(step: .signIn, detail: .signIn(.unreachable)),
    OnboardingState(step: .signIn, detail: .signIn(.signingIn(.google))),
    OnboardingState(step: .signIn, detail: .signIn(.signingIn(.gitHub))),
    OnboardingState(step: .signIn, detail: .signIn(.signingIn(.apple))),
    OnboardingState(step: .signIn, detail: .signIn(.enterCode(.google, code: "WDJB-MJHT"))),
    OnboardingState(step: .signIn, detail: .signIn(.refused("Nobody answered."))),
    OnboardingState(step: .signIn, detail: .reading),
    OnboardingState(step: .microphone, detail: .permission(.notDetermined)),
    OnboardingState(step: .microphone, detail: .permission(.denied)),
    OnboardingState(step: .microphone, detail: .permission(.restricted)),
    OnboardingState(step: .microphone, detail: .permission(.granted)),
    OnboardingState(step: .microphone, detail: .awaitingSystemSettings),
    OnboardingState(step: .accessibility, detail: .permission(.notDetermined)),
    OnboardingState(step: .accessibility, detail: .permission(.denied)),
    OnboardingState(step: .accessibility, detail: .permission(.restricted)),
    OnboardingState(step: .accessibility, detail: .permission(.granted)),
    OnboardingState(step: .accessibility, detail: .awaitingSystemSettings),
    OnboardingState(step: .setup, detail: .installing(0.5)),
    OnboardingState(step: .setup, detail: .installFailed("It stopped.", reached: 0.4)),
    OnboardingState(step: .setup, detail: .installed),
    OnboardingState(step: .setup, detail: .reading),
    OnboardingState(step: .ready, detail: .finishing(.ready)),
    OnboardingState(step: .ready, detail: .finishing(.ready, trial: .listening)),
    OnboardingState(step: .ready, detail: .finishing(.ready, trial: .heard("Hello there."))),
    OnboardingState(step: .ready, detail: .finishing(.pastesManually)),
    OnboardingState(step: .ready, detail: .finishing(.needsSpeechModel)),
    OnboardingState(step: .ready, detail: .finishing(.needsMicrophone)),
    OnboardingState(step: .ready, detail: .reading),
]

/// Words that would tell the user which engine is doing the work; §16 forbids them anywhere readable.
private let forbiddenWords = [
    "whisper", "whisperkit", "mlx", "qwen", "foundation model", "llm", "coreml",
]

/// The page for a state, with the default shortcut unless given one.
private func page(
    _ state: OnboardingState, hotkey: HotkeyBinding = Settings.default.hotkey,
    activation: HotkeyActivation = .holdToTalk
) -> OnboardingPage {
    OnboardingPresenter.page(for: state, hotkey: hotkey, activation: activation)
}

/// Every intent a page offers, buttons, providers and link together.
private func intents(_ page: OnboardingPage) -> [OnboardingIntent] {
    page.providers.filter(\.isEnabled).map { .signIn($0.provider) }
        + page.buttons.filter(\.isEnabled).map(\.intent) + [page.link?.intent].compactMap(\.self)
}

@Suite("Onboarding pages")
struct OnboardingPresenterTests {

    // MARK: Rules that hold on every page

    @Test("says something on every page it can be asked for, and numbers it")
    func everyPageIsWhole() {
        for state in everyState {
            let page = page(state)
            #expect(!page.title.isEmpty, "\(state) has no title")
            #expect(!page.accessibilityLabel.isEmpty, "\(state) has nothing to read aloud")
            #expect(page.position == state.step.position)
            #expect(page.stepCount == OnboardingStep.allCases.count)
        }
    }

    /// The last page offers only the dashboard once words have arrived, since it is closing by itself.
    @Test("never leaves the user on a page with nothing they can press, but the one closing itself")
    func noPageIsADeadEnd() {
        for state in everyState where state.detail.trial == .waiting || state.detail.trial == .listening {
            #expect(page(state).hasSomethingToPress, "\(state) is a dead end")
        }
        let closing = page(OnboardingState(step: .ready, detail: .finishing(.ready, trial: .heard("Hi"))))
        #expect(!closing.hasSomethingToPress)
        #expect(closing.hint == "Opening your dashboard…")
    }

    @Test("puts the providers on the sign-in page, and only where one can be chosen or chosen again")
    func onlySignInOffersProviders() {
        for state in everyState {
            let offers =
                state.step == .signIn
                && [.offering, .refused("Nobody answered.")].contains(state.detail.signIn)
            let expected = offers ? SignInProvider.offered.count : 0
            #expect(page(state).providers.count == expected, "\(state) draws the wrong providers")
        }
    }

    @Test("only the page a person is agreeing on carries the terms")
    func onlySignInCarriesTheTerms() {
        let agreeing = page(OnboardingState(step: .signIn, detail: .signIn(.offering)))
        #expect(agreeing.showsTerms)
        for state in everyState where state.step != .signIn {
            #expect(!page(state).showsTerms, "\(state)")
        }
    }

    @Test("steers towards at most one answer, and points at none but that one")
    func atMostOneProminentButton() {
        for state in everyState {
            let page = page(state)
            #expect(page.buttons.filter(\.isProminent).count <= 1, "\(state) steers towards many answers")
            #expect(page.buttons.filter { $0.isPointedAt && !$0.isProminent }.isEmpty, "\(state)")
        }
    }

    @Test("never names an engine, a model or a file")
    func neverNamesTheMachinery() {
        for state in everyState {
            let page = page(state)
            let spoken = [page.title, page.hint ?? "", page.explanation ?? "", page.accessibilityLabel]
                .joined(separator: " ")
                .lowercased()
            for word in forbiddenWords {
                #expect(!spoken.contains(word), "\(state) says \(word)")
            }
        }
    }

    @Test("reads aloud the heading and the sentence behind it")
    func voiceOverGetsTheWholePage() {
        for state in everyState {
            let page = page(state)
            #expect(page.accessibilityLabel.hasPrefix(page.title))
            if let said = page.explanation ?? page.hint {
                #expect(page.accessibilityLabel.contains(said))
            }
        }
    }

    // MARK: Moods

    /// The problem moods, written out because being marked one is deliberate, not computed.
    private static let troubles: [(OnboardingState, OnboardingMood)] = [
        (OnboardingState(step: .signIn, detail: .signIn(.unreachable)), .offline),
        (OnboardingState(step: .signIn, detail: .signIn(.refused("Nobody answered."))), .failure),
        (OnboardingState(step: .setup, detail: .installFailed("It stopped.", reached: 0.4)), .failure),
        (OnboardingState(step: .microphone, detail: .permission(.denied)), .warning),
        (OnboardingState(step: .microphone, detail: .permission(.restricted)), .warning),
        (OnboardingState(step: .accessibility, detail: .permission(.restricted)), .warning),
        (OnboardingState(step: .ready, detail: .finishing(.needsMicrophone)), .warning),
        (OnboardingState(step: .ready, detail: .finishing(.needsSpeechModel)), .warning),
    ]

    @Test("draws the pages that report a problem in their own light, and no others")
    func troublesAreMarked() {
        let problems: Set<OnboardingMood> = [.warning, .failure, .offline]
        for state in everyState {
            if let mood = Self.troubles.first(where: { $0.0 == state })?.1 {
                #expect(page(state).mood == mood, "\(state) is drawn in the wrong light")
            } else {
                #expect(!problems.contains(page(state).mood), "\(state) is drawn as a problem")
            }
        }
    }

    @Test("lights a finished step as done and a step under way as live")
    func doneAndLive() {
        for step in [OnboardingStep.microphone, .accessibility] {
            #expect(page(OnboardingState(step: step, detail: .permission(.granted))).mood == .done)
            #expect(page(OnboardingState(step: step, detail: .awaitingSystemSettings)).mood == .waiting)
        }
        #expect(page(OnboardingState(step: .setup, detail: .installed)).mood == .done)
        #expect(page(OnboardingState(step: .setup, detail: .installing(0.2))).mood == .live)
        #expect(page(OnboardingState(step: .signIn, detail: .signIn(.signingIn(.google)))).mood == .waiting)
    }

    // MARK: Sign-in

    @Test("says what Uttrflow is for on the page that asks who you are")
    func signInCarriesThePitch() {
        let offering = page(OnboardingState(step: .signIn, detail: .signIn(.offering)))
        #expect(offering.title == "Just talk.")
        #expect(offering.picture == .waveform(.talking, badge: nil))
        #expect(offering.explanation == OnboardingPresenter.pitch)
        #expect(offering.providers.first?.label == "Google")
        #expect(offering.providers.first?.title == "Continue with Google")
    }

    @Test("offline, offers only to try again")
    func offlineOffersOnlyTryAgain() {
        let offline = page(OnboardingState(step: .signIn, detail: .signIn(.unreachable)))
        #expect(offline.providers.isEmpty)
        #expect(offline.buttons.map(\.intent) == [.recover(.retry)])
        #expect(offline.picture == .waveform(.still, badge: .symbol("wifi.slash", .neutral)))
    }

    @Test("while the browser has the user, offers to open it again or give up")
    func waitingOnTheBrowser() {
        let waiting = page(OnboardingState(step: .signIn, detail: .signIn(.signingIn(.google))))
        #expect(waiting.buttons.map(\.intent) == [.reopenBrowser, .cancelSignIn])
        #expect(waiting.picture == .waveform(.idle, badge: .waitingOn(.google)))

        let code = page(OnboardingState(step: .signIn, detail: .signIn(.enterCode(.google, code: "AB-CD"))))
        #expect(code.picture == .code("AB-CD"))
        #expect(code.buttons.map(\.intent) == [.reopenBrowser, .cancelSignIn])
    }

    @Test("a refusal says why and offers the providers again")
    func aRefusalSaysWhy() {
        let refused = page(OnboardingState(step: .signIn, detail: .signIn(.refused("Nobody answered."))))
        #expect(refused.hint == "Nobody answered.")
        #expect(refused.providers.filter(\.isEnabled).count == refused.providers.count)
        #expect(refused.picture == .waveform(.still, badge: .symbol("xmark", .failure)))
    }

    @Test("offers no way past sign-in without an account")
    func signInIsMandatory() {
        for state in everyState where state.step == .signIn {
            #expect(!intents(page(state)).contains(.advance), "\(state)")
        }
    }

    // MARK: Permissions

    @Test("offers no way past a permission until it is granted, bar a device policy")
    func permissionsAreMandatory() {
        for step in [OnboardingStep.microphone, .accessibility] {
            for detail in [
                OnboardingDetail.permission(.notDetermined), .permission(.denied), .awaitingSystemSettings,
            ] {
                #expect(!intents(page(OnboardingState(step: step, detail: detail))).contains(.advance))
            }
            for status in [PermissionStatus.granted, .restricted] {
                let page = page(OnboardingState(step: step, detail: .permission(status)))
                #expect(page.buttons.map(\.intent) == [.advance], "\(step) at \(status)")
            }
        }
    }

    @Test("points at Allow on a first visit, and asks macOS")
    func allowIsPointedAt() {
        for step in [OnboardingStep.microphone, .accessibility] {
            let kind: PermissionKind = step == .microphone ? .microphone : .accessibility
            let first = page(OnboardingState(step: step, detail: .permission(.notDetermined)))
            #expect(first.buttons.count == 1)
            #expect(first.buttons.first?.isPointedAt == true)
            #expect(first.buttons.first?.intent == .requestPermission(kind))
        }
    }

    /// `AXIsProcessTrusted` answers false before anyone has been asked, so this page opens at `.denied`.
    @Test("the Accessibility page opens on the ask, since nobody has refused yet")
    func accessibilityIsQuietOnItsFirstVisit() {
        let first = page(OnboardingState(step: .accessibility, detail: .permission(.denied)))
        #expect(first.buttons.first?.intent == .requestPermission(.accessibility))
        #expect(first.picture == .typing(.still, field: .placeholder("Your words go here")))
    }

    @Test("a refused microphone points at System Settings")
    func aRefusedMicrophonePointsAtSettings() {
        let refused = page(OnboardingState(step: .microphone, detail: .permission(.denied)))
        #expect(refused.buttons.map(\.intent) == [.recover(.openSystemSettings(.microphone))])
        #expect(refused.buttons.first?.isPointedAt == true)
        #expect(refused.explanation == PermissionError.microphoneDenied.userMessage)
    }

    @Test("while System Settings is open, offers the pane and a look again, naming where to look")
    func waitingOnSettings() {
        for (step, pane) in [
            (OnboardingStep.microphone, SystemSettingsPane.microphone), (.accessibility, .accessibility),
        ] {
            let waiting = page(OnboardingState(step: step, detail: .awaitingSystemSettings))
            #expect(waiting.buttons.map(\.intent) == [.recover(.openSystemSettings(pane)), .recover(.retry)])
            #expect(waiting.buttons.last?.isProminent == true)
            #expect(waiting.hint?.hasPrefix("Privacy & Security › ") == true)
        }
    }

    @Test("draws the microphone as a waveform and Accessibility as a field being typed into")
    func eachPermissionHasItsPicture() {
        let heard = page(OnboardingState(step: .microphone, detail: .permission(.granted)))
        #expect(heard.picture == .waveform(.talking, badge: nil))
        let typed = page(OnboardingState(step: .accessibility, detail: .permission(.granted)))
        guard case .typing(.talking, .typing) = typed.picture else {
            Issue.record("Accessibility granted draws \(typed.picture)")
            return
        }
        let blocked = page(OnboardingState(step: .microphone, detail: .permission(.restricted)))
        #expect(blocked.picture == .waveform(.still, badge: .symbol("mic.slash", .caution)))
        let waiting = page(OnboardingState(step: .accessibility, detail: .awaitingSystemSettings))
        #expect(waiting.picture == .typing(.idle, field: .placeholder("Waiting for access…")))
        let off = page(OnboardingState(step: .accessibility, detail: .permission(.restricted)))
        #expect(off.picture == .typing(.still, field: .placeholder("Typing is turned off")))
    }

    // MARK: The download

    @Test("keeps Continue in view while the download runs, and keeps it unpressable")
    func theDownloadPageWaits() {
        let downloading = page(OnboardingState(step: .setup, detail: .installing(0.64)))
        #expect(downloading.picture == .download(0.64, .running))
        #expect(downloading.buttons.map(\.title) == ["Cancel", "Continue"])
        #expect(downloading.buttons.last?.isEnabled == false)
        #expect(downloading.buttons.first?.intent == .cancelInstall)
    }

    @Test("puts the reason a download stopped in front of the user, where it stopped, with no way past")
    func aStoppedDownloadExplainsItself() {
        let message = SpeechEngineError.modelDownloadFailed(description: "offline").userMessage
        let stopped = page(OnboardingState(step: .setup, detail: .installFailed(message, reached: 0.38)))
        #expect(stopped.hint == message)
        #expect(stopped.picture == .download(0.38, .stopped))
        #expect(stopped.buttons.map(\.intent) == [.recover(.downloadSpeechModel)])
    }

    @Test("lets the user on once the model is on disk")
    func aFinishedDownloadLetsThrough() {
        for detail in [OnboardingDetail.installed, .reading] {
            let done = page(OnboardingState(step: .setup, detail: detail))
            #expect(done.picture == .download(1, .finished))
            #expect(done.buttons.map(\.intent) == [.advance])
        }
    }

    // MARK: The last page

    @Test("asks a new install for a first try with ⌃⌥ held, and a way straight to the app")
    func theFirstTry() {
        let trying = page(OnboardingState(step: .ready, detail: .finishing(.ready)))
        #expect(trying.title == "Hold ⌃ ⌥ and talk.")
        #expect(
            trying.picture == .keys(["⌃", "⌥"], isHeld: false, field: .placeholder("Your words appear here")))
        #expect(trying.link == OnboardingLink(title: "Skip to dashboard", intent: .finish))
        #expect(trying.hint == nil)

        let pressed = page(
            OnboardingState(step: .ready, detail: .finishing(.ready)), activation: .pressToToggle)
        #expect(pressed.title == "Press ⌃ ⌥ and talk.")

        let earlier = page(
            OnboardingState(step: .ready, detail: .finishing(.ready)), hotkey: Settings.earlierInstall.hotkey)
        #expect(earlier.title == "Hold ⌥ Space and talk.")
    }

    @Test("holds the keys down while listening, and shows the words that came back")
    func theTryGoesOn() {
        let listening = page(OnboardingState(step: .ready, detail: .finishing(.ready, trial: .listening)))
        #expect(listening.title == "Listening…")
        #expect(listening.mood == .live)
        #expect(listening.hint == "Let go when you’re done")
        guard case .keys(_, isHeld: true, _) = listening.picture else {
            Issue.record("listening draws \(listening.picture)")
            return
        }
        let toggled = page(
            OnboardingState(step: .ready, detail: .finishing(.ready, trial: .listening)),
            activation: .pressToToggle)
        #expect(toggled.hint == "Press again when you’re done")

        let heard = page(
            OnboardingState(step: .ready, detail: .finishing(.ready, trial: .heard("Hi there."))))
        #expect(heard.title == "That’s it.")
        #expect(heard.picture == .keys(["⌃", "⌥"], isHeld: false, field: .filled("Hi there.")))
    }

    @Test("says that words will be copied when Accessibility is missing")
    func copyingIsSaid() {
        let copying = page(OnboardingState(step: .ready, detail: .finishing(.pastesManually)))
        #expect(copying.hint?.contains("copied") == true)
    }

    @Test("offers the way to put right an ending that cannot be tried")
    func everyEndingThatCanBeFixedOffersTheFix() {
        let fixes: [OnboardingReadiness: OnboardingIntent] = [
            .needsSpeechModel: .recover(.downloadSpeechModel),
            .needsMicrophone: .recover(.openSystemSettings(.microphone)),
        ]
        for (readiness, fix) in fixes {
            let ending = page(OnboardingState(step: .ready, detail: .finishing(readiness)))
            #expect(ending.buttons.map(\.intent) == [fix, .finish], "\(readiness) offers no way back")
            #expect(ending.buttons.last?.title == "Close")
        }
    }

    // MARK: Keycaps

    @Test("draws a shortcut in the order macOS draws it")
    func modifiersComeInTheSystemsOrder() {
        let everything = HotkeyBinding(
            keyCode: 49, modifiers: [.command, .shift, .option, .control])
        #expect(OnboardingKeys.of(everything) == ["⌃", "⌥", "⇧", "⌘", "Space"])
        #expect(OnboardingKeys.of(.optionSpace) == ["⌥", "Space"])
    }

    @Test("prints a key it cannot name as a code rather than as the wrong letter")
    func anUnnamedKeyIsNotGuessedAt() {
        let unusual = HotkeyBinding(keyCode: 7, modifiers: [.command])
        #expect(OnboardingKeys.of(unusual) == ["⌘", "Key 7"])
    }

    /// Issue 353: a chord of modifiers drew its key as a raw code, and a held Fn as "Key 63".
    @Test("draws a shortcut made of modifiers, or a held Fn, the way Settings does")
    func heldKeysMatchSettings() {
        let chord = HotkeyBinding(keyCode: 58, modifiers: [.option, .command, .control])
        #expect(OnboardingKeys.of(chord) == ["⌃", "⌥", "⌘"])
        #expect(OnboardingKeys.of(.functionHold) == ["fn"])
    }

    @Test("names the keys a shortcut is realistically bound to")
    func theNamedKeys() {
        let named = [36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape"]
        for (code, name) in named {
            let binding = HotkeyBinding(keyCode: UInt16(code), modifiers: [.option])
            #expect(OnboardingKeys.of(binding).last == name)
        }
    }

    // MARK: The dots

    @Test("numbers the dots once each, from one to five")
    func theDotsAreNumberedOnce() {
        let positions = OnboardingStep.allCases.map(\.position)
        #expect(positions == Array(1...OnboardingStep.count))
        #expect(OnboardingStep.count == 5)
    }
}
