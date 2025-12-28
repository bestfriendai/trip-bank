import SwiftUI

// MARK: - Reduced Motion Support

/// Check if user prefers reduced motion
struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let animation: Animation?

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation)
    }
}

extension View {
    /// Apply animation only if reduced motion is not enabled
    func animationRespectingMotion(_ animation: Animation? = .default) -> some View {
        modifier(ReducedMotionModifier(animation: animation))
    }

    /// Apply spring animation respecting reduced motion
    func springAnimation(response: Double = 0.4, dampingFraction: Double = 0.8) -> some View {
        modifier(ReducedMotionModifier(
            animation: .spring(response: response, dampingFraction: dampingFraction)
        ))
    }
}

// MARK: - Accessibility Labels for Common Actions

extension View {
    /// Add accessibility for a close button
    func accessibilityCloseButton() -> some View {
        self
            .accessibilityLabel("Close")
            .accessibilityHint("Double-tap to close")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for a delete button
    func accessibilityDeleteButton(itemName: String = "item") -> some View {
        self
            .accessibilityLabel("Delete \(itemName)")
            .accessibilityHint("Double-tap to delete")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for a share button
    func accessibilityShareButton() -> some View {
        self
            .accessibilityLabel("Share")
            .accessibilityHint("Double-tap to share")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for an edit button
    func accessibilityEditButton(itemName: String = "item") -> some View {
        self
            .accessibilityLabel("Edit \(itemName)")
            .accessibilityHint("Double-tap to edit")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for a mute/unmute button
    func accessibilityMuteButton(isMuted: Bool) -> some View {
        self
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")
            .accessibilityHint("Double-tap to \(isMuted ? "unmute" : "mute") audio")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for a play/pause button
    func accessibilityPlayPauseButton(isPlaying: Bool) -> some View {
        self
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityHint("Double-tap to \(isPlaying ? "pause" : "play")")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for a navigation card/row
    func accessibilityNavigationItem(title: String, subtitle: String? = nil) -> some View {
        var label = title
        if let subtitle = subtitle {
            label += ", \(subtitle)"
        }
        return self
            .accessibilityLabel(label)
            .accessibilityHint("Double-tap to view details")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Dynamic Type Support

struct ScaledFontModifier: ViewModifier {
    @ScaledMetric var size: CGFloat

    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight = .regular) {
        self._size = ScaledMetric(wrappedValue: size)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    /// Apply a scaled font that respects Dynamic Type
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight))
    }
}

// MARK: - High Contrast Support

extension View {
    /// Check if high contrast mode is enabled and apply appropriate styling
    @ViewBuilder
    func highContrastBorder(color: Color = .primary, width: CGFloat = 1) -> some View {
        self.modifier(HighContrastBorderModifier(color: color, width: width))
    }
}

struct HighContrastBorderModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) var contrast
    let color: Color
    let width: CGFloat

    func body(content: Content) -> some View {
        if contrast == .increased {
            content.border(color, width: width)
        } else {
            content
        }
    }
}

// MARK: - VoiceOver Announcements

enum AccessibilityAnnouncement {
    /// Announce a message to VoiceOver
    /// - Parameters:
    ///   - message: The message to announce
    ///   - delay: Small delay to allow view updates to complete before announcing (default 0.1s)
    /// - Note: Use this for dynamic content updates that VoiceOver users should be notified about,
    ///         such as "Item saved successfully" or "3 photos selected"
    static func announce(_ message: String, delay: TimeInterval = 0.1) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Announce screen change
    static func screenChanged(to screenName: String) {
        UIAccessibility.post(notification: .screenChanged, argument: screenName)
    }

    /// Announce layout change
    static func layoutChanged(focus: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: focus)
    }
}

// MARK: - Accessible Loading State

struct AccessibleProgressView: View {
    let message: String

    var body: some View {
        ProgressView()
            .accessibilityLabel(message)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Skip to Content (for complex layouts)

struct SkipToContentButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Skip to content")
        }
        // Use accessibilityElement to ensure proper VoiceOver handling
        .accessibilityElement()
        .accessibilityLabel("Skip to main content")
        .accessibilityHint("Double-tap to skip navigation and jump to main content")
        .accessibilityAddTraits(.isButton)
        // Visually hidden but accessible
        .frame(width: 0, height: 0)
        .clipped()
    }
}
