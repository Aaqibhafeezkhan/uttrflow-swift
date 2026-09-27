// Turns onboarding state into the card the window draws, plus permission wording and keycaps.
internal import UttrflowAccount
public import UttrflowCore

/// Turns where the user is into what the window draws; the one place the approved designs live.
public enum OnboardingPresenter {
    /// The page for a state, with the shortcut and how it is pressed drawn on the last one.
    public static func page(
        for state: OnboardingState, hotkey: HotkeyBinding, activation: HotkeyActivation = .holdToTalk,
        signsInAsStandIn: Bool = false
    ) -> OnboardingPage {
        switch state.step {
        case .signIn: signIn(state, standIn: signsInAsStandIn)
        case .microphone: permission(.microphone, state)
        case .accessibility: permission(.accessibility, state)
        case .setup: setup(state)
        case .ready: ready(state, keys: OnboardingKeys.of(hotkey), activation: activation)
        }
    }

    // MARK: Sign-in

    /// What Uttrflow is for, said on the page that asks who you are.
    static let pitch = """
        Hold one key, say what you mean, and Uttrflow writes it into whatever app you’re in — \
        punctuated, tidied, and without the “um”s. Sign in once, and after that it runs \
        entirely on this Mac.
        """

    /// Said under the providers in a development build, whose sign-in asks nobody.
    static let standInHint = "Development build: signs in as a stand-in, no browser"

    /// The sign-in page in its five forms: offering, unreachable, in the browser, entering a code, refused.
    private static func signIn(_ state: OnboardingState, standIn: Bool = false) -> OnboardingPage {
        let signIn = state.detail.signIn
        let providers = SignInProvider.offered.map {
            OnboardingProviderButton(provider: $0, isEnabled: signIn.acceptsAProvider)
        }
        let waiting = [
            OnboardingButton.plain("Reopen", "macwindow", .reopenBrowser),
            .plain("Cancel", "xmark", .cancelSignIn),
        ]
        switch signIn {
        case .offering:
            return page(
                state, mood: .brand, picture: .waveform(.talking, badge: nil), title: "Just talk.",
                providers: providers, hint: standIn ? standInHint : nil, showsTerms: true,
                explanation: pitch)
        case .refused(let message):
            return page(
                state, mood: .failure, picture: .waveform(.still, badge: .symbol("xmark", .failure)),
                title: "That didn’t work.", providers: providers, hint: message, showsTerms: true,
                explanation: message)
        case .unreachable:
            return page(
                state, mood: .offline,
                picture: .waveform(.still, badge: .symbol("wifi.slash", .neutral)),
                title: "You’re offline.",
                buttons: [.prominent("Try again", "arrow.clockwise", .recover(.retry))],
                explanation: """
                    Signing in is the one thing Uttrflow needs the internet for. Connect and \
                    try again.
                    """)
        case .signingIn(let provider):
            return page(
                state, mood: .waiting, picture: .waveform(.idle, badge: .waitingOn(provider)),
                title: "Check your browser.", buttons: waiting,
                explanation:
                    "Finish signing in with \(AccountPagePresenter.title(for: provider)) in your browser.")
        case .enterCode(let provider, let code):
            return page(
                state, mood: .waiting, picture: .code(code), title: "Type this code.", buttons: waiting,
                hint: "In your browser, to finish with \(AccountPagePresenter.title(for: provider))",
                explanation: """
                    Your browser is open. Type this code there to finish signing in with \
                    \(AccountPagePresenter.title(for: provider)).
                    """)
        }
    }

    // MARK: Permissions

    /// Both permission pages from one shape; neither can be left until it is granted.
    private static func permission(
        _ kind: PermissionKind, _ state: OnboardingState
    ) -> OnboardingPage {
        let wording = PermissionWording.of(kind)
        let pane = OnboardingIntent.recover(.openSystemSettings(kind.settingsPane))
        let settings = OnboardingButton.plain("Settings", "gearshape", pane)
        let allow = OnboardingButton.pointed("Allow", wording.symbolName, .requestPermission(kind))
        switch state.detail {
        case .permission(.granted):
            return page(
                state, mood: .done, picture: wording.picture(.talking, .granted),
                title: wording.grantedTitle, buttons: [.prominent("Continue", "arrow.right", .advance)])
        case .permission(.restricted):
            return page(
                state, mood: .warning, picture: wording.picture(.still, .blocked),
                title: wording.blockedTitle,
                buttons: [.prominent("Continue", "arrow.right", .advance)],
                hint: "A device policy turns this off", explanation: wording.refused)
        case .awaitingSystemSettings:
            return page(
                state, mood: .waiting, picture: wording.picture(.idle, .waiting),
                title: "Flip the switch.",
                buttons: [settings, .prominent("Check", "arrow.clockwise", .recover(.retry))],
                hint: "Privacy & Security › \(wording.paneName)", explanation: wording.refused)
        // Accessibility reads as refused before anyone has been asked, so its first answer is still the ask.
        case .permission(.denied) where kind.reportsNotDetermined:
            return page(
                state, mood: .warning, picture: wording.picture(.still, .refused),
                title: wording.refusedTitle,
                buttons: [.pointed("Settings", "gearshape", pane)], explanation: wording.refused)
        default:
            return page(
                state, mood: .brand, picture: wording.picture(.still, .asking), title: wording.askTitle,
                buttons: [allow], hint: wording.askHint, explanation: wording.why)
        }
    }

