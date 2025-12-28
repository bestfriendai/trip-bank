import SwiftUI

/// Centralized design system tokens for consistent styling
/// Follows Apple HIG recommendations
enum DesignTokens {

    // MARK: - Spacing

    enum Spacing {
        /// 4pt - Minimum spacing
        static let xs: CGFloat = 4
        /// 8pt - Tight spacing
        static let sm: CGFloat = 8
        /// 12pt - Compact spacing
        static let md: CGFloat = 12
        /// 16pt - Default spacing
        static let lg: CGFloat = 16
        /// 20pt - Comfortable spacing
        static let xl: CGFloat = 20
        /// 24pt - Section spacing
        static let xxl: CGFloat = 24
        /// 32pt - Large section spacing
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        /// 4pt - Subtle rounding
        static let xs: CGFloat = 4
        /// 8pt - Default buttons
        static let sm: CGFloat = 8
        /// 12pt - Cards, input fields
        static let md: CGFloat = 12
        /// 16pt - Large cards
        static let lg: CGFloat = 16
        /// 22pt - App icon style
        static let xl: CGFloat = 22
        /// Full rounding
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows

    enum Shadow {
        static let sm = ShadowStyle(
            color: .black.opacity(0.05),
            radius: 4,
            y: 2
        )

        static let md = ShadowStyle(
            color: .black.opacity(0.1),
            radius: 8,
            y: 4
        )

        static let lg = ShadowStyle(
            color: .black.opacity(0.15),
            radius: 16,
            y: 8
        )
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    // MARK: - Animation Durations

    enum AnimationDuration {
        /// 0.15s - Micro interactions
        static let fast: Double = 0.15
        /// 0.25s - Default transitions
        static let normal: Double = 0.25
        /// 0.35s - Emphasis animations
        static let slow: Double = 0.35
        /// 0.5s - Major transitions
        static let slower: Double = 0.5
    }

    // MARK: - Typography (Using system fonts)

    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }

    // MARK: - Colors (Semantic)

    enum Colors {
        // Primary actions
        static let primary = Color.blue

        // Destructive actions
        static let destructive = Color.red

        // Success states
        static let success = Color.green

        // Warning states
        static let warning = Color.orange

        // Neutral backgrounds
        static let backgroundPrimary = Color(.systemBackground)
        static let backgroundSecondary = Color(.secondarySystemBackground)
        static let backgroundTertiary = Color(.tertiarySystemBackground)

        // Text colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)

        // Borders and dividers
        static let border = Color(.separator)
        static let divider = Color(.separator)

        // Overlay for modals
        static let overlay = Color.black.opacity(0.4)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
            .shadow(
                color: DesignTokens.Shadow.md.color,
                radius: DesignTokens.Shadow.md.radius,
                y: DesignTokens.Shadow.md.y
            )
    }

    /// Apply primary button styling
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DesignTokens.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
    }

    /// Apply secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(DesignTokens.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DesignTokens.Colors.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
    }
}
