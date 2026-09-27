public import struct Foundation.Data

/// A pasteboard that marks every text write concealed, for words the app already knows are a secret.
public struct ConcealingPasteboard: Pasteboard {
    private let base: any Pasteboard

    /// Wraps the pasteboard the writes go through, so its announcements still happen.
    public init(_ base: any Pasteboard) {
        self.base = base
    }

    public func text() -> String? { base.text() }

    public func setText(_ text: String) { base.setConcealedText(text) }

    /// The formatted flavour is dropped, since a concealed write carries the plain words alone.
    public func setText(_ text: String, richText: String?) { base.setConcealedText(text) }

    public func setConcealedText(_ text: String) { base.setConcealedText(text) }

    public func setImage(_ data: Data) { base.setImage(data) }
}
