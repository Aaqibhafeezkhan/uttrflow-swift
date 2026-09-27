// Tests for when the home page's demonstration is allowed to move.

import CoreGraphics
import Testing
import UttrflowCore

@testable import Uttrflow

/// The card moves in the window being used and nowhere else, since a visible window is not a watched one.
@Suite("Whether a window has somebody's attention")
struct WindowAttentionTests {
    /// The main window on Home, key, in the active app, on screen.
    private let inUse = WindowAttention(
        isShown: true, isKey: true, isApplicationActive: true, isApplicationHidden: false,
        isOnScreen: true)

    @Test("moves while its window is key in the active app and Home is showing")
    func movesWhenInUse() {
        #expect(inUse.animates)
    }

    @Test("stays still when another window of the app has the keyboard")
    func stillWhenNotKey() {
        var attention = inUse
        attention.isKey = false

        #expect(!attention.animates)
    }

    @Test("stays still when partly visible behind another app's window")
    func stillWhenPartlyCovered() {
        var attention = inUse
        attention.isKey = false
        attention.isApplicationActive = false

        #expect(!attention.animates)
    }

    @Test("stays still when fully covered")
    func stillWhenCovered() {
        var attention = inUse
        attention.isOnScreen = false

        #expect(!attention.animates)
    }

    @Test("stays still when the app is hidden")
    func stillWhenHidden() {
        var attention = inUse
        attention.isApplicationHidden = true

        #expect(!attention.animates)
    }

    @Test("stays still once a different page is chosen")
    func stillOffHome() {
        var attention = inUse
        attention.isShown = false

        #expect(!attention.animates)
    }

    @Test("stays still under Reduce Motion, even in the window being used")
    func stillUnderReduceMotion() {
        var attention = inUse
        attention.motion = MotionBudget(reducesMotion: true)

        #expect(!attention.animates)
    }

    @Test("stays still in Low Power Mode, even in the window being used")
    func stillInLowPowerMode() {
        var attention = inUse
        attention.motion = MotionBudget(energy: EnergyConditions(isLowPowerMode: true))

        #expect(!attention.animates)
    }

    @Test("stays still at serious thermal pressure, even in the window being used")
    func stillWhenHot() {
        var attention = inUse
        attention.motion = MotionBudget(energy: EnergyConditions(thermal: .serious))

        #expect(!attention.animates)
    }

    @Test("stays still when the card is scrolled out of view in the window being used")
    func stillWhenScrolledOutOfView() {
        var attention = inUse
        attention.isViewVisible = false

        #expect(!attention.animates)
    }

    @Test("moves while any part of the card is in sight")
    func movesWhenTheCardIsInSight() {
        var attention = inUse
        attention.isViewVisible = true

        #expect(attention.animates)
    }

    @Test("counts as attended under Reduce Motion or Low Power Mode, which the caller judges for itself")
    func attendedIgnoresTheMotionBudget() {
        var attention = inUse
        attention.motion = MotionBudget(
            reducesMotion: true, energy: EnergyConditions(isLowPowerMode: true))

        #expect(attention.isAttended)
        #expect(!attention.animates)
    }

    @Test("is not attended when covered, hidden, behind another window or scrolled away")
    func notAttendedOutOfSight() {
        let changes: [(inout WindowAttention) -> Void] = [
            { $0.isOnScreen = false }, { $0.isApplicationHidden = true }, { $0.isKey = false },
            { $0.isApplicationActive = false }, { $0.isShown = false }, { $0.isViewVisible = false },
        ]
        for change in changes {
            var attention = inUse
            change(&attention)

            #expect(!attention.isAttended)
        }
    }
}

/// Whether a view's own frame can be seen, which a visible window does not settle.
@Suite("Whether a view inside a window is in sight")
struct ViewVisibilityTests {
    /// A 1728 by 1117 point display at the origin.
    private let display = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    @Test("is in sight when its frame lies on the display")
    func onTheDisplay() {
        let card = CGRect(x: 400, y: 300, width: 816, height: 240)

        #expect(WindowAttention.isVisible(unclippedFrameOnScreen: card, displays: [display]))
    }

    @Test("is in sight when only a sliver of it is on the display")
    func partlyOnTheDisplay() {
        let card = CGRect(x: 400, y: -230, width: 816, height: 240)

        #expect(WindowAttention.isVisible(unclippedFrameOnScreen: card, displays: [display]))
    }

