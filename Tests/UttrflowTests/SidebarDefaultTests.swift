// Tests for whether the sidebar opens with its names showing.

import Testing

@testable import Uttrflow

@MainActor
@Suite("The sidebar's remembered width")
struct SidebarDefaultTests {
    @Test("a first launch, with nothing remembered, opens the sidebar with its names showing")
    func opensOnFirstLaunch() {
        #expect(MainWindowController.isSidebarExpanded(stored: nil))
    }

    @Test("a sidebar left collapsed stays collapsed, and one left open stays open")
    func remembersTheLastChoice() {
        #expect(!MainWindowController.isSidebarExpanded(stored: false))
        #expect(MainWindowController.isSidebarExpanded(stored: true))
    }
}
