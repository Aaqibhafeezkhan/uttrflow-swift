// Tests for the clock that redraws home at each mood boundary and at midnight.

import AppKit
import Foundation
import Testing
import UttrflowUX

@testable import Uttrflow

@MainActor
@Suite("Home's clock")
struct HomeClockTests {
    /// A clock on its own notification centres, reading `time` for now and counting its redraws.
    @MainActor
    final class Rig {
        var time: Date
        var redraws = 0
        let center = NotificationCenter()
        let workspace = NotificationCenter()
        let calendar: Calendar
        private(set) var clock: HomeClock?

        init(hour: Int, minute: Int = 0) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .gmt
            self.calendar = calendar
            time = Self.at(calendar, hour: hour, minute: minute)
            clock = HomeClock(
                calendar: calendar, center: center, workspaceCenter: workspace,
                now: { [unowned self] in time }, redraw: { [unowned self] in redraws += 1 })
        }

        /// 27 September 2026 at `hour`:`minute` in the rig's zone.
        static func at(_ calendar: Calendar, hour: Int, minute: Int = 0) -> Date {
            calendar.date(
                from: DateComponents(year: 2026, month: 9, day: 27, hour: hour, minute: minute))
                ?? .distantPast
        }

        func at(hour: Int, minute: Int = 0) -> Date { Self.at(calendar, hour: hour, minute: minute) }
    }

    @Test("a drawing sets the timer for the next boundary once the window is in sight")
    func schedulesNextBoundary() throws {
        let rig = Rig(hour: 9, minute: 15)
        let clock = try #require(rig.clock)
        clock.drew(at: rig.time)
        #expect(clock.due == rig.at(hour: 12))
        #expect(clock.nextFire == nil)
        clock.setVisible(true)
        #expect(clock.nextFire == rig.at(hour: 12))
        #expect(rig.redraws == 0)
    }

    @Test("going out of sight stops the timer")
    func stopsOutOfSight() throws {
        let rig = Rig(hour: 9)
        let clock = try #require(rig.clock)
        clock.drew(at: rig.time)
        clock.setVisible(true)
        clock.setVisible(false)
        #expect(!clock.isRunning)
        #expect(clock.nextFire == nil)
    }

    @Test("coming into sight after a boundary passed redraws at once and waits for the next")
    func catchesUpOnSight() throws {
        let rig = Rig(hour: 9)
        let clock = try #require(rig.clock)
        clock.drew(at: rig.time)
        rig.time = rig.at(hour: 13, minute: 5)
        clock.setVisible(true)
        #expect(rig.redraws == 1)
        #expect(clock.nextFire == rig.at(hour: 17))
        clock.setVisible(true)
        #expect(rig.redraws == 1)
    }

    @Test("a window never drawn redraws on first sight")
    func redrawsWhenNeverDrawn() throws {
        let rig = Rig(hour: 9)
        let clock = try #require(rig.clock)
        clock.setVisible(true)
        #expect(rig.redraws == 1)
        #expect(clock.due == rig.at(hour: 12))
    }

    @Test("the timer firing redraws and moves on to the next boundary")
    func tickMovesOn() throws {
        let rig = Rig(hour: 11, minute: 59)
        let clock = try #require(rig.clock)
        clock.drew(at: rig.time)
        clock.setVisible(true)
        rig.time = rig.at(hour: 12)
        clock.tick()
        #expect(rig.redraws == 1)
        #expect(clock.due == rig.at(hour: 17))
        #expect(clock.nextFire == rig.at(hour: 17))
    }

    @Test("drawings before the boundary keep the same timer")
    func redrawsBeforeBoundaryKeepTimer() throws {
        let rig = Rig(hour: 9)
        let clock = try #require(rig.clock)
        clock.drew(at: rig.time)
        clock.setVisible(true)
        clock.drew(at: rig.at(hour: 10))
        clock.drew(at: rig.at(hour: 11, minute: 59))
        #expect(clock.due == rig.at(hour: 12))
        #expect(clock.nextFire == rig.at(hour: 12))
    }

    @Test(
        "a wake, a clock change or a new day redraws at once while in sight",
        arguments: [
            Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange,
            .NSCalendarDayChanged, NSWorkspace.didWakeNotification,
        ])
    func timeChangeRedraws(name: Notification.Name) throws {
        let rig = Rig(hour: 9)
        let clock = try #require(rig.clock)
        clock.drew(at: rig.time)
        clock.setVisible(true)
        let center = name == NSWorkspace.didWakeNotification ? rig.workspace : rig.center
        center.post(name: name, object: nil)
        #expect(rig.redraws == 1)
        #expect(clock.nextFire == rig.at(hour: 12))
    }

    @Test("a clock set back while out of sight redraws on next sight")
    func clockSetBackOutOfSight() throws {
        let rig = Rig(hour: 13)
        let clock = try #require(rig.clock)
        clock.drew(at: rig.time)
        rig.time = rig.at(hour: 9)
        rig.center.post(name: .NSSystemClockDidChange, object: nil)
        #expect(rig.redraws == 0)
        #expect(clock.due == nil)
        clock.setVisible(true)
        #expect(rig.redraws == 1)
        #expect(clock.nextFire == rig.at(hour: 12))
    }
}