    // MARK: The download

    /// The download page: running, stopped, or done; it cannot be left until the model is on disk.
    private static func setup(_ state: OnboardingState) -> OnboardingPage {
        switch state.detail {
        case .installing(let fraction):
            page(
                state, mood: .live, picture: .download(fraction, .running), title: "Tuning in.",
                buttons: [.plain("Cancel", "xmark", .cancelInstall), .disabled("Continue", "arrow.right")],
                hint: "One-time download · stays on this Mac", explanation: staysOnThisMac)
        case .installFailed(let message, let reached):
            page(
                state, mood: .failure, picture: .download(reached, .stopped), title: "Download stopped.",
                buttons: [.prominent("Try again", "arrow.clockwise", .recover(.downloadSpeechModel))],
                hint: message, explanation: message)
        // Nothing left to wait for: the model is on disk, so the user is let past.
        default:
            page(
                state, mood: .done, picture: .download(1, .finished), title: "Ready to listen.",
                buttons: [.prominent("Continue", "arrow.right", .advance)], explanation: staysOnThisMac)
        }
    }

    /// Why the wait is worth it, said on every form of the download page.
    static let staysOnThisMac = """
        A one-time download. Once it finishes, dictation runs on this Mac — it keeps working \
        with Wi-Fi off, on a plane, anywhere.
        """

    // MARK: The last page

    /// The last page: a first try when dictation can work, else what still stands in the way.
    private static func ready(
        _ state: OnboardingState, keys: [String], activation: HotkeyActivation
    ) -> OnboardingPage {
        switch state.detail.readiness ?? .ready {
        case .ready, .pastesManually:
            trying(state, keys: keys, activation: activation)
        case .needsSpeechModel:
            page(
                state, mood: .warning, picture: .download(0, .stopped),
                title: "One thing left to download.",
                buttons: [
                    .plain("Download", "arrow.down", .recover(.downloadSpeechModel)),
                    .prominent("Close", "xmark", .finish),
                ],
                hint: "Nothing is recognised until it finishes",
                explanation: SpeechEngineError.modelNotInstalled.userMessage)
        case .needsMicrophone:
            page(
                state, mood: .warning, picture: .waveform(.still, badge: .symbol("mic.slash", .caution)),
                title: "Can’t hear you yet.",
                buttons: [
                    .plain("Settings", "gearshape", .recover(.openSystemSettings(.microphone))),
                    .prominent("Close", "xmark", .finish),
                ],
                hint: "Turn on the microphone to dictate",
                explanation: PermissionError.microphoneDenied.userMessage)
        }
    }

    /// The first try: the keys to press, the field the words land in, and a way straight to the app.
    private static func trying(
        _ state: OnboardingState, keys: [String], activation: HotkeyActivation
    ) -> OnboardingPage {
        let skip = OnboardingLink(title: "Skip to dashboard", intent: .finish)
        let copies = state.detail.readiness == .pastesManually
        let empty = OnboardingField.placeholder("Your words appear here")
        let verb = activation == .holdToTalk ? "Hold" : "Press"
        switch state.detail.trial {
        case .waiting:
            return page(
                state, mood: .brand, picture: .keys(keys, isHeld: false, field: empty),
                title: "\(verb) \(keys.joined(separator: " ")) and talk.", link: skip,
                hint: copies ? "Without Accessibility, words are copied for you to paste" : nil,
                explanation: "Try it now. Uttrflow lives in your menu bar whenever you need it.")
        case .listening:
            return page(
                state, mood: .live, picture: .keys(keys, isHeld: true, field: empty),
                title: "Listening…", link: skip,
                hint: activation == .holdToTalk ? "Let go when you’re done" : "Press again when you’re done")
        case .heard(let words):
            return page(
                state, mood: .done, picture: .keys(keys, isHeld: false, field: .filled(words)),
                title: "That’s it.", hint: "Opening your dashboard…")
        }
    }

    // MARK: Assembly

