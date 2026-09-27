import AppKit
import SwiftUI
import UttrflowContext
import UttrflowPredict
import UttrflowUX

/// A window that never becomes the active one, so the caret stays in the field under it.
final class SuggestionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// What the surface was last asked to draw, so a display setting can change under it.
private struct SuggestionRequest: Equatable {
    var suggestion: Suggestion = .silent
    /// What is already in the field, so the surface offers only what the suggestion adds.
    var typed: String = ""
    var placement: SuggestionPlacement = .inlineGhost
    var caret: CGRect?
    var window: CGRect?
    /// The field's own rectangle, whose right edge a long ghost is cut at.
    var field: CGRect?
    var fieldPointSize: CGFloat?
    /// Where the arrow keys have put the highlight, and whether they have moved it at all.
    var selection: SuggestionSelection = .untouched
    /// The key that accepts in this field, so the hint drawn after the ghost is the key that works.
    var acceptKey: AcceptKey = .tab
    /// The field's own font family, so the ghost is set in the face the line is.
    var fontFamily: String?
    /// The field's own text colour, so the ghost reads against the field and not against Uttrflow's appearance.
    var textColor: TextColor?

    /// How far apart two reads of one caret may be and still be the same place, since a field can report it a point off.
    static let caretTolerance: CGFloat = 1

    /// Whether this asks for exactly what `other` drew, the caret allowed its read-to-read wobble.
    func draws(sameAs other: Self) -> Bool {
        var aligned = self
        aligned.caret = other.caret
        return aligned == other && Self.sameCaret(caret, other.caret)
    }

    /// Whether two caret reads are one place.
    private static func sameCaret(_ lhs: CGRect?, _ rhs: CGRect?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        return abs(lhs.minX - rhs.minX) <= caretTolerance && abs(lhs.maxX - rhs.maxX) <= caretTolerance
            && abs(lhs.minY - rhs.minY) <= caretTolerance && abs(lhs.maxY - rhs.maxY) <= caretTolerance
    }
}

/// Owns the panel the suggestion is drawn in, one for the whole process so no two ghosts are ever on screen.
@MainActor
final class SuggestionPanelController {
    /// The one panel every suggestion loop draws in, so a loop rebuilt by a settings change cannot leave a second one behind.
    static let shared = SuggestionPanelController()

    private let panel: SuggestionPanel
    private let hostingView: NSHostingView<SuggestionView>
    /// Lays out the ghost line alone at its full width, which is how a ghost too long for its room is caught.
    private var measurer: NSHostingView<SuggestionGhostLine>?
    private var request = SuggestionRequest()
    private var panelSize = CGSize(width: 1, height: 1)
    private var appearanceObserver: (any NSObjectProtocol)?
    private var announcer = SuggestionAnnouncer()
    /// Reads an announcement aloud to VoiceOver; a test swaps it to hear what would be said.
    var announce: @MainActor (String) -> Void = SuggestionPanelController.post
    private var isActuallyShowing = false

