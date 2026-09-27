// Tests that the sidebar lights the page on screen, not the page its last presentation was built for.

import Foundation
import Testing
import UttrflowUX

@testable import Uttrflow

@MainActor
@Suite("The sidebar's highlight")
struct SidebarSelectionTests {
    /// A presentation built while Home was showing, as a redraw skipped out of sight leaves it.
    private let stale = SidebarPresenter.sidebar(
        for: SidebarSnapshot(selection: .page(.home), shortcutKeys: ["⌥"], now: Date()))

    private func lit(_ selection: SidebarDestination?) -> [String] {
        SidebarSection.allCases.flatMap { stale.items(in: $0) }
            .filter { SidebarView.isLit($0, given: selection) }.map(\.title)
    }

    @Test("History lights History even when the presentation still says Home")
    func followsThePage() {
        #expect(lit(.page(.history)) == ["History"])
        #expect(lit(.page(.insights)) == ["Insights"])
    }

    @Test("any Settings tab lights the one Settings row")
    func settingsTabs() {
        for tab in SettingsTab.allCases {
            #expect(lit(.settings(tab)) == ["Settings"])
        }
    }

    @Test("the account page lights no row, and no page defers to the presentation")
    func accountAndUnknown() {
        #expect(lit(.page(.account)).isEmpty)
        #expect(lit(nil) == ["Home"])
    }

}
