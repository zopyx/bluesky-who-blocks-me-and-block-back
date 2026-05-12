import SwiftUI

// MARK: - AppCardStyle

/// A view modifier that applies a standardized card background using system adaptive colors.
/// In dark mode the card appears as a subtle elevated surface; in light mode it blends naturally
/// with the system background.
struct AppCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let style: AppCardStyleLevel

    enum AppCardStyleLevel {
        case standard
        case subtle

        var fill: Color {
            switch self {
            case .standard:  return Color(.secondarySystemFill)
            case .subtle:    return Color(.tertiarySystemFill)
            }
        }
    }

    func body(content: Content) -> some View {
        content.background(style.fill, in: .rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Applies the standard card background shape.
    /// - Parameter cornerRadius: Corner radius for the background shape (default 16).
    /// - Parameter style: Visual prominence of the card (default .standard).
    func appCardStyle(cornerRadius: CGFloat = 16, style: AppCardStyle.AppCardStyleLevel = .standard) -> some View {
        modifier(AppCardStyle(cornerRadius: cornerRadius, style: style))
    }
}

// MARK: - Adaptive Background Colors

extension Color {
    /// A subtle card surface fill that adapts to light and dark appearance.
    /// Use for the background of grouped cards, tiles, or info panels.
    static let cardBackground = Color(.secondarySystemFill)

    /// An even more subdued fill for secondary card elements.
    static let subtleBackground = Color(.tertiarySystemFill)

    /// A separator / divider color that adapts automatically.
    static let appDivider = Color(.separator)

    /// Background for small icon containers within cards.
    static let iconBackground = Color(.quaternarySystemFill)
}
