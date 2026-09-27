import AppKit
import ApplicationServices
import CoreText
import Foundation
import UttrflowPredict

private import Synchronization

/// The frontmost application's identity, taken on the main thread where `NSWorkspace` is safe to read.
public struct FrontmostApp: Sendable {
    /// Addresses the app for the Accessibility read.
    public let processIdentifier: Int32
    /// The app's bundle identifier, which every capability table is keyed by.
    public let bundleIdentifier: String
    /// The app as the user knows it, cleaned of the marks some applications pad it with.
    public let name: String

    public init(processIdentifier: Int32, bundleIdentifier: String, name: String) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }
}

/// Reads the focused field once, for everything the suggestion loop needs. See `Docs/predict.md`.
public enum FocusedFieldReader {
    /// Its own thread, because these calls block until the other application answers.
    private static let queue = LatestOnlyQueue(label: "com.uttrflow.focused-field", qos: .userInitiated)

    /// The primary screen's top edge, cached because `NSScreen` is main-thread-only and this reads off it.
    private static let cachedPrimaryScreenMaxY = Mutex<CGFloat>(0)

    /// Whether the caches are already being kept up to date, so preparing twice observes once.
    @MainActor private static var prepared = false

    /// Fills the caches the off-main read depends on and keeps them filled. See `Docs/predict-ime.md`.
    @MainActor
    public static func prepare() {
        guard !prepared else { return }
        prepared = true
        CompositionProbe.startObservingInputSource()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil
        ) { _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { refreshPrimaryScreenMaxY() } }
        }
        refreshPrimaryScreenMaxY()
    }

    /// Asks AppKit where the primary screen ends, the one place in the read path that touches `NSScreen`.
    @MainActor
    private static func refreshPrimaryScreenMaxY() {
        let maxY = NSScreen.screens.first?.frame.maxY ?? 0
        cachedPrimaryScreenMaxY.withLock { $0 = maxY }
    }

    /// The frontmost application's identity, or `nil` when it is Uttrflow, whose AX tree must not be walked off the main actor.
    @MainActor
    public static func frontmostApp() -> FrontmostApp? {
        guard let app = NSWorkspace.shared.frontmostApplication,
            let bundleIdentifier = app.bundleIdentifier,
            bundleIdentifier != Bundle.main.bundleIdentifier
        else { return nil }
        // Some applications pad their name with control and direction marks, which would reach the model verbatim.
        let name = Surroundings.cleaned(app.localizedName ?? bundleIdentifier)
            .trimmingCharacters(in: .whitespaces)
        return FrontmostApp(
            processIdentifier: app.processIdentifier, bundleIdentifier: bundleIdentifier,
            name: name.isEmpty ? bundleIdentifier : name)
    }

    /// One reading, off the main thread, or `nil` when nothing usable is focused.
    public static func read() async -> FocusedFieldSnapshot? {
        // Identity is taken on the main actor first, because the blocking read below may not touch `NSWorkspace`.
        guard let app = await frontmostApp() else { return nil }
        // A field that stops answering costs the turn half a second at most, and no later turn waits behind it.
        return await queue.run(within: .milliseconds(500)) { isWanted in
            let reading = snapshot(app: app, while: isWanted)
            // A browser engine answers zero-size caret bounds until its full tree is on.
            if FullTreeSwitch.isNeeded(in: app.bundleIdentifier, after: reading) {
                fullTree.switchOn(
                    processIdentifier: app.processIdentifier, bundleIdentifier: app.bundleIdentifier,
                    host: fullTreeHost(app.processIdentifier))
            }
            return reading
        }
    }

    /// The full Accessibility trees the suggestion loop turned on, kept so stopping the loop turns them off.
    private static let fullTree = FullTreeSwitch()

    /// Turns off every browser engine's full tree the suggestion loop turned on.
    public static func releaseFullTrees() {
        fullTree.switchOffEverything(host: fullTreeHost)
    }

    /// One application's full-tree switches, each message capped so a stalled application cannot hold the caller.
    private static func fullTreeHost(_ processIdentifier: Int32) -> FullTreeSwitch.Host {
        let application = AXUIElementCreateApplication(processIdentifier)
        _ = AXUIElementSetMessagingTimeout(application, elementTimeoutInSeconds)
        return FullTreeSwitch.Host(
            read: { attribute in
                var value: AnyObject?
                guard AXUIElementCopyAttributeValue(application, attribute as CFString, &value) == .success
                else { return nil }
                return (value as? NSNumber)?.boolValue
            },
            write: { attribute, isOn in
                AXUIElementSetAttributeValue(
                    application, attribute as CFString, isOn ? kCFBooleanTrue : kCFBooleanFalse) == .success
            })
    }

    /// Its own thread for the wider walk, so an application slow to describe its window never holds up a field read.
    private static let surroundingsQueue = LatestOnlyQueue(
        label: "com.uttrflow.surroundings", qos: .utility)

    /// How long one Accessibility call into another application may wait, since a stalled one would otherwise wait seconds.
    static let elementTimeoutInSeconds: Float = 0.05

    /// How long the turn waits for the wider walk before going on without it.
    private static let surroundingsAllowance = Duration.milliseconds(200)

    /// What is on screen around the focused field, or `nil` when nothing usable is focused or the wait ran out.
    public static func surroundings() async -> Surroundings? {
        guard let app = await frontmostApp() else { return nil }
        // A walk that does not answer in time is left to finish; a newer walk replaces one still queued.
        return await surroundingsQueue.run(within: surroundingsAllowance) { _ in surroundings(of: app) }
    }

    /// The same read synchronously, for an application front or not, which is what a probe shows the operator.
    public static func surroundings(of app: FrontmostApp) -> Surroundings? {
        // A field with no window, or a window focused as a whole, has nothing around it worth a walk.
        guard AXIsProcessTrusted(), let field = SurfaceProbe.focusedField(of: app.processIdentifier),
            let window = element(field, kAXWindowAttribute), !CFEqual(field, window)
        else { return nil }
        let answers = AXNode(window).answers
        return Surroundings.collect(
            around: AXNode(field), in: AXElementTree(), windowTitle: answers.title, windowFrame: answers.frame
        )
    }

    /// The fields whose reads ran past their budget lately, which are left alone until their rest is over.
    static let slowFields = SlowFields()

    /// The same reading, synchronously, for the queue above and for the capability probe; the identity is read on main.
    static func snapshot(
        app: FrontmostApp, while isWanted: @Sendable () -> Bool = { true }
    ) -> FocusedFieldSnapshot? {
        let started = DispatchTime.now().uptimeNanoseconds
        guard AXIsProcessTrusted(), let field = SurfaceProbe.focusedField(of: app.processIdentifier)
        else { return nil }
        let slow = SlowFields.Key(process: app.processIdentifier, element: CFHash(field))
        // A field whose read ran over lately is asked nothing, so a heavy document does not stall its application every turn.
        guard !slowFields.isResting(slow, at: started) else { return nil }
        // Every question to the field gives up quickly, so a field that stops answering costs a moment, not the loop.
        _ = AXUIElementSetMessagingTimeout(field, elementTimeoutInSeconds)
        let budget = FieldReadBudget(started: started)
        var ranOver = false
        // Checked before every question after the first: a superseded read stops, and one past its budget stops and rests the field.
        let goOn: () -> Bool = {
            guard isWanted() else { return false }
            guard budget.isSpent(at: DispatchTime.now().uptimeNanoseconds) else { return true }
            ranOver = true
            return false
        }
        let answer = read(field, of: app, started: started, while: goOn)
        if ranOver {
            slowFields.ranOver(slow, at: DispatchTime.now().uptimeNanoseconds)
        } else if answer != nil {
            slowFields.answered(slow)
        }
        return answer
    }

    /// Everything the snapshot holds, each question asked once and none after `goOn` says stop.
    private static func read(
        _ field: AXUIElement, of app: FrontmostApp, started: UInt64, while goOn: () -> Bool
    ) -> FocusedFieldSnapshot? {
        let identity = identity(of: field)
        guard let role = identity.role else { return nil }
        // Decided before the value is fetched, so a declared secure field's contents are never read at all.
        let declaredSecure = SecureField.isDeclaredSecure(
            role: role, subrole: identity.subrole, identifier: identity.identifier,
            placeholder: identity.placeholder, description: identity.description)
        guard goOn() else { return nil }
        // A web field that refuses the character range still says where its selection is in text markers.
        let range =
            SurfaceProbe.selectedRange(field) ?? (declaredSecure || !goOn() ? nil : markerSelection(field))
        guard goOn() else { return nil }
        let read = declaredSecure ? (value: nil, selection: nil) : boundedValue(of: field, at: range)
        let value = read.value
        let secure = declaredSecure || (value.map(SecureField.looksMasked) ?? false)
        guard goOn() else { return nil }
        // The attributed string carries the characters, so a secure field is never asked for its style.
        let style = secure ? nil : range.flatMap { typeStyle(field, at: $0) }
        guard goOn() else { return nil }
        let flipped = cachedPrimaryScreenMaxY.withLock { $0 }
        let marked = CompositionProbe.markedText(of: field)
        guard goOn() else { return nil }
        let window = element(field, kAXWindowAttribute)
        guard goOn() else { return nil }
        let document = document(of: field, in: window)
        guard goOn() else { return nil }
        let fieldRect = frame(of: field)
        guard goOn() else { return nil }
        let caretRect = caret(field, at: range, frame: fieldRect, pointSize: style?.size, while: goOn)
        guard goOn() else { return nil }
        let windowRect = window.flatMap { frame(of: $0) }
        guard goOn() else { return nil }
        let title = window.flatMap { SurfaceProbe.string($0, kAXTitleAttribute) }
        guard goOn() else { return nil }
        // An editor that draws its own text keeps an empty input at the caret, so its line is read off the rendered text.
        let hidden =
            secure ? nil : hiddenInputLine(field, role: role, value: value, frame: fieldRect, while: goOn)

        return FocusedFieldSnapshot(
            bundleIdentifier: app.bundleIdentifier,
            applicationName: app.name,
            role: role,
            subrole: identity.subrole,
            identifier: identity.identifier,
            placeholder: identity.placeholder,
            accessibilityDescription: identity.description,
            document: document,
            value: secure ? nil : hidden.map { $0.before + $0.after } ?? value,
            selection: hidden.map { NSRange(location: $0.before.utf16.count, length: 0) } ?? read.selection,
            caret: (hidden?.caret ?? caretRect).map { flip($0, below: flipped) },
            window: windowRect.map { flip($0, below: flipped) },
            field: (hidden?.line ?? fieldRect).flatMap {
                FocusedFieldSnapshot.isCaretShaped($0) ? nil : flip($0, below: flipped)
            },
            pointSize: style?.size,
            fontFamily: style?.family,
            textColor: style?.color,
            isSecure: secure,
            isComposing: Composition.isComposing(
                markedText: marked, inputSource: CompositionProbe.inputSourceKind()),
            markedText: marked,
            readMicroseconds: Int((DispatchTime.now().uptimeNanoseconds - started) / 1000),
            windowTitle: title
        )
    }

    /// The caret's line read off an editor's rendered text, for the empty caret-sized input such an editor keeps focused.
    private static func hiddenInputLine(
        _ field: AXUIElement, role: String, value: String?, frame: CGRect?, while goOn: () -> Bool
    ) -> HiddenInputLine.Reading? {
        guard FocusedFieldSnapshot.isTextEntry(role), let frame,
            HiddenInputLine.isStub(value: value, frame: frame)
        else { return nil }
        return HiddenInputLine.read(around: AXNode(field), at: frame, in: AXElementTree(), while: goOn)
    }

    /// What names the field, asked in one message: its role and the four names it may publish for itself.
    private static func identity(
        of field: AXUIElement
    ) -> (role: String?, subrole: String?, identifier: String?, placeholder: String?, description: String?) {
        let attributes = [
            kAXRoleAttribute, kAXSubroleAttribute, kAXIdentifierAttribute, kAXPlaceholderValueAttribute,
            kAXDescriptionAttribute,
        ]
        var answers: CFArray?
        let result = AXUIElementCopyMultipleAttributeValues(
            field, attributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &answers)
        // An element that will not answer the batch is asked one attribute at a time instead.
        guard result == .success, let values = answers as? [AnyObject], values.count == attributes.count
        else {
            let named = attributes.map { SurfaceProbe.string(field, $0) }
            return (named[0], named[1], named[2], named[3], named[4])
        }
        let named = values.map { $0 as? String }
        return (named[0], named[1], named[2], named[3], named[4])
    }

    /// The field's value around the caret, with the selection moved into it, so a long scrollback is never copied whole.
    private static func boundedValue(
        of field: AXUIElement, at range: CFRange?
    ) -> (value: String?, selection: NSRange?) {
        let selection = range.map { NSRange(location: $0.location, length: $0.length) }
        let count: Int? = selection == nil ? nil : SurfaceProbe.integer(field, kAXNumberOfCharactersAttribute)
        return ValueWindow.read(
            count: count, selection: selection,
            whole: { SurfaceProbe.string(field, kAXValueAttribute) },
            part: { window in
                SurfaceProbe.parameterized(
                    field, kAXStringForRangeParameterizedAttribute,
                    CFRange(location: window.location, length: window.length)) as? String
            })
    }

    /// Accessibility measures from the top of the primary screen; AppKit measures from the bottom.
    private static func flip(_ rect: CGRect, below primaryScreenMaxY: CGFloat) -> CGRect {
        SuggestionGeometry.fromAccessibility(rect, primaryScreenMaxY: primaryScreenMaxY)
    }

    /// An attribute that is an element, under the same short timeout the field itself answers under.
    private static func element(_ owner: AXUIElement, _ attribute: String) -> AXUIElement? {
        SurfaceProbe.element(owner, attribute, timeoutInSeconds: elementTimeoutInSeconds)
    }

    /// The page or the directory the field belongs to, which the window publishes when the field does not.
    private static func document(of field: AXUIElement, in window: AXUIElement?) -> String? {
        if let own = SurfaceProbe.string(field, kAXDocumentAttribute) { return own }
        return window.flatMap { SurfaceProbe.string($0, kAXDocumentAttribute) }
    }

    /// An element's rectangle as Accessibility reports it, or nothing when it gives no position or no size.
    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let origin: CGPoint = SurfaceProbe.value(element, kAXPositionAttribute, .cgPoint),
            let size: CGSize = SurfaceProbe.value(element, kAXSizeAttribute, .cgSize)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// The caret's screen rectangle, from the selection where the field answers it and from the text marker where it does not; `frame` is the field's own, already read.
    private static func caret(
        _ field: AXUIElement, at range: CFRange?, frame: CGRect?, pointSize: CGFloat?, while goOn: () -> Bool
    ) -> CGRect? {
        CaretLocator.caret(
            at: range.map { (location: $0.location, length: $0.length) }, frame: frame, pointSize: pointSize,
            bounds: { goOn() ? SurfaceProbe.bounds(field, at: CFRange(location: $0, length: $1)) : nil },
            markerBounds: { goOn() ? markerBounds(field) : nil })
    }

    /// What a field says about its own type, either half of which it may leave out.
    struct TypeStyle: Sendable, Equatable {
        /// The type size in points, so the ghost matches the line it sits on.
        let size: CGFloat?
        /// The font family, so the ghost is set in the face the line is.
        let family: String?
        /// The text colour, so the ghost reads against the field rather than against Uttrflow's appearance.
        var color: TextColor?
    }

    /// One element of another application, compared the way Accessibility compares them, its answers kept once asked.
    struct AXNode: Equatable {
        let element: AXUIElement
        let answers: Answers

        init(_ element: AXUIElement) {
            self.element = element
            answers = Answers(element)
            // Every question to this element gives up quickly, so a window that stops answering costs a moment, not the loop.
            _ = AXUIElementSetMessagingTimeout(element, elementTimeoutInSeconds)
        }

        static func == (lhs: AXNode, rhs: AXNode) -> Bool { CFEqual(lhs.element, rhs.element) }
    }

    /// What the collector asks one element: its shape in a single message, and its value apart, only when its text is read.
    final class Answers {
        /// The attributes asked for together, in the order the answers come back, the value left out since it can be a whole document.
        static let attributes = [
            kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute, kAXTitleAttribute,
            kAXDescriptionAttribute, kAXChildrenAttribute, kAXParentAttribute, kAXSubroleAttribute,
            kAXIdentifierAttribute, kAXPlaceholderValueAttribute,
        ]

        /// How many UTF-16 units of a long value are read from its end, twice the per-element cap so cleaning still leaves enough.
        static let valueReadLimit = Surroundings.maximumCharactersPerElement * 2

        private let element: AXUIElement
        private var fetched: [AnyObject]?
        private var valueRead: String??

        init(_ element: AXUIElement) {
            self.element = element
        }

        /// Answers already in hand, one per attribute, so a test can ask them without another application.
        init(_ element: AXUIElement, fetched: [AnyObject]) {
            self.element = element
            self.fetched = fetched.count == Self.attributes.count ? fetched : []
        }

        /// The answers, one per attribute, an element that does not answer at all standing as none.
        private var values: [AnyObject] {
            if let fetched { return fetched }
            var answers: CFArray?
            let result = AXUIElementCopyMultipleAttributeValues(
                element, Self.attributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &answers)
            let values = result == .success ? (answers as? [AnyObject]) ?? [] : []
            fetched = values.count == Self.attributes.count ? values : []
            return fetched ?? []
        }

        /// One answer by attribute, or nothing when the element did not answer.
        private subscript(_ attribute: String) -> AnyObject? {
            Self.attributes.firstIndex(of: attribute).flatMap {
                values.indices.contains($0) ? values[$0] : nil
            }
        }

        var role: String? { self[kAXRoleAttribute] as? String }
        var title: String? { self[kAXTitleAttribute] as? String }

        /// Whether the element declares itself secure by role, subrole or name, asked of the answers already fetched.
        var isSecure: Bool {
            SecureField.isDeclaredSecure(
                role: role, subrole: self[kAXSubroleAttribute] as? String,
                identifier: self[kAXIdentifierAttribute] as? String,
                placeholder: self[kAXPlaceholderValueAttribute] as? String,
                description: self[kAXDescriptionAttribute] as? String)
        }

        /// What the element says: the end of its value, else its title, else its description, and nothing for a secure element.
        var text: String? {
            guard !isSecure else { return nil }
            let candidates: [() -> String?] = [
                { self.value }, { self[kAXTitleAttribute] as? String },
                { self[kAXDescriptionAttribute] as? String },
            ]
            for candidate in candidates {
                if let text = candidate(), text.contains(where: { !$0.isWhitespace }) { return text }
            }
            return nil
        }

        /// The element's value, read once and only its last ``valueReadLimit`` units when the element can say how long it is.
        private var value: String? {
            if let valueRead { return valueRead }
            let read = Self.tail(of: element)
            valueRead = .some(read)
            return read
        }

        /// The end of an element's value by range where it is long, else the whole value, which is short or of unknown length.
        private static func tail(of element: AXUIElement) -> String? {
            var length: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXNumberOfCharactersAttribute as CFString, &length)
                == .success,
                let count = (length as? NSNumber)?.intValue, count > valueReadLimit
            {
                let range = CFRange(location: count - valueReadLimit, length: valueReadLimit)
                if let tail = SurfaceProbe.parameterized(
                    element, kAXStringForRangeParameterizedAttribute, range)
                    as? String
                {
                    return tail
                }
            }
            var value: AnyObject?
            guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success
            else {
                return nil
            }
            return value as? String
        }

        /// Where the element is, or nothing when it reports no position or no size.
        var frame: CGRect? {
            guard let origin: CGPoint = SurfaceProbe.unwrap(self[kAXPositionAttribute], .cgPoint),
                let size: CGSize = SurfaceProbe.unwrap(self[kAXSizeAttribute], .cgSize)
            else { return nil }
            return CGRect(origin: origin, size: size)
        }

        var children: [AXUIElement] { self[kAXChildrenAttribute] as? [AXUIElement] ?? [] }

        var parent: AXUIElement? {
            guard let value = self[kAXParentAttribute], CFGetTypeID(value) == AXUIElementGetTypeID() else {
                return nil
            }
            // Checked by type ID above; `as?` on a Core Foundation type always succeeds.
            return unsafeDowncast(value, to: AXUIElement.self)
        }
    }

    /// The other application's window as the surroundings collector walks it, one Accessibility message per element.
    struct AXElementTree: ElementTree {
        func role(of node: AXNode) -> String? { node.answers.role }
        func isSecure(_ node: AXNode) -> Bool { node.answers.isSecure }
        func text(of node: AXNode) -> String? { node.answers.text }
        func frame(of node: AXNode) -> CGRect? { node.answers.frame }
        func children(of node: AXNode) -> [AXNode] { node.answers.children.map(AXNode.init) }

        /// The element's parent, stopping at the window so the walk never crosses into the application's other windows.
        func parent(of node: AXNode) -> AXNode? {
            guard node.answers.role != kAXWindowRole, let parent = node.answers.parent.map(AXNode.init),
                parent.answers.role != kAXApplicationRole
            else { return nil }
            return parent
        }
    }

    /// The font at the caret, so the ghost is set in the field's own face and size.
    private static func typeStyle(_ field: AXUIElement, at range: CFRange) -> TypeStyle? {
        let widened = AccessibilityRange.widenedForStyle(range)
        guard
            let answer = SurfaceProbe.parameterized(
                field, kAXAttributedStringForRangeParameterizedAttribute, widened),
            CFGetTypeID(answer) == CFAttributedStringGetTypeID()
        else { return nil }
        // Checked by type ID above; `as?` on a Core Foundation type always succeeds.
        return typeStyle(inAttributed: unsafeDowncast(answer, to: CFAttributedString.self))
    }

    /// The font size in an attributed string, from whichever form the application answered in.
    static func pointSize(inAttributed attributed: CFAttributedString) -> CGFloat? {
        typeStyle(inAttributed: attributed)?.size
    }

    /// The font in an attributed string: a Core Text font where AppKit put one, else the `AXFont` dictionary most applications answer with.
    static func typeStyle(inAttributed attributed: CFAttributedString) -> TypeStyle? {
        guard CFAttributedStringGetLength(attributed) > 0 else { return nil }
        let color = textColor(inAttributed: attributed)
        if let font = CFAttributedStringGetAttribute(attributed, 0, kCTFontAttributeName, nil),
            CFGetTypeID(font) == CTFontGetTypeID()
        {
            // Checked by type ID above; `as?` on a Core Foundation type always succeeds.
            let font = unsafeDowncast(font, to: CTFont.self)
            return TypeStyle(
                size: CTFontGetSize(font), family: CTFontCopyFamilyName(font) as String, color: color)
        }
        var size: CGFloat?
        var family: String?
        if let described = CFAttributedStringGetAttribute(attributed, 0, Self.axFontKey as CFString, nil),
            CFGetTypeID(described) == CFDictionaryGetTypeID()
        {
            // Checked by type ID above; a Core Foundation dictionary bridges to Foundation without AppKit.
            let font = unsafeDowncast(described, to: CFDictionary.self) as NSDictionary
            size = (font[Self.axFontSizeKey] as? NSNumber).map { CGFloat($0.doubleValue) }
            family = font[Self.axFontFamilyKey] as? String
        }
        guard size != nil || family != nil || color != nil else { return nil }
        return TypeStyle(size: size, family: family, color: color)
    }

    /// The text colour at the start of an attributed string, from the Accessibility key or the Core Text one.
    static func textColor(inAttributed attributed: CFAttributedString) -> TextColor? {
        let keys = [Self.axForegroundColorKey as CFString, kCTForegroundColorAttributeName]
        for key in keys {
            if let color = textColor(CFAttributedStringGetAttribute(attributed, 0, key, nil)) { return color }
        }
        return nil
    }

    /// A Core Graphics colour as sRGB, or nothing for a value that is not one or cannot be converted.
    static func textColor(_ value: CFTypeRef?) -> TextColor? {
        guard let value, CFGetTypeID(value) == CGColor.typeID,
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        // Checked by type ID above; `as?` on a Core Foundation type always succeeds.
        let color = unsafeDowncast(value, to: CGColor.self)
        guard let converted = color.converted(to: sRGB, intent: .defaultIntent, options: nil),
            let channels = converted.components, channels.count >= 3
        else { return nil }
        return TextColor(red: Double(channels[0]), green: Double(channels[1]), blue: Double(channels[2]))
    }

    /// The attribute Accessibility describes a run's font under, which is a dictionary rather than a font object.
    private static let axFontKey = "AXFont"
    private static let axFontSizeKey = "AXFontSize"
    private static let axFontFamilyKey = "AXFontFamily"
    private static let axForegroundColorKey = "AXForegroundColor"

    /// The selection as a character range, measured in text markers from the field's start, for a field that refuses `AXSelectedTextRange`.
    private static func markerSelection(_ field: AXUIElement) -> CFRange? {
        var selected: AnyObject?
        guard
            AXUIElementCopyAttributeValue(field, "AXSelectedTextMarkerRange" as CFString, &selected)
                == .success,
            let selected, CFGetTypeID(selected) == AXTextMarkerRangeGetTypeID(),
            let whole = SurfaceProbe.parameterized(field, "AXTextMarkerRangeForUIElement", field),
            CFGetTypeID(whole) == AXTextMarkerRangeGetTypeID()
        else { return nil }
        // Checked by type ID above; `as?` on a Core Foundation type always succeeds.
        let selection = unsafeDowncast(selected, to: AXTextMarkerRange.self)
        let start = AXTextMarkerRangeCopyStartMarker(unsafeDowncast(whole, to: AXTextMarkerRange.self))
        let before = AXTextMarkerRangeCreate(nil, start, AXTextMarkerRangeCopyStartMarker(selection))
        guard let location = markerLength(field, before), let length = markerLength(field, selection)
        else { return nil }
        return CFRange(location: location, length: length)
    }

    /// How many characters a text-marker range spans, or nothing where the field will not count them.
    private static func markerLength(_ field: AXUIElement, _ range: AXTextMarkerRange) -> Int? {
        (SurfaceProbe.parameterized(field, "AXLengthForTextMarkerRange", range) as? NSNumber)?.intValue
    }

    /// The screen rectangle of the selection's text-marker range, which web content answers where it answers nothing for a character range.
    private static func markerBounds(_ field: AXUIElement) -> CGRect? {
        var marker: AnyObject?
        guard
            AXUIElementCopyAttributeValue(field, "AXSelectedTextMarkerRange" as CFString, &marker)
                == .success,
            let marker
        else { return nil }
        var answer: AnyObject?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                field, "AXBoundsForTextMarkerRange" as CFString, marker, &answer) == .success,
            let answer, CFGetTypeID(answer) == AXValueGetTypeID()
        else { return nil }
        var rect = CGRect.zero
        // Checked by type ID above; `as?` on a Core Foundation type always succeeds.
        guard AXValueGetValue(unsafeDowncast(answer, to: AXValue.self), .cgRect, &rect), !rect.isNull
        else { return nil }
        return rect
    }

}
