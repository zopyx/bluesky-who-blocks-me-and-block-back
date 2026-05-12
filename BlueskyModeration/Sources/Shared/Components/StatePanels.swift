import SwiftUI

struct LoadingPanel: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStatePanel: View {
    let title: String
    let message: String

    init(title: String, message: String = "") {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

struct ErrorRetryBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subheadline)
                Spacer()
            }

            Button(action: retry) {
                Label(loc("actions.retry"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .glassBorderedButton()
            .accessibilityLabel("Retry: \(message)")
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

struct BatchProgressCard: View {
    let title: String
    let completedCount: Int
    let totalCount: Int
    let currentHandle: String?
    let onCancel: (() -> Void)?

    init(
        title: String,
        completedCount: Int,
        totalCount: Int,
        currentHandle: String?,
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.currentHandle = currentHandle
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(completedCount)/\(totalCount)").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(completedCount), total: Double(totalCount))
            if let currentHandle {
                Text(currentHandle).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            if let onCancel {
                HStack {
                    Spacer()
                    Button(role: .destructive, action: onCancel) {
                        Label(loc("actions.cancel"), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel(loc("actions.cancel"))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(completedCount) of \(totalCount) complete")
    }
}

struct StatusChip: View {
    enum Style {
        case neutral, positive, warning, destructive, info
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
            .background {
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular.tint(tintColor), in: .rect(cornerRadius: .infinity))
                } else {
                    Color.clear.background(backgroundColor, in: Capsule())
                }
            }
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral: return .secondary
        case .positive: return .green
        case .warning: return .orange
        case .destructive: return .red
        case .info: return Color.skyPrimary
        }
    }

    private var tintColor: Color {
        switch style {
        case .neutral: return .secondary
        case .positive: return .green
        case .warning: return .orange
        case .destructive: return .red
        case .info: return Color.skyPrimary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral: return Color(.systemGray6)
        case .positive: return .green.opacity(0.12)
        case .warning: return .orange.opacity(0.12)
        case .destructive: return .red.opacity(0.12)
        case .info: return Color.skyPrimary.opacity(0.12)
        }
    }
}

struct HelpSection: View {
    let title: String
    let bulletPoints: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bulletPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.skyPrimary)
                            .frame(width: 16, height: 16)
                        Text(point)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct OnboardingRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
        .padding(.vertical, 8)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            LoadingPanel(message: "Loading members\u{2026}")
            EmptyStatePanel(title: "No members yet", message: "Search for accounts to add to this list.")
            ErrorRetryBanner(message: "Network connection failed.") {}
            BatchProgressCard(title: "Bulk Add", completedCount: 3, totalCount: 10, currentHandle: "user.bsky.social")
        }
        .padding(.vertical)
    }
}
