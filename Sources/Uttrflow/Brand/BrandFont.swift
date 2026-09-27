// The display typeface the redesign sets headings in, bundled so no screen depends on the network.

import CoreText
import Foundation
import SwiftUI

/// Registers the bundled Outfit typeface and builds display fonts from it. See `Docs/redesign-tokens.md`.
enum BrandFont {
    /// The family name the typeface registers under.
    static let family = "Outfit"

    /// The bundled variable font file.
    static var fileURL: URL? {
        Bundle.module.url(forResource: "Outfit-Variable", withExtension: "ttf")
    }

    /// Whether the typeface is usable, registering it on first read.
    static let isAvailable: Bool = register(fileURL)

    /// Registers a font file for this process; a file already registered counts as success.
    static func register(_ url: URL?) -> Bool {
        guard let url else { return false }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return true }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) } ?? 0
        return code == CTFontManagerError.alreadyRegistered.rawValue
    }

    /// A display font in the brand typeface, or the system font when the typeface is missing.
    static func display(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        display(size: size, weight: weight, available: isAvailable)
    }

    /// A display font chosen by whether the typeface is available.
    static func display(size: CGFloat, weight: Font.Weight, available: Bool) -> Font {
        available ? .custom(family, size: size).weight(weight) : .system(size: size, weight: weight)
    }
}