    init() {
        hostingView = NSHostingView(rootView: SuggestionView(presentation: .init(.silent)))
        panel = SuggestionPanel(
            contentRect: CGRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        configurePanel()
        hostingView.rootView = SuggestionView(
            presentation: SuggestionPresentation(.silent),
            onDesiredSize: { [weak self] size in self?.resize(to: size) })
        observeAppearance()
    }

    isolated deinit {
        guard let appearanceObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(appearanceObserver)
    }

    /// Says what to draw and what to draw it against, answering whether the offer is on screen whole; `.silent` takes the surface away.
    @discardableResult
    func show(
        _ suggestion: Suggestion,
        typed: String = "",
        placement: SuggestionPlacement,
        caret: CGRect? = nil,
        window: CGRect? = nil,
        field: CGRect? = nil,
        fieldPointSize: CGFloat? = nil,
        selection: SuggestionSelection = .untouched,
        acceptKey: AcceptKey = .tab,
        fontFamily: String? = nil,
        textColor: TextColor? = nil
    ) -> Bool {
        let next = SuggestionRequest(
            suggestion: suggestion, typed: typed, placement: placement, caret: caret,
            window: window, field: field, fieldPointSize: fieldPointSize, selection: selection,
            acceptKey: acceptKey, fontFamily: fontFamily, textColor: textColor)
        // The same offer at the same caret is already on screen, so nothing is laid out, placed or fronted again.
        if isActuallyShowing, next.draws(sameAs: request) { return true }
        request = next
        return render()
    }

    func hide() {
        // Already hidden and already drawn hidden: redrawing would change nothing and costs a screen lookup per key.
        if request.suggestion == .silent, !panel.isVisible, drawn.style == .hidden { return }
        request.suggestion = .silent
        render()
    }

    /// Whether a suggestion is on screen, which is what a scroll acts on.
    var isShowing: Bool { isActuallyShowing }

    /// Exposed so a probe or a test can read back what was actually configured.
    var window: NSPanel { panel }

    /// What the panel is drawing right now, which a test reads back.
    var drawn: SuggestionPresentation { hostingView.rootView.presentation }

    /// How many times the view has been replaced, so a test can see that a redundant hide changes nothing.
    private(set) var renders = 0

    /// How many times the panel has been placed, so a test can see that one redraw moves it once.
    private(set) var placements = 0

    /// The ghost line's full width in this presentation's face, as the view would draw it with no room limit.
    private func width(of row: SuggestionPresentation.Row, in presentation: SuggestionPresentation) -> CGFloat
    {
        let line = SuggestionGhostLine(presentation: presentation, row: row)
        guard let measurer else {
            let made = NSHostingView(rootView: line)
            measurer = made
            return made.fittingSize.width
        }
        measurer.rootView = line
        return measurer.fittingSize.width
    }

    /// Takes the panel off screen, and says so to VoiceOver.
    private func withdraw() {
        announcer.surfaceWithdrawn()
        isActuallyShowing = false
        panel.orderOut(nil)
    }

    /// Redraws from the last request, measuring the new content before the panel is placed so old and new are never on screen together.
    @discardableResult
    private func render() -> Bool {
        // Nothing to place means no screen to look up.
        let room =
            request.suggestion == .silent
            ? nil
            : request.caret.flatMap {
                SuggestionGeometry.availableWidth(
                    caret: $0, field: request.field, window: request.window, screen: screenFrame)
            }
        var presentation = SuggestionPresentation(
            request.suggestion, typed: request.typed, selection: request.selection,
            fieldPointSize: request.fieldPointSize, appearance: Self.appearance(),
            acceptKey: request.acceptKey, fontFamily: request.fontFamily,
            fieldTextColor: request.textColor, maximumWidth: room)
        // A ghost cut short would hide words Tab inserts, so one that does not fit its room is not drawn at all.
        if let inline = presentation.inline, let room = presentation.maximumWidth,
            !SuggestionGeometry.fits(width(of: inline, in: presentation), in: room)
        {
            presentation = SuggestionPresentation(.silent)
        }
        hostingView.rootView = SuggestionView(
            presentation: presentation,
            onDesiredSize: { [weak self] size in self?.resize(to: size) })
        renders += 1
        guard presentation.style != .hidden else {
            withdraw()
            return false
        }
        let measured = hostingView.fittingSize
        if measured.width > 0, measured.height > 0 {
            panelSize = CGSize(width: measured.width.rounded(.up), height: measured.height.rounded(.up))
        }
        guard reposition() else {
            withdraw()
            return false
        }
        // `orderFrontRegardless`, never `makeKeyAndOrderFront`: no keyboard is taken; a panel already up is not fronted again.
        if !isActuallyShowing || !panel.isVisible { panel.orderFrontRegardless() }
        isActuallyShowing = true
        // The panel is out of VoiceOver's reach, so the offer and its accept key are spoken once as it appears.
        if let text = announcer.announcement(for: presentation) { announce(text) }
        return true
    }

    /// Asks VoiceOver to speak at low priority, so the echo of the user's own typing is not cut off.
    private static func post(_ text: String) {
        NSAccessibility.post(
            element: NSApplication.shared, notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.low.rawValue,
            ])
    }

    /// What Increase Contrast, Reduce Transparency and Reduce Motion are set to right now.
    private static func appearance() -> SuggestionAppearance {
        let workspace = NSWorkspace.shared
        return SuggestionAppearance(
            increasesContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
            reducesTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
            reducesMotion: workspace.accessibilityDisplayShouldReduceMotion)
    }

    /// Redraws when the user changes a display setting while the surface is on screen.
    private func observeAppearance() {
        appearanceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.render() }
        }
    }

    /// The view measures itself and reports what it wants; the panel follows and stays on screen.
    private func resize(to size: CGSize) {
        let wanted = CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
        guard wanted.width > 0, wanted.height > 0, wanted != panelSize else { return }
        panelSize = wanted
        guard drawn.style != .hidden else {
            isActuallyShowing = false
            return
        }
        guard reposition() else { return withdraw() }
        if !isActuallyShowing || !panel.isVisible { panel.orderFrontRegardless() }
        isActuallyShowing = true
    }

    /// Places the panel at the caret, or reports that there is nowhere on the line to draw it.
    @discardableResult
    private func reposition() -> Bool {
        guard
            let anchor = SuggestionGeometry.anchor(
                for: request.placement, caret: request.caret, window: request.window,
                field: request.field, screen: screenFrame, size: panelSize)
        else { return false }
        guard anchor.frame != panel.frame else { return true }
        placements += 1
        panel.setFrame(anchor.frame, display: true)
        return true
    }

    /// The screen the caret is on, so a field on another display is drawn there and not against the panel's last screen.
    private var screenHoldingCaret: NSScreen? {
        guard let caret = request.caret else { return nil }
        return NSScreen.screens.first { $0.frame.contains(CGPoint(x: caret.minX, y: caret.midY)) }
    }

    /// The screen's whole frame, Dock and menu bar bands included, since a full-screen window's own caret can sit in either.
    private var screenFrame: CGRect {
        // With no screen to place against, staying put beats moving somewhere arbitrary.
        (screenHoldingCaret ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first)?.frame
            ?? panel.frame
    }

    private func configurePanel() {
        panel.styleMask = [.nonactivatingPanel]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Nothing here is clickable — Tab takes the suggestion — so clicks pass through to the field.
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false
        // `orderOut` waits out AppKit's fade on the main thread, which would stall every keystroke over a ghost.
        panel.animationBehavior = .none
        PrivateWindowSharing.apply(to: panel)
        panel.contentView = hostingView
    }
}
