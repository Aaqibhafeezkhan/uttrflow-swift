// Tests that a hidden floating button draws nothing and reads no microphone level.

import Testing
import UttrflowPipeline

@testable import Uttrflow

@MainActor
@Suite("A hidden floating button")
struct DockVisibilityTests {
    private static func dock() -> DockPanelController {
        let dock = DockPanelController()
        dock.setLevelSource { 0.2 }
        return dock
    }

    @Test("draws nothing until it is first shown")
    func emptyUntilShown() {
        let dock = Self.dock()
        #expect(!dock.drawsContent)
        dock.show()
        defer { dock.hide() }
        #expect(dock.drawsContent)
    }

    @Test("empties itself when hidden, so no spinner or meter runs behind it")
    func emptiedWhenHidden() {
        let dock = Self.dock()
        dock.show()
        dock.update(with: DictationPresenter.dock(for: .tidying))
        dock.hide()
        #expect(!dock.isVisible)
        #expect(!dock.drawsContent)
    }

    @Test("reads the microphone for the meter only while it is on screen")
    func metersOnlyWhileShown() {
        let dock = Self.dock()
        dock.update(with: DictationPresenter.dock(for: .recording))
        #expect(!dock.isMetering)
        dock.show()
        #expect(dock.isMetering)
        dock.hide()
        #expect(!dock.isMetering)
        dock.show()
        #expect(dock.isMetering)
        dock.update(with: DictationPresenter.dock(for: .tidying))
        #expect(!dock.isMetering)
        dock.hide()
    }
}
