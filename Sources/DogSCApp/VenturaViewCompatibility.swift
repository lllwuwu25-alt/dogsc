import AppKit
import SwiftUI

extension View {
    /// Keep old/new values and the initial callback on the pre-Sonoma API.
    @ViewBuilder
    func dogscOnChange<Value: Equatable>(
        of value: Value, initial: Bool = false,
        _ action: @escaping (Value, Value) -> Void
    ) -> some View {
        if #available(macOS 14.0, *) {
            onChange(of: value, initial: initial, action)
        } else {
            onChange(of: value) { [value] next in action(value, next) }
                .onAppear { if initial { action(value, value) } }
        }
    }

    @ViewBuilder
    func dogscFocusEffectDisabled() -> some View {
        if #available(macOS 14.0, *) { focusEffectDisabled() } else { self }
    }

    @ViewBuilder
    func dogscSymbolReplacement() -> some View {
        if #available(macOS 14.0, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            contentTransition(.opacity)
        }
    }

    @ViewBuilder
    func dogscPresentationBackground(_ color: Color) -> some View {
        if #available(macOS 13.3, *) { presentationBackground(color) }
        else { background(color) }
    }

    @ViewBuilder
    func dogscSizeBasedScrollBounce() -> some View {
        if #available(macOS 13.3, *) { scrollBounceBehavior(.basedOnSize) }
        else { self }
    }

    func dogscOnKeyPress(
        keys: Set<DogSCKeyEquivalent>, phases: DogSCKeyPress.Phases = [.down, .repeating],
        isFocused: Bool? = nil, action: @escaping (DogSCKeyPress) -> DogSCKeyPress.Result
    ) -> some View {
        modifier(DogSCKeyPressModifier(keys: keys, phases: phases, explicitFocus: isFocused, action: action))
    }

    func dogscOnKeyPress(
        _ key: DogSCKeyEquivalent, action: @escaping () -> DogSCKeyPress.Result
    ) -> some View {
        dogscOnKeyPress(keys: [key], phases: .down) { _ in action() }
    }

    @ViewBuilder
    func dogscAccessibilityToggle() -> some View {
        if #available(macOS 14.0, *) { accessibilityAddTraits(.isToggle) }
        else { self }
    }

    @ViewBuilder
    func dogscButtonRepeatBehavior(_ enabled: Bool) -> some View {
        if #available(macOS 14.0, *) { buttonRepeatBehavior(enabled ? .enabled : .disabled) }
        else { self }
    }
}

/// SwiftUI only added KeyEquivalent's Hashable/Equatable conformance in Sonoma.
/// Character provides the same key identity on Ventura without that conformance.
struct DogSCKeyEquivalent: Hashable, Sendable {
    let character: Character
    init(_ key: KeyEquivalent) { character = key.character }
    var native: KeyEquivalent { KeyEquivalent(character) }
    static let upArrow = Self(.upArrow)
    static let downArrow = Self(.downArrow)
    static let leftArrow = Self(.leftArrow)
    static let rightArrow = Self(.rightArrow)
    static let `return` = Self(.return)
}

struct DogSCKeyPress {
    enum Result { case handled, ignored }
    struct Phases: OptionSet, Sendable {
        let rawValue: Int
        static let down = Self(rawValue: 1)
        static let repeating = Self(rawValue: 2)
    }
    let key: DogSCKeyEquivalent
    let modifiers: EventModifiers
}

struct DogSCKeyboardFocusKey: PreferenceKey {
    static var defaultValue: Bool { false }
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct DogSCKeyPressModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var environmentFocused
    @State private var childFocused = false
    let keys: Set<DogSCKeyEquivalent>
    let phases: DogSCKeyPress.Phases
    let explicitFocus: Bool?
    let action: (DogSCKeyPress) -> DogSCKeyPress.Result

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onKeyPress(
                keys: Set(keys.map(\.native)),
                phases: phases.contains(.repeating) ? [.down, .repeat] : .down
            ) { press in
                action(DogSCKeyPress(key: DogSCKeyEquivalent(press.key), modifiers: press.modifiers)) == .handled
                    ? .handled : .ignored
            }
        } else {
            content
                .background(VenturaKeyMonitor(
                    active: isEnabled && (explicitFocus ?? (environmentFocused || childFocused)),
                    dispatch: VenturaKeyDispatch(keys: keys, phases: phases, action: action)))
                .onPreferenceChange(DogSCKeyboardFocusKey.self) { childFocused = $0 }
        }
    }
}

/// Ventura lacks SwiftUI's animation-completion API. These delays are explicit
/// at the three visual-cleanup call sites, whose revision checks reject stale
/// callbacks. Storage and recording lifecycle never depend on this fallback.
@MainActor
func dogscWithAnimation(
    _ animation: Animation?, fallbackDuration: TimeInterval,
    _ body: () -> Void, completion: @escaping @MainActor () -> Void
) {
    if #available(macOS 14.0, *) {
        withAnimation(animation, completionCriteria: .removed, body, completion: completion)
    } else {
        withAnimation(animation, body)
        Task { @MainActor in
            if animation != nil {
                do { try await Task.sleep(for: .seconds(fallbackDuration)) }
                catch { return }
            }
            completion()
        }
    }
}
