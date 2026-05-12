import SwiftUI

struct InfoView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var selectedTab: InfoTab = .overview

    enum InfoTab: String, CaseIterable {
        case overview = "Overview"
        case features = "Features"
        case legal = "Legal"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(selection: $selectedTab) {
                    ForEach(InfoTab.allCases, id: \.self) { tab in
                        Text(verbatim: localizationManager.localized("info.\(tab.rawValue.lowercased())")).tag(tab)
                    }
                } label: {
                    Text(verbatim: localizationManager.localized("info.section"))
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    Group {
                        switch selectedTab {
                        case .overview: overviewTab
                        case .features: featuresTab
                        case .legal: legalTab
                        }
                    }
                    .padding(16)
                }
            }
            .background(background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.08, blue: 0.14), for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 16) {
            heroCard
            claimsGrid
            openSourceCard
            securityNote
        }
    }

    private var heroCard: some View {
        VStack(spacing: 10) {
            Image("RulyxLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 64)

            Text(verbatim: localizationManager.localized("onboarding.title"))
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))

            Text(verbatim: localizationManager.localized("info.powered_by"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.80))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.36, blue: 0.80),
                            Color(red: 0.08, green: 0.55, blue: 0.98),
                            Color(red: 0.05, green: 0.77, blue: 0.73),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var claimsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            claimTile(icon: "dollarsign.circle.fill", text: localizationManager.localized("info.claim.free"), color: .green)
            claimTile(icon: "swift", text: localizationManager.localized("info.claim.opensource"), color: .orange)
            claimTile(icon: "hand.raised.slash.fill", text: localizationManager.localized("info.claim.notracking"), color: .skyPrimary)
            claimTile(icon: "megaphone.slash.fill", text: localizationManager.localized("info.claim.noads"), color: .skyAccent)
        }
    }

    private var openSourceCard: some View {
        Link(destination: URL(string: "https://github.com/zopyx/bluesky-who-blocks-me-and-block-back")!) {
            HStack(spacing: 14) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: localizationManager.localized("info.view_github"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(verbatim: localizationManager.localized("info.github_url"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel("View on GitHub")
        .accessibilityHint("Opens the project repository on GitHub in your browser")
    }

    private var securityNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title)
                .foregroundStyle(Color.skyPrimary)
                .frame(width: 40, height: 40)
                .background(Color.skyPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: localizationManager.localized("info.keychain.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(verbatim: localizationManager.localized("info.keychain.desc"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.80))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Features Tab

    private var featuresTab: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            featureCard(
                icon: "checklist.checked",
                color: .skyPrimary,
                title: localizationManager.localized("info.feature.lists"),
                items: [
                    "Browse curation and moderation lists with inline search and filtering.",
                    "Bulk add, remove, copy, and move members across lists with progress tracking.",
                    "Import handles from text, CSV, or files — preview before commit.",
                    "Export member lists and diff results as CSV.",
                ]
            )

            featureCard(
                icon: "rectangle.split.3x1",
                color: Color(red: 0.96, green: 0.60, blue: 0.18),
                title: localizationManager.localized("info.feature.compare"),
                items: [
                    "Compare lists and view overlap, only-in-A, and only-in-B buckets.",
                    "Copy or move selected members between lists in bulk.",
                    "Export diffs for offline review or archiving.",
                ]
            )

            featureCard(
                icon: "hand.raised.square.on.square",
                color: .skyAccent,
                title: localizationManager.localized("info.feature.moderation"),
                items: [
                    "Block or mute from profile detail with confirmation dialogs.",
                    "Block all followers of an account — runs as a background task.",
                    "View and toggle moderation-list membership directly from any profile.",
                ]
            )

            featureCard(
                icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                color: Color(red: 0.70, green: 0.35, blue: 0.90),
                title: localizationManager.localized("info.feature.audit"),
                items: [
                    "Local list snapshots captured on each load — compare any two.",
                    "Operation log tracks bulk actions with success and failure counts.",
                    "Pending Actions sheet shows running tasks with progress and retry.",
                    "Saved and recent profile searches persist across launches.",
                ]
            )
        }
    }

    // MARK: - Legal Tab

    private var legalTab: some View {
        VStack(spacing: 12) {
            legalRow(icon: "person.crop.square", title: localizationManager.localized("info.legal.author"), value: "Andreas Jung")

            Link(destination: URL(string: "https://www.py-consultant.com/")!) {
                legalRow(icon: "globe", title: localizationManager.localized("info.legal.website"), value: "py-consultant.com", link: true)
            }
            .accessibilityLabel("Visit website")
            .accessibilityHint("Opens the author's website in your browser")

            Link(destination: URL(string: "https://www.py-consultant.com/imprint-privacy.html")!) {
                legalRow(icon: "doc.text", title: localizationManager.localized("info.legal.imprint"), value: "py-consultant.com/imprint-privacy.html", link: true)
            }
            .accessibilityLabel("View imprint")
            .accessibilityHint("Opens the legal imprint page in your browser")

            Link(destination: URL(string: "https://www.py-consultant.com/imprint-privacy.html")!) {
                legalRow(icon: "hand.raised", title: localizationManager.localized("info.legal.privacy"), value: "py-consultant.com/imprint-privacy.html", link: true)
            }
            .accessibilityLabel("View privacy policy")
            .accessibilityHint("Opens the privacy policy page in your browser")

            legalRow(icon: "doc.text.magnifyingglass", title: localizationManager.localized("info.legal.license"), value: localizationManager.localized("info.legal.license_value"))

            legalDivider

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: localizationManager.localized("info.third_party"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Link(destination: URL(string: "https://clearsky.app")!) {
                    legalRow(icon: "cloud", title: localizationManager.localized("info.legal.clearsky"), value: "clearsky.app", link: true)
                }
                .accessibilityLabel("Visit ClearSky website")
                .accessibilityHint("Opens the ClearSky website in your browser")

                Link(destination: URL(string: "https://github.com/ClearskyApp06/clearskyservices")!) {
                    legalRow(icon: "chevron.left.forwardslash.chevron.right", title: localizationManager.localized("info.legal.clearsky_github"), value: "github.com/ClearskyApp06", link: true)
                }
                .accessibilityLabel("View ClearSky on GitHub")
                .accessibilityHint("Opens the ClearSky GitHub repository in your browser")

                Text(verbatim: localizationManager.localized("info.clearsky.desc"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.leading, 50)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))

            legalDivider

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: localizationManager.localized("info.data_classification"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                dataRow(label: localizationManager.localized("info.data.account"), value: localizationManager.localized("info.data.account_value"))
                dataRow(label: localizationManager.localized("info.data.api"), value: localizationManager.localized("info.data.api_value"))
                dataRow(label: localizationManager.localized("info.data.audit"), value: localizationManager.localized("info.data.audit_value"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Reusable Components

    private func claimTile(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureCard(icon: String, color: Color, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)

                        Text(item)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.80))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func legalRow(icon: String, title: String, value: String, link: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.skyAccent)
                .frame(width: 36, height: 36)
                .background(Color.skyAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.80))
            }

            Spacer()

            if link {
                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var legalDivider: some View {
        Color.white.opacity(0.08)
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func dataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.80))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.11),
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.04, green: 0.11, blue: 0.19),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.skyPrimary.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 44)
                .offset(x: 140, y: -220)

            Circle()
                .fill(Color.skyAccent.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 54)
                .offset(x: -150, y: 240)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    InfoView()
}
