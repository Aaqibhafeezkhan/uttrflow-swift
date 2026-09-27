// The menu bar popover: aurora glass with the talk hint, four round buttons and two one-line lists.

import AppKit
import SwiftUI
import UttrflowUX

/// Draws a ``MenuBarPresentation`` and reports every click as an intent; it decides nothing.
struct MenuBarPopoverView: View {
    let presentation: MenuBarPresentation
    /// Carries a chosen command back to the controller.
    let onCommand: (MenuBarIntent) -> Void
    /// The control that has the keyboard, by its place in ``MenuBarKeyboard``.
    @FocusState private var focus: Int?
    /// Whether a key has moved the focus, which is when its ring is drawn.
    @State private var usesKeyboard = false
    /// Whether the panel has the keyboard; losing it hides the ring until a key is pressed again.
    @Environment(\.controlActiveState) private var activeState

    /// The popover's width, from the design.
    static let width: CGFloat = 290
    /// Room round the glass for its shadow, which a borderless window would otherwise clip.
    static let shadowMargin: CGFloat = 28

    var body: some View {
        let keyboard = MenuBarKeyboard(presentation)
        VStack(alignment: .leading, spacing: 0) {
            MenuBarHeaderView(
                header: presentation.header, onCommand: onCommand, focus: $focus, showsFocus: usesKeyboard)
            buttonRow(keyboard).padding(.top, 14)
            if let last = presentation.lastDictation {
                MenuBarRule()
                MenuBarSectionLabel(text: "LAST DICTATION")
                MenuBarRowView(row: last, onCommand: onCommand, isFocused: shows(keyboard.lastDictationPlace))
                    .menuBarKey($focus, keyboard.lastDictationPlace)
            }
            if !presentation.clips.isEmpty {
                MenuBarRule()
                MenuBarSectionLabel(text: "CLIPBOARD")
                ForEach(Array(presentation.clips.enumerated()), id: \.offset) { index, row in
                    MenuBarRowView(
                        row: row, onCommand: onCommand, isFocused: shows(keyboard.clipsStart + index)
                    )
                    .menuBarKey($focus, keyboard.clipsStart + index)
                }
            }
        }
        .onMoveCommand { move($0, in: keyboard) }
        .onKeyPress(keys: [.return, .space]) { _ in press(in: keyboard) }
        .onKeyPress(.tab) { reveal() }
        .onChange(of: activeState) { _, state in if state != .key { usesKeyboard = false } }
        .padding(14)
        .frame(width: Self.width, alignment: .leading)
        .background(alignment: .top) { MenuBarAurora() }
        .menuBarGlass()
        .contextMenu { MenuBarMenuItems(items: presentation.items, onCommand: onCommand) }
        .padding(Self.shadowMargin)
    }

    private func buttonRow(_ keyboard: MenuBarKeyboard) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(presentation.buttons.enumerated()), id: \.offset) { index, button in
                MenuBarRoundButton(
                    button: button, onCommand: onCommand, isFocused: shows(keyboard.buttonsStart + index)
                )
                .menuBarKey($focus, keyboard.buttonsStart + index)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func shows(_ place: Int) -> Bool { usesKeyboard && focus == place }

    /// Shows where the focus is on the first key, and moves it from then on.
    private func move(_ direction: MoveCommandDirection, in keyboard: MenuBarKeyboard) {
        if reveal() == .handled { return }
        focus = keyboard.place(after: focus, forward: direction == .down || direction == .right)
    }

    /// Draws the ring round the control that already has the focus, the first time a key asks for it.
    private func reveal() -> KeyPress.Result {
        guard !usesKeyboard else { return .ignored }
        usesKeyboard = true
        return focus == nil ? .ignored : .handled
    }

    /// Runs the focused control, as a click would.
    private func press(in keyboard: MenuBarKeyboard) -> KeyPress.Result {
        guard usesKeyboard, let command = keyboard.command(at: focus) else { return .ignored }
        onCommand(command.intent)
        return .handled
    }
}

extension View {
    /// Joins the popover's keyboard order at `place`, drawing its own ring instead of the system's.
    fileprivate func menuBarKey(_ focus: FocusState<Int?>.Binding, _ place: Int) -> some View {
        focusable().focusEffectDisabled().focused(focus, equals: place)
    }
}

// MARK: - Header

/// The mark on its tile, beside the talk hint or the status that replaces it.
private struct MenuBarHeaderView: View {
    let header: MenuBarHeader
    let onCommand: (MenuBarIntent) -> Void
    let focus: FocusState<Int?>.Binding
    let showsFocus: Bool

    var body: some View {
        HStack(spacing: 10) {
            MenuBarMarkTile()
            switch header {
            case .hint(let hint):
                MenuBarHintView(hint: hint)
                Spacer(minLength: 0)
            case .status(let status):
                MenuBarStatusView(status: status)
                if let action = status.action {
                    MenuBarPill(
                        command: action, emphasis: status.actionEmphasis, onCommand: onCommand,
                        isFocused: showsFocus && focus.wrappedValue == 0
                    )
                    .menuBarKey(focus, 0)
                }
            }
        }
    }
}

/// The mark, stroked in the text colour on its own small tile.
private struct MenuBarMarkTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(MenuBarColour.tile)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(MenuBarColour.track, lineWidth: 1))
            .frame(width: 30, height: 30)
            .overlay(UttrflowMarkView(height: 15).foregroundStyle(MenuBarColour.text))
            .accessibilityHidden(true)
    }
}

