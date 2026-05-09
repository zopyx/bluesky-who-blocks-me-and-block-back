import SwiftUI

struct InfoView: View {
    @State private var selectedTab: InfoTab = .overview

    enum InfoTab: String, CaseIterable {
        case overview = "Overview"
        case features = "Features"
        case legal = "Legal"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(InfoTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
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
            .navigationTitle("Rulyx")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.08, blue: 0.14), for: .navigationBar)
        }
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
            Image(systemName: "checklist.checked")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .padding(14)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            Text("Rulyx")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Moderation rules, made manageable.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))

            Text("Trust & safety tooling for AT Protocol communities.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
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
                            Color(red: 0.05, green: 0.77, blue: 0.73)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var claimsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            claimTile(icon: "dollarsign.circle.fill", text: "Free", color: .green)
            claimTile(icon: "swift", text: "Open Source", color: .orange)
            claimTile(icon: "hand.raised.slash.fill", text: "No Tracking", color: .skyPrimary)
            claimTile(icon: "megaphone.slash.fill", text: "No Ads", color: .skyAccent)
        }
    }

    private var openSourceCard: some View {
        Link(destination: URL(string: "https://github.com/zopyx/bluesky-who-blocks-me-and-block-back")!) {
            HStack(spacing: 14) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("View on GitHub")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("github.com/zopyx/bluesky-who-blocks-me-and-block-back")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var securityNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title3)
                .foregroundStyle(Color.skyPrimary)
                .frame(width: 40, height: 40)
                .background(Color.skyPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("Keychain-secured")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Account secrets never leave your device. All API calls go directly to your Bluesky PDS.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Features Tab

    private var featuresTab: some View {
        VStack(spacing: 12) {
            featureCard(
                icon: "checklist.checked",
                color: .skyPrimary,
                title: "Lists & Members",
                items: [
                    "Browse curation and moderation lists with inline search and filtering.",
                    "Bulk add, remove, copy, and move members across lists with progress tracking.",
                    "Import handles from text, CSV, or files — preview before commit.",
                    "Export member lists and diff results as CSV."
                ]
            )

            featureCard(
                icon: "rectangle.split.3x1",
                color: Color(red: 0.96, green: 0.60, blue: 0.18),
                title: "Compare & Transfer",
                items: [
                    "Compare lists and view overlap, only-in-A, and only-in-B buckets.",
                    "Copy or move selected members between lists in bulk.",
                    "Export diffs for offline review or archiving."
                ]
            )

            featureCard(
                icon: "hand.raised.square.on.square",
                color: .skyAccent,
                title: "Moderation",
                items: [
                    "Block or mute from profile detail with confirmation dialogs.",
                    "Block all followers of an account — runs as a background task.",
                    "View and toggle moderation-list membership directly from any profile."
                ]
            )

            featureCard(
                icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                color: Color(red: 0.70, green: 0.35, blue: 0.90),
                title: "Audit & History",
                items: [
                    "Local list snapshots captured on each load — compare any two.",
                    "Operation log tracks bulk actions with success and failure counts.",
                    "Pending Actions sheet shows running tasks with progress and retry.",
                    "Saved and recent profile searches persist across launches."
                ]
            )
        }
    }

    // MARK: - Legal Tab

    private var legalTab: some View {
        VStack(spacing: 12) {
            legalRow(icon: "person.crop.square", title: "Author", value: "Andreas Jung")

            Link(destination: URL(string: "https://www.py-consultant.com/")!) {
                legalRow(icon: "globe", title: "Website", value: "py-consultant.com", link: true)
            }

            Link(destination: URL(string: "https://www.py-consultant.com/imprint-privacy.html")!) {
                legalRow(icon: "doc.text", title: "Imprint", value: "py-consultant.com/imprint-privacy.html", link: true)
            }

            Link(destination: URL(string: "https://www.py-consultant.com/imprint-privacy.html")!) {
                legalRow(icon: "hand.raised", title: "Privacy Policy", value: "py-consultant.com/imprint-privacy.html", link: true)
            }

            legalRow(icon: "doc.text.magnifyingglass", title: "License", value: "MIT — see LICENSE file")

            legalDivider

            VStack(alignment: .leading, spacing: 8) {
                Text("Data Classification")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                dataRow(label: "Account Data", value: "Stored Locally")
                dataRow(label: "Bluesky API", value: "Live Read/Write")
                dataRow(label: "Audit History", value: "Local Only")
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
                .font(.title2)
                .foregroundStyle(color)
            Text(text)
                .font(.caption2.weight(.semibold))
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
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.80))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func legalRow(icon: String, title: String, value: String, link: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.skyAccent)
                .frame(width: 36, height: 36)
                .background(Color.skyAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            if link {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
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
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.11),
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.04, green: 0.11, blue: 0.19)
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
