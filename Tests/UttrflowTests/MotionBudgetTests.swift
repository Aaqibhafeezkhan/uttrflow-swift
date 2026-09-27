// Tests for how much motion the app's animations are allowed.

import AppKit
import Foundation
import Testing
import UttrflowCore

@testable import Uttrflow

@Suite("How much motion the Mac allows")
struct MotionBudgetTests {
    @Test("moves the demonstration on a cool Mac with nothing asked of it")
    func demonstrationMovesByDefault() {
        #expect(MotionBudget().demonstrationMoves)
        #expect(MotionBudget(energy: EnergyConditions(thermal: .fair)).demonstrationMoves)
    }

    @Test("holds the demonstration still under Reduce Motion")
    func demonstrationStillUnderReduceMotion() {
        #expect(!MotionBudget(reducesMotion: true).demonstrationMoves)
    }

    @Test("holds the demonstration still in Low Power Mode")
    func demonstrationStillInLowPowerMode() {
        #expect(!MotionBudget(energy: EnergyConditions(isLowPowerMode: true)).demonstrationMoves)
    }

    @Test(
        "holds the demonstration still at serious thermal pressure and worse",
        arguments: [ThermalPressure.serious, .critical])
    func demonstrationStillWhenHot(_ pressure: ThermalPressure) {
        #expect(!MotionBudget(energy: EnergyConditions(thermal: pressure)).demonstrationMoves)
    }

    @Test("caps the demonstration at 30 frames a second")
    func demonstrationFrameCap() {
        #expect(MotionBudget.demonstrationFrameInterval == 1.0 / 30)
    }

    @Test("moves the working bars unless Reduce Motion is on")
    func workingBars() {
        #expect(MotionBudget().workingBarsMove)
        #expect(MotionBudget(energy: EnergyConditions(isLowPowerMode: true)).workingBarsMove)
        #expect(!MotionBudget(reducesMotion: true).workingBarsMove)
    }

    @Test("caps the dock at 60 frames a second on a Mac that asks for nothing less")
    func dockAtSixty() {
        #expect(MotionBudget().dockFrameInterval == 1.0 / 60)
        #expect(MotionBudget(reducesMotion: true).dockFrameInterval == 1.0 / 60)
        #expect(MotionBudget(energy: EnergyConditions(thermal: .fair)).dockFrameInterval == 1.0 / 60)
    }

    @Test(
        "caps the dock at the meter's 20 Hz data rate in Low Power Mode or under thermal pressure",
        arguments: [
            EnergyConditions(isLowPowerMode: true), EnergyConditions(thermal: .serious),
            EnergyConditions(thermal: .critical),
        ])
    func dockAtDataRate(_ energy: EnergyConditions) {
        #expect(MotionBudget(energy: energy).dockFrameInterval == 1.0 / 20)
        #expect(MotionBudget(energy: energy).dockFrameInterval == DockMetrics.meterArrivalInterval)
    }

    @MainActor
    @Test("reads this process's own conditions from the system")
    func readsTheSystem() {
        let current = MotionBudget.current()

        #expect(current.reducesMotion == NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        #expect(current.energy == EnergyConditions.current())
    }
}

@Suite("A one-off animation under Reduce Motion")
struct MotionBudgetAllowingTests {
    @Test("runs when the Mac asks for nothing and lands in place under Reduce Motion")
    func allowing() {
        #expect(MotionBudget().allowing(.easeOut) == .easeOut)
        #expect(MotionBudget(reducesMotion: true).allowing(.easeOut) == nil)
        #expect(MotionBudget(energy: EnergyConditions(isLowPowerMode: true)).allowing(.easeOut) == .easeOut)
    }
}
