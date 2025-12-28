import SwiftUI
import UIKit

/// Centralized haptic feedback manager for consistent UX
/// Usage: HapticManager.shared.impact(.medium)
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    // Pre-created generators for performance
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators on init for faster first response
        prepareAll()
    }

    // MARK: - Impact Feedback

    enum ImpactStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid
    }

    func impact(_ style: ImpactStyle) {
        switch style {
        case .light:
            lightImpact.impactOccurred()
        case .medium:
            mediumImpact.impactOccurred()
        case .heavy:
            heavyImpact.impactOccurred()
        case .soft:
            lightImpact.impactOccurred(intensity: 0.5)
        case .rigid:
            heavyImpact.impactOccurred(intensity: 0.8)
        }
    }

    // MARK: - Selection Feedback

    /// For selection changes (tabs, toggles, picker values)
    func selectionChanged() {
        selection.selectionChanged()
    }

    // MARK: - Notification Feedback

    /// For success states (save complete, upload success)
    func success() {
        notification.notificationOccurred(.success)
    }

    /// For warning states (approaching limit, validation issue)
    func warning() {
        notification.notificationOccurred(.warning)
    }

    /// For error states (operation failed)
    func error() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Prepare (Call before animations)

    func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Specific Use Cases

    /// Button tap feedback
    func buttonTap() {
        impact(.light)
    }

    /// Card tap feedback
    func cardTap() {
        impact(.medium)
    }

    /// Long press initiated
    func longPressStart() {
        impact(.medium)
    }

    /// Drag start
    func dragStart() {
        impact(.medium)
    }

    /// Drag end / drop
    func dragEnd() {
        impact(.light)
    }

    /// Toggle switch
    func toggle() {
        impact(.light)
    }

    /// Delete action
    func delete() {
        impact(.medium)
    }

    /// Pull to refresh triggered
    func pullRefresh() {
        impact(.light)
    }

    /// Share action
    func share() {
        impact(.light)
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Add haptic feedback on tap
    func hapticOnTap(_ style: HapticManager.ImpactStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                HapticManager.shared.impact(style)
            }
        )
    }
}
