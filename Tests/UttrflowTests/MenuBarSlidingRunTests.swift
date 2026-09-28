// Tests that the popover's sliding run moves only while allowed and in a window, and stays a third of its track.

import AppKit
import Testing

@testable import Uttrflow

@MainActor
@Suite("The menu bar popover's sliding run")
struct MenuBarSlidingRunTests {
    private static func run(moves: Bool) -> MenuBarSlidingRunView {
        let view = MenuBarSlidingRunView()
        view.frame = NSRect(x: 0, y: 0, width: 200, height: 3)
        view.moves = moves
        view.layout()
        return view
    }

    private static func window(holding view: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 3), styleMask: [.borderless],
            backing: .buffered,
            defer: true)
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(view)
        return window
    }

    @Test("waits a third of the track long, just off its leading end, with capsule ends")
    func restsOffTheTrack() {
        let view = Self.run(moves: false)
        #expect(view.run.frame == CGRect(x: -60, y: 0, width: 60, height: 3))
        #expect(view.run.cornerRadius == 1.5)
        #expect(view.layer?.masksToBounds == true)
        #expect(view.run.colors?.count == 2)
    }

    @Test("slides across and round again in a window when the budget allows")
    func slidesInAWindow() throws {
        let view = Self.run(moves: true)
        #expect(view.run.animation(forKey: MenuBarSlidingRunView.slideKey) == nil)
        let window = Self.window(holding: view)
        let slide = try #require(
            view.run.animation(forKey: MenuBarSlidingRunView.slideKey) as? CABasicAnimation)
        #expect(slide.fromValue as? CGFloat == -30)
        #expect(slide.toValue as? CGFloat == 230)
        #expect(slide.duration == MenuBarSlidingRunView.period)
        #expect(slide.repeatCount == .infinity)
        view.removeFromSuperview()
        #expect(view.run.animation(forKey: MenuBarSlidingRunView.slideKey) == nil)
        window.close()
    }

    @Test("holds still when the budget stops allowing motion")
    func stopsWhenTheBudgetSaysSo() {
        let view = Self.run(moves: true)
        let window = Self.window(holding: view)
        #expect(view.run.animation(forKey: MenuBarSlidingRunView.slideKey) != nil)
        view.moves = false
        #expect(view.run.animation(forKey: MenuBarSlidingRunView.slideKey) == nil)
        window.close()
    }

    @Test("is not hit, so clicks reach the popover under it")
    func passesClicksThrough() {
        #expect(Self.run(moves: false).hitTest(NSPoint(x: 10, y: 1)) == nil)
    }
}