/// "hold [⌃⌥] to talk", the keys on a keycap.
private struct MenuBarHintView: View {
    let hint: MenuBarHint

    var body: some View {
        HStack(spacing: 5) {
            Text(hint.verb)
            Text(hint.keys)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MenuBarColour.text)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(MenuBarColour.keycap, in: RoundedRectangle(cornerRadius: 5))
            Text(hint.trail)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(MenuBarColour.hint)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

/// A dot and a title, a quieter line under it, and a bar when there is progress to show.
private struct MenuBarStatusView: View {
    let status: MenuBarStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Circle().fill(MenuBarColour.dot(status.emphasis)).frame(width: 7, height: 7)
                Text(status.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MenuBarColour.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail = status.detail {
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(MenuBarColour.detail)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let progress = status.progress {
                MenuBarProgressBar(progress: progress).padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A thin teal bar: filled to a fraction, or a short run sliding across when the fraction is unknown.
private struct MenuBarProgressBar: View {
    let progress: MenuBarProgress
    @State private var sliding = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(MenuBarColour.track)
                switch progress {
                case .fraction(let fraction):
                    // Eases between ticks, and only steps under Reduce Motion.
                    Capsule().fill(MenuBarColour.progress).frame(width: width * fraction)
                        .animation(
                            MotionBudget.current().workingBarsMove ? .linear(duration: 1) : nil,
                            value: fraction)
                case .indeterminate:
                    Capsule().fill(MenuBarColour.progress)
                        .frame(width: width * 0.3)
                        .offset(x: sliding ? width : -width * 0.3)
                        .onAppear {
                            // Held still under Reduce Motion, Low Power Mode and thermal pressure.
                            guard MotionBudget.current().demonstrationMoves else { return }
                            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                                sliding = true
                            }
                        }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

/// The header's one action, as a coloured pill.
private struct MenuBarPill: View {
    let command: MenuBarCommand
    let emphasis: MenuBarEmphasis
    let onCommand: (MenuBarIntent) -> Void
    let isFocused: Bool

    var body: some View {
        Button {
            onCommand(command.intent)
        } label: {
            Text(command.title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(MenuBarColour.fillInk)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(MenuBarColour.dot(emphasis), in: Capsule())
                .menuBarFocusRing(Capsule(), isShown: isFocused)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!command.isEnabled)
    }
}

// MARK: - Buttons

/// A round button: the disc, its glyph, and the label under it.
private struct MenuBarRoundButton: View {
    let button: MenuBarButton
    let onCommand: (MenuBarIntent) -> Void
    let isFocused: Bool

    var body: some View {
        Button {
            onCommand(button.command.intent)
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(
                        MenuBarColour.disc(isPrimary: button.isPrimary, isEnabled: button.command.isEnabled)
                    )
                    .overlay(Circle().strokeBorder(MenuBarColour.buttonEdge, lineWidth: 1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: button.symbolName)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(button.isPrimary ? MenuBarColour.fillInk : MenuBarColour.text)
                    )
                    .opacity(button.command.isEnabled || button.isPrimary ? 1 : 0.35)
                    .menuBarFocusRing(Circle(), isShown: isFocused)
                Text(button.command.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(MenuBarColour.buttonLabel)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!button.command.isEnabled)
        .accessibilityLabel(button.command.title)
    }
}

// MARK: - Lists

/// The rule between sections.
private struct MenuBarRule: View {
    var body: some View {
        Rectangle()
            .fill(MenuBarColour.rule)
            .frame(height: 1)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
    }
}

/// A small capitalised label over a list.
private struct MenuBarSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .kerning(0.63)
            .foregroundStyle(MenuBarColour.quiet)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One line, cut with an ellipsis; a click pastes it, Option-click copies it.
private struct MenuBarRowView: View {
    let row: MenuBarRow
    let onCommand: (MenuBarIntent) -> Void
    let isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            let copies = NSEvent.modifierFlags.contains(.option)
            onCommand(copies ? row.copy.intent : row.insert.intent)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 11))
                    .foregroundStyle(MenuBarColour.quiet)
                Text(row.title)
                    .font(.system(size: 13))
                    .foregroundStyle(MenuBarColour.row)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isHovered && row.insert.isEnabled ? MenuBarColour.hover : .clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .menuBarFocusRing(RoundedRectangle(cornerRadius: 8), isShown: isFocused)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!row.insert.isEnabled)
        .onHover { isHovered = $0 }
        .help(row.tooltip ?? "")
        .contextMenu {
            Button(row.insert.title) { onCommand(row.insert.intent) }.disabled(!row.insert.isEnabled)
            Button(row.copy.title) { onCommand(row.copy.intent) }.disabled(!row.copy.isEnabled)
        }
        .accessibilityLabel(row.title)
        .accessibilityHint("Pastes at the cursor. Option-click copies it.")
    }
}

// MARK: - Right-click menu

/// The right-click menu's switches, windows and Quit, drawn from the same items the icon's menu shows.
private struct MenuBarMenuItems: View {
    let items: [MenuBarItem]
    let onCommand: (MenuBarIntent) -> Void

    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            switch item {
            case .status, .sectionHeader:
                EmptyView()
            case .separator:
                Divider()
            case .command(let command):
                if command.isChecked {
                    Button {
                        onCommand(command.intent)
                    } label: {
                        Label(command.title, systemImage: "checkmark")
                    }
                    .disabled(!command.isEnabled)
                } else {
                    Button(command.title) { onCommand(command.intent) }.disabled(!command.isEnabled)
                }
            }
        }
    }
}