    @Test("is out of sight once its scroll view clips all of it away, leaving an empty rectangle")
    func scrolledAway() {
        #expect(!WindowAttention.isVisible(unclippedFrameOnScreen: .zero, displays: [display]))
    }

    @Test("keeps the whole card when its scroll view's bounds cover it")
    func uncoveredWhenInsideTheScrollView() {
        let uncovered = WindowAttention.uncoveredFrame(
            size: CGSize(width: 816, height: 240), inWindow: CGRect(x: 100, y: 500, width: 816, height: 240),
            scrollViewBounds: CGRect(x: -100, y: -500, width: 1100, height: 760))

        #expect(uncovered == CGRect(x: 100, y: 500, width: 816, height: 240))
    }

    @Test("keeps only the strip of the card its scroll view's bounds still reach")
    func partlyUncovered() {
        let uncovered = WindowAttention.uncoveredFrame(
            size: CGSize(width: 816, height: 240), inWindow: CGRect(x: 100, y: 700, width: 816, height: 240),
            scrollViewBounds: CGRect(x: -100, y: -700, width: 1100, height: 760))

        #expect(uncovered == CGRect(x: 100, y: 700, width: 816, height: 60))
    }

    @Test(
        "is empty when the card is scrolled below its scroll view's bounds, as on a window opened at the top of Home"
    )
    func coveredWhenScrolledBelow() {
        let uncovered = WindowAttention.uncoveredFrame(
            size: CGSize(width: 816, height: 240), inWindow: CGRect(x: 100, y: 1000, width: 816, height: 240),
            scrollViewBounds: CGRect(x: -100, y: -1000, width: 1100, height: 760))

        #expect(uncovered == .zero)
        #expect(!WindowAttention.isVisible(unclippedFrameOnScreen: uncovered, displays: [display]))
    }

    @Test("is empty when the card is scrolled above its scroll view's bounds")
    func coveredWhenScrolledAbove() {
        let uncovered = WindowAttention.uncoveredFrame(
            size: CGSize(width: 816, height: 240), inWindow: CGRect(x: 100, y: -400, width: 816, height: 240),
            scrollViewBounds: CGRect(x: -100, y: 400, width: 1100, height: 760))

        #expect(uncovered == .zero)
    }

    @Test("keeps the whole card when it is not in a scroll view")
    func uncoveredOutsideAScrollView() {
        let uncovered = WindowAttention.uncoveredFrame(
            size: CGSize(width: 816, height: 240), inWindow: CGRect(x: 100, y: 500, width: 816, height: 240),
            scrollViewBounds: nil)

        #expect(uncovered == CGRect(x: 100, y: 500, width: 816, height: 240))
    }

    @Test("turns a frame measured from the top into one measured from the bottom")
    func flipsFromTheTop() {
        let flipped = WindowAttention.flipped(
            CGRect(x: 100, y: 500, width: 816, height: 240), withinHeight: 780)

        #expect(flipped == CGRect(x: 100, y: 40, width: 816, height: 240))
    }

    @Test("is out of sight past the bottom edge while its window still reaches onto the display")
    func pastTheBottomEdge() {
        let card = CGRect(x: 400, y: -260, width: 816, height: 240)

        #expect(!WindowAttention.isVisible(unclippedFrameOnScreen: card, displays: [display]))
    }

    @Test("is out of sight when it only touches the display's edge")
    func touchingTheEdge() {
        let card = CGRect(x: 1728, y: 300, width: 816, height: 240)

        #expect(!WindowAttention.isVisible(unclippedFrameOnScreen: card, displays: [display]))
    }

    @Test("is in sight on a second display beside the first")
    func onASecondDisplay() {
        let second = CGRect(x: 1728, y: 0, width: 1920, height: 1080)
        let card = CGRect(x: 2000, y: 300, width: 816, height: 240)

        #expect(WindowAttention.isVisible(unclippedFrameOnScreen: card, displays: [display, second]))
    }

    @Test("is out of sight with no display at all")
    func noDisplay() {
        let card = CGRect(x: 400, y: 300, width: 816, height: 240)

        #expect(!WindowAttention.isVisible(unclippedFrameOnScreen: card, displays: []))
    }
}
