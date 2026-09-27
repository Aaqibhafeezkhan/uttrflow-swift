// The onboarding window's contents: the aurora, the logo, and the glass card each page is drawn on.

import AppKit
import SwiftUI
import UttrflowAccount
import UttrflowUX

/// The page the window is showing, observable for SwiftUI; every field comes from `OnboardingFlow`.
@MainActor
@Observable
final class OnboardingModel {
    private(set) var page: OnboardingPage

    @ObservationIgnored private let flow: OnboardingFlow

    init(flow: OnboardingFlow) {
        self.flow = flow
        self.page = flow.page
        // Reads the flow through `self`, since the flow keeps this closure and must not be kept by it.
        flow.onChange = { [weak self] _ in
            guard let self else { return }
            page = self.flow.page
        }
    }

    /// Whether the window was opened by Sign In rather than by a permission button.
    @ObservationIgnored var asksToSignIn = false

    func start() {
        Task { [flow, asksToSignIn] in
            await asksToSignIn ? flow.resume(askingToSignIn: true) : flow.start()
        }
    }

    /// Re-reads both permissions when the window comes to the front; System Settings never tells the app.
    func refresh() {
        Task { await flow.refresh() }
    }

    func press(_ intent: OnboardingIntent) {
        Task { await flow.perform(intent) }
    }

    /// Tells the last page how the first try is going.
    func tried(_ trial: OnboardingTrial) {
        Task { await flow.tried(trial) }
    }
}

/// The onboarding window's contents, derived from `OnboardingPage`; dark whatever the Mac is set to.
struct OnboardingView: View {
    let model: OnboardingModel

    var body: some View {
        OnboardingScreen(page: model.page, press: model.press)
            .onAppear { model.start() }
    }
}

/// One page drawn whole: the aurora for its mood, the logo, and the card.
struct OnboardingScreen: View {
    let page: OnboardingPage
    let press: (OnboardingIntent) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            OnboardingBackdrop(mood: page.mood)
            OnboardingLogo()
                .padding(.leading, OnboardingMetrics.logoInset.width)
                .padding(.top, OnboardingMetrics.logoInset.height)
            OnboardingCard(page: page, press: press)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, OnboardingMetrics.cardTrailing)
                .padding(.top, OnboardingMetrics.cardTop)
                .padding(.bottom, OnboardingMetrics.cardBottom)
        }
        .frame(width: OnboardingMetrics.windowWidth, height: OnboardingMetrics.windowHeight)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}

/// The glass card: the picture above, the heading, the round buttons, a hint and the dots below.
struct OnboardingCard: View {
    let page: OnboardingPage
    let press: (OnboardingIntent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            picture
                .frame(maxWidth: .infinity)
                .frame(height: OnboardingMetrics.pictureHeight)
                .background(pictureGround)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
            VStack(spacing: 22) {
                title
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    buttons
                    footnotes
                }
                OnboardingDots(position: page.position, count: page.stepCount)
            }
            .padding(.top, 26)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .id(page.title)
            .transition(.opacity)
        }
        .frame(width: OnboardingMetrics.cardWidth)
        .frame(maxHeight: .infinity)
        .background(OnboardingInk.glass.opacity(0.46))
        .clipShape(.rect(cornerRadius: OnboardingMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OnboardingMetrics.cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.1)], startPoint: .top,
                        endPoint: .bottom),
                    lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.65), radius: 30, y: 30)
        .animation(.smooth(duration: 0.26), value: page.title)
        .help(page.explanation ?? "")
    }

    /// The teal light rising from the foot of the picture.
    private var pictureGround: some View {
        ZStack {
            Color.black.opacity(0.15)
            EllipticalGradient(
                colors: [OnboardingInk.teal.opacity(0.28), .clear],
                center: .bottom, startRadiusFraction: 0, endRadiusFraction: 0.7)
        }
    }

    @ViewBuilder private var picture: some View {
        switch page.picture {
        case .waveform(let wave, let badge):
            ZStack {
                OnboardingWaveform(wave: wave).frame(width: 300, height: 110)
                if let badge { OnboardingBadgeView(badge: badge) }
            }
        case .typing(let wave, let field):
            VStack(spacing: 6) {
                OnboardingWaveform(wave: wave).frame(width: 240, height: 88)
                OnboardingFieldView(field: field, width: 250)
            }
        case .download(let fraction, let download):
            OnboardingDownloadRing(fraction: fraction, download: download)
        case .keys(let keys, let isHeld, let field):
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    OnboardingKeycaps(keys: keys, isHeld: isHeld)
                    if isHeld { OnboardingWaveform(wave: .talking, count: 18).frame(width: 90, height: 33) }
                }
                OnboardingFieldView(field: field, width: 280)
            }
        case .code(let code):
            OnboardingCode(code: code)
        }
    }

    private var title: some View {
        Text(page.title)
            .font(BrandFont.display(size: 34, weight: .semibold))
            .tracking(-1)
            .multilineTextAlignment(.center)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.35), .init(color: OnboardingInk.glow, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(page.accessibilityLabel)
    }

    private var buttons: some View {
        HStack(alignment: .top, spacing: 22) {
            ForEach(page.providers, id: \.provider) { provider in
                OnboardingRoundButton(
                    title: provider.label, isProminent: provider.provider == page.providers.first?.provider,
                    isEnabled: provider.isEnabled, action: { press(.signIn(provider.provider)) }
                ) {
                    OnboardingProviderMark(provider: provider.provider, size: 26)
                }
                .accessibilityLabel(provider.title)
            }
            ForEach(Array(page.buttons.enumerated()), id: \.offset) { _, button in
                OnboardingRoundButton(
                    title: button.title, isProminent: button.isProminent, isEnabled: button.isEnabled,
                    isPointedAt: button.isPointedAt, action: { press(button.intent) }
                ) {
                    Image(systemName: button.symbolName).font(.system(size: 22, weight: .medium))
                }
            }
        }
    }

    /// The hint, the terms and the link, each quiet and centred under the buttons.
    @ViewBuilder private var footnotes: some View {
        if let hint = page.hint {
            Text(hint)
                .font(.system(size: page.link == nil ? 11 : 12.5))
                .foregroundStyle(.white.opacity(page.link == nil ? 0.42 : 0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 12)
        }
        if page.showsTerms {
            Text("Terms · Privacy")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 12)
                .accessibilityLabel("By continuing you agree to the Terms of Use and the Privacy Policy.")
        }
        if let link = page.link {
            Button(link.title) { press(link.intent) }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .underline(color: .white.opacity(0.3))
                .padding(.top, 10)
        }
    }
}

// MARK: - Sizes

/// The measurements the design is drawn to. See `Docs/app-onboarding.md`.
enum OnboardingMetrics {
    static let windowWidth: CGFloat = 860
    static let windowHeight: CGFloat = 560
    /// The logo's top-left corner, clear of the window's buttons.
    static let logoInset = CGSize(width: 24, height: 56)
    static let cardWidth: CGFloat = 390
    static let cardRadius: CGFloat = 28
    static let cardTop: CGFloat = 66
    static let cardTrailing: CGFloat = 40
    static let cardBottom: CGFloat = 40
    /// The picture at the top of the card.
    static let pictureHeight: CGFloat = 170
    static let roundSize: CGFloat = 64
    /// The aurora's shortest gap between frames: it turns a degree in a fifth of a second.
    static let auroraFrameInterval: TimeInterval = 1.0 / 15
}