    /// Fills in everything a page has in common, so each page says only what makes it different.
    private static func page(
        _ state: OnboardingState,
        mood: OnboardingMood,
        picture: OnboardingPicture,
        title: String,
        providers: [OnboardingProviderButton] = [],
        buttons: [OnboardingButton] = [],
        link: OnboardingLink? = nil,
        hint: String? = nil,
        showsTerms: Bool = false,
        explanation: String? = nil
    ) -> OnboardingPage {
        OnboardingPage(
            mood: mood,
            picture: picture,
            title: title,
            providers: providers,
            buttons: buttons,
            link: link,
            hint: hint,
            showsTerms: showsTerms,
            explanation: explanation,
            position: state.step.position,
            stepCount: OnboardingStep.count,
            // Spoken as one sentence, so a screen reader says what the page is and what it wants.
            accessibilityLabel: [title, explanation ?? hint].compactMap(\.self).joined(separator: " ")
        )
    }
}

// MARK: - Wording

/// Everything that differs between the two permission pages, as data so a third is a row here.
private struct PermissionWording {
    /// Which answer a permission page is drawing.
    enum Moment { case asking, waiting, refused, granted, blocked }

    /// Which permission this is.
    let kind: PermissionKind
    /// The SF Symbol on the Allow button and the badge.
    let symbolName: String
    /// The heading before anything is granted.
    let askTitle: String
    /// The heading once it is granted.
    let grantedTitle: String
    /// The heading after a refusal.
    let refusedTitle: String
    /// The heading when a device policy decides.
    let blockedTitle: String
    /// The line under the Allow button.
    let askHint: String
    /// The name of the list it is switched on in, under Privacy & Security.
    let paneName: String
    /// Why it is asked for, read by VoiceOver and shown on hover.
    let why: String
    /// What is not possible until it is granted.
    let refused: String

    /// The wording for a permission.
    static func of(_ kind: PermissionKind) -> PermissionWording {
        switch kind {
        case .microphone: microphone
        case .accessibility: accessibility
        }
    }

    /// The card's picture for one moment: the microphone badges the waveform, Accessibility fills a field.
    func picture(_ wave: OnboardingWave, _ moment: Moment) -> OnboardingPicture {
        guard kind == .microphone else {
            return .typing(wave, field: Self.field(for: moment))
        }
        switch moment {
        case .granted: return .waveform(wave, badge: nil)
        case .asking: return .waveform(wave, badge: .symbol(symbolName, .neutral))
        case .waiting: return .waveform(wave, badge: .symbol("gearshape", .neutral))
        case .refused, .blocked: return .waveform(wave, badge: .symbol("mic.slash", .caution))
        }
    }

    /// What the Accessibility page's field says at each moment.
    private static func field(for moment: Moment) -> OnboardingField {
        switch moment {
        case .asking: .placeholder("Your words go here")
        case .waiting: .placeholder("Waiting for access…")
        case .granted: .typing("See you Thursday at 10.")
        case .refused, .blocked: .placeholder("Typing is turned off")
        }
    }

    /// The microphone page's words.
    private static let microphone = PermissionWording(
        kind: .microphone,
        symbolName: "mic",
        askTitle: "Let me hear you.",
        grantedTitle: "Loud and clear.",
        refusedTitle: "Mic is off.",
        blockedTitle: "Mic is blocked.",
        askHint: "Stays on this Mac",
        paneName: "Microphone",
        why: "\(SettingsPresenter.recordingsPromise) Nothing you say is uploaded.",
        refused: PermissionError.microphoneDenied.userMessage
    )

    /// The Accessibility page's words.
    private static let accessibility = PermissionWording(
        kind: .accessibility,
        symbolName: "figure.arms.open",
        askTitle: "Let me type for you.",
        grantedTitle: "Ready to type.",
        refusedTitle: "Typing is off.",
        blockedTitle: "Typing is blocked.",
        askHint: "Words land where your cursor is",
        paneName: "Accessibility",
        why: """
            macOS asks for this because Uttrflow types into apps you have open. It only ever \
            inserts at your cursor — it never reads or changes anything else.
            """,
        refused: """
            Until this is on, Uttrflow cannot type into another app. It will put your words on \
            the clipboard instead, for you to paste.
            """
    )
}

// MARK: - Keycaps

/// A shortcut as the keys a person actually presses.
enum OnboardingKeys {
    /// Modifiers in the order macOS draws them, then the key itself.
    static func of(_ binding: HotkeyBinding) -> [String] {
        // A key that is itself a modifier, or Fn, is drawn exactly as Settings draws it.
        guard binding.heldModifier == nil else { return SettingsShortcut.keycaps(for: binding) }
        return SettingsShortcut.modifierCaps(for: binding) + [name(for: binding.keyCode)]
    }

    /// The keys a shortcut is realistically bound to; a key code becomes a letter only through the layout.
    private static let names: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
    ]

    /// The key's name, or its code when the name is unknown.
    private static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
