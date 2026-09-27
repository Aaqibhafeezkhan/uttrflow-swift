// The sidebar's avatar disc and the account picture decoded for it.

import AppKit
import SwiftUI

import struct Foundation.Data

/// The account's picture, decoded off the main thread and small, over the initials until it is ready.
struct SidebarAvatar: View {
    let initials: String
    let picture: Data?
    let size: CGFloat

    @State private var image: CGImage?

    init(initials: String, picture: Data?, size: CGFloat) {
        self.initials = initials
        self.picture = picture
        self.size = size
        _image = State(initialValue: picture.flatMap(AccountPictures.cached(for:)))
    }

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(.circle)
            } else {
                Text(initials)
                    .font(BrandFont.display(size: size * 0.39, weight: .semibold))
                    .foregroundStyle(IslandPalette.avatarInk)
                    .frame(width: size, height: size)
                    .background(
                        LinearGradient(
                            colors: IslandPalette.avatar, startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        in: .circle)
            }
        }
        .task(id: picture) {
            guard let picture else {
                image = nil
                return
            }
            image = await AccountPictures.image(for: picture)
        }
    }
}

/// The account picture at avatar size, decoded once per set of bytes and never on the main thread.
@MainActor
enum AccountPictures {
    /// The largest the avatar is drawn, in pixels on a Retina screen.
    static let pixels = 96
    private static var last: (data: Data, image: CGImage)?

    /// The decoded picture for these bytes, if it is the one already decoded.
    static func cached(for data: Data) -> CGImage? {
        last.flatMap { $0.data == data ? $0.image : nil }
    }

    /// The decoded picture for these bytes, decoding them away from the main thread when they are new.
    static func image(for data: Data) async -> CGImage? {
        if let image = cached(for: data) { return image }
        let limit = pixels
        let image = await Task.detached(priority: .userInitiated) {
            PictureDecoder.thumbnail(of: data, longestSide: limit)
        }.value
        if let image { last = (data, image) }
        return image
    }
}
