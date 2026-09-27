// Tells a view whether its window is the one being used, so animations stop when nobody is watching.

import AppKit
import SwiftUI

/// Tells a view whether its window has somebody's attention, by `WindowAttention`. See Docs/app-main-window.md.
extension View {
    /// Calls `onChange` with whether this view's window is the one being used, and the budget allows motion unless `includingMotionBudget` is false.
    func onWindowAttentionChange(
        includingMotionBudget: Bool = true, _ onChange: @escaping (Bool) -> Void
    ) -> some View {
        modifier(WindowAttentionModifier(includesMotionBudget: includingMotionBudget, onChange: onChange))
    }
}

/// Measures the part of the view its scroll view leaves uncovered and hands it to the reporter.
private struct WindowAttentionModifier: ViewModifier {
    let includesMotionBudget: Bool
    let onChange: (Bool) -> Void

    /// A reference, so a scroll reaches the reporter without re-evaluating the view's body.
    @State private var relay = VisibleFrameRelay()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                WindowAttention.uncoveredFrame(
                    size: proxy.size, inWindow: proxy.frame(in: .global),
                    scrollViewBounds: proxy.bounds(of: .scrollView))
            } action: {
                relay.frame = $0
            }
            .background(
                WindowAttentionReporter(
                    relay: relay, includesMotionBudget: includesMotionBudget, onChange: onChange
                )
                .allowsHitTesting(false))
    }
}

/// Carries the view's uncovered frame, in window coordinates from the top left, to the `NSView` that decides.
@MainActor
private final class VisibleFrameRelay {
    /// Nil until SwiftUI has measured the view once.
    var frame: CGRect? {
        didSet {
            if frame != oldValue { onChange?() }
        }
    }

    var onChange: (() -> Void)?
}

/// A zero-sized `NSView` whose only job is to have a `window`.
private struct WindowAttentionReporter: NSViewRepresentable {
    let relay: VisibleFrameRelay
    let includesMotionBudget: Bool
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = AttentionReportingView()
        view.includesMotionBudget = includesMotionBudget
        view.onChange = onChange
        view.relay = relay
        relay.onChange = { [weak view] in view?.recheck() }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? AttentionReportingView)?.includesMotionBudget = includesMotionBudget
        (view as? AttentionReportingView)?.onChange = onChange
    }
}

private final class AttentionReportingView: NSView {
    /// Whether the answer also asks the motion budget, or only whether the view is in sight.
    var includesMotionBudget = true
    var onChange: ((Bool) -> Void)?
    var relay: VisibleFrameRelay?
    /// The last answer given, so repeated notices do not restart a running animation.
    private var lastReported: Bool?

    /// Subscribes here because a view has no window until it is placed in one.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let centre = NotificationCenter.default
        centre.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        guard let window else {
            report(false)
            return
        }
        let windowNotices: [NSNotification.Name] = [
            NSWindow.didChangeOcclusionStateNotification, NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification, NSWindow.didMoveNotification,
            NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification,
        ]
        for name in windowNotices {
            centre.addObserver(self, selector: #selector(recheck), name: name, object: window)
        }
        let applicationNotices: [NSNotification.Name] = [
            NSApplication.didHideNotification, NSApplication.didUnhideNotification,
            NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
            NSApplication.didChangeScreenParametersNotification,
        ]
        for name in applicationNotices {
            centre.addObserver(self, selector: #selector(recheck), name: name, object: nil)
        }
        for notice in MotionBudget.changeNotices {
            notice.centre.addObserver(
                self, selector: #selector(motionBudgetChanged), name: notice.name, object: nil)
        }
        recheck()
    }

    /// Stops the animation while this view is out of the hierarchy, as switching pages does.
    override func viewDidHide() {
        super.viewDidHide()
        report(false)
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        recheck()
    }

    /// Rechecks on the main thread, since power and thermal notices arrive on the thread that posted them.
    @objc nonisolated private func motionBudgetChanged() {
        Task { @MainActor in self.recheck() }
    }

    @objc func recheck() {
        let attention = WindowAttention(
            isShown: window != nil && !isHiddenOrHasHiddenAncestor,
            isKey: window?.isKeyWindow ?? false,
            isApplicationActive: NSApp.isActive,
            isApplicationHidden: NSApp.isHidden,
            isOnScreen: window?.occlusionState.contains(.visible) ?? false,
            isViewVisible: isVisibleOnADisplay,
            motion: .current())
        report(includesMotionBudget ? attention.animates : attention.isAttended)
    }

    /// Whether the part of this view its scroll view leaves uncovered lies on a display, which a sliver of window does not promise.
    private var isVisibleOnADisplay: Bool {
        guard let window, let content = window.contentView else { return false }
        guard let uncovered = relay?.frame else { return true }
        let inContent =
            content.isFlipped
            ? uncovered : WindowAttention.flipped(uncovered, withinHeight: content.bounds.height)
        let onScreen =
            uncovered.isEmpty
            ? CGRect.zero : window.convertToScreen(content.convert(inContent, to: nil))
        return WindowAttention.isVisible(
            unclippedFrameOnScreen: onScreen, displays: NSScreen.screens.map(\.frame))
    }

    private func report(_ animates: Bool) {
        guard lastReported != animates else { return }
        lastReported = animates
        onChange?(animates)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
