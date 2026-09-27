// The popover's unknown-length progress run, slid by Core Animation so no frame re-renders the SwiftUI glass.

import AppKit

/// The track-shaped layer the run slides in, clipped to a capsule; it moves only while it is in a window.
final class MenuBarSlidingRunView: NSView {
    /// The run's share of the track's width.
    static let share: CGFloat = 0.3
    /// How long one crossing takes, in seconds.
    static let period: CFTimeInterval = 1.6
    /// The animation's key on the run's layer.
    static let slideKey = "slide"

    /// Whether the run moves; the popover sets it from the motion budget as that changes.
    var moves = MotionBudgetObserver.shared.budget.demonstrationMoves {
        didSet { if moves != oldValue { restart() } }
    }

    /// The run itself: the progress gradient, aurora blue into dictation teal.
    let run = CAGradientLayer()

    /// The width the running animation was built for.
    private var animatedWidth: CGFloat = 0

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        run.startPoint = CGPoint(x: 0, y: 0.5)
        run.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(run)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.cornerRadius = bounds.height / 2
        run.cornerRadius = bounds.height / 2
        let width = bounds.width * Self.share
        run.frame = CGRect(x: -width, y: 0, width: width, height: bounds.height)
        CATransaction.commit()
        if bounds.width != animatedWidth { restart() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restart()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        paint()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        run.contentsScale = window?.backingScaleFactor ?? 2
    }

    /// Resolves the gradient's colours for the view's appearance.
    private func paint() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            run.colors = MenuBarColour.progressStops.map(\.cgColor)
        }
    }

    /// Starts the slide from the leading end, or stops it when the run may not move or is in no window.
    private func restart() {
        run.removeAnimation(forKey: Self.slideKey)
        animatedWidth = bounds.width
        paint()
        let width = bounds.width * Self.share
        let slide = CABasicAnimation(keyPath: "position.x")
        slide.fromValue = -width / 2
        slide.toValue = bounds.width + width / 2
        slide.duration = Self.period
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        guard moves, window != nil, width > 0 else { return }
        slide.repeatCount = .infinity
        run.add(slide, forKey: Self.slideKey)
    }
}
