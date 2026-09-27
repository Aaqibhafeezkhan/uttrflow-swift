// The signed-in person's picture or initials in a circle.

import UttrflowUX
import AppKit
import SwiftUI

/// Whoever is signed in, as a circle: their picture, or their initials on the lilac-to-teal disc.
struct AvatarView: View {
    let identity: AccountIdentity
    var size: CGFloat = 44
    /// The width of the faint ring drawn outside the circle; none by default.
    var ring: CGFloat = 0

    var body: some View {
        Group {
            if let picture = identity.picture, let image = NSImage(data: picture) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(identity.initials)
                    .font(BrandFont.display(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(ProfilePalette.avatarInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ProfilePalette.avatarDisc)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        // Outside the frame, so the ring never moves what is laid out beside the circle.
        .background { Circle().fill(ProfilePalette.avatarRing).padding(-ring).opacity(ring > 0 ? 1 : 0) }
        // The name is beside it on every page, so the circle is decoration to a screen reader.
        .accessibilityHidden(true)
    }
}
