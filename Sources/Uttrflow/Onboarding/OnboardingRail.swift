// The rail ground Settings draws, and the reproducible noise its grain and onboarding's are made from.

import AppKit
import UttrflowUX
import SwiftUI

/// The Settings rail's ground: the accent deepened until white sits on it, in both appearances.
struct RailGround: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(rgb: BrandPalette.Teal.railTop),
                Color(rgb: BrandPalette.Teal.railMiddle),
                Color(rgb: BrandPalette.Teal.railBottom),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(
            RadialGradient(
                colors: [Color.dockAccentLight.opacity(0.30), .clear],
                center: UnitPoint(x: 0.14, y: 0), startRadius: 0, endRadius: 300)
        )
        .overlay(RailPattern())
    }
}

/// A handful of out-of-focus lights under film grain, all white below 8%; the grain hides gradient banding.
private struct RailPattern: View {
    /// Each light as a fraction of the rail, so the arrangement survives a taller window.
    private struct Light {
        let x: CGFloat
        let y: CGFloat
        let diameter: CGFloat
        let alpha: Double
    }

    private static let lights = [
        Light(x: 150, y: 0.635, diameter: 120, alpha: 0.07),
        Light(x: 24, y: 0.808, diameter: 86, alpha: 0.05),
        Light(x: 176, y: 0.869, diameter: 64, alpha: 0.06),
        Light(x: 96, y: 0.742, diameter: 46, alpha: 0.05),
        Light(x: -14, y: 0.577, diameter: 70, alpha: 0.04),
        Light(x: 188, y: 0.481, diameter: 40, alpha: 0.05),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array(Self.lights.enumerated()), id: \.offset) { _, light in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(light.alpha), .white.opacity(0)],
                                center: .center, startRadius: 0,
                                endRadius: light.diameter * 0.34)
                        )
                        .frame(width: light.diameter, height: light.diameter)
                        .offset(x: light.x, y: proxy.size.height * light.y)
                }
                Grain()
            }
        }
        .allowsHitTesting(false)
    }
}

/// Film grain, drawn once and rasterised; deterministic, so it does not shimmer when the window resizes.
private struct Grain: View {
    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            var generator = SplitMix64(seed: 0x5F_E0D3_29C0)
            let dot = Path(CGRect(x: 0, y: 0, width: 1, height: 1))
            for _ in 0..<2400 {
                let x = generator.fraction() * size.width
                let y = generator.fraction() * size.height
                context.fill(
                    dot.offsetBy(dx: x, dy: y),
                    with: .color(.white.opacity(0.02 + generator.fraction() * 0.05)))
            }
        }
        // Rasterised once rather than re-run on every redraw of the page beside it.
        .drawingGroup()
        .blendMode(.plusLighter)
    }
}

/// Sixty-four bits of reproducible noise, small enough to read.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func fraction() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}
