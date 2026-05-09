import SwiftUI

struct InfoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    claimsStrip
                    detailGrid
                    openSourceCard
                    authorCard
                    footerCard
                }
                .padding(16)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .background(background)
            .navigationTitle("Info")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.05, green: 0.08, blue: 0.14), for: .navigationBar)
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
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

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .offset(x: 140, y: -80)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 160, height: 160)
                .blur(radius: 8)
                .offset(x: -60, y: -110)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rulyx")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                        Text("moderation rules, made manageable.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.80))
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(red: 0.06, green: 0.36, blue: 0.80))
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text("Trust & safety tooling for AT Protocol communities.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))

                HStack(spacing: 10) {
                    heroBadge("Live API")
                    heroBadge("Keychain")
                    heroBadge("Bulk Tools")
                }
            }
            .padding(22)
        }
        .frame(minHeight: 210)
        .shadow(color: Color.skyPrimary.opacity(0.22), radius: 22, y: 12)
    }

    private var claimsStrip: some View {
        HStack(spacing: 12) {
            claimCard(icon: "dollarsign.circle", text: "Free")
            claimCard(icon: "swift", text: "Open source")
            claimCard(icon: "hand.raised.slash", text: "No tracking")
            claimCard(icon: "megaphone.slash", text: "No ads")
        }
    }

    private var detailGrid: some View {
        VStack(spacing: 12) {
            detailCard(
                title: "Lists & Members",
                systemImage: "checklist.checked",
                tone: .skyPrimary,
                lines: [
                    "Browse curation and moderation lists with inline search and member filtering.",
                    "Multi-select members for bulk add, remove, copy, and move between lists.",
                    "Import handles from pasted text, CSV, or file. Preview before commit with duplicate and conflict detection.",
                    "Export list membership and diff results as CSV files."
                ]
            )

            detailCard(
                title: "Compare & Transfer",
                systemImage: "rectangle.split.3x1",
                tone: Color(red: 0.96, green: 0.60, blue: 0.18),
                lines: [
                    "Compare two lists and see overlap, only-in-current, and only-in-other buckets.",
                    "Copy or move selected members between lists with progress tracking.",
                    "Export diff results to CSV for outside review."
                ]
            )

            detailCard(
                title: "Profile Moderation",
                systemImage: "hand.raised.square.on.square",
                tone: .skyAccent,
                lines: [
                    "Inspect profiles: labels, stats, owned-list and starter-pack membership.",
                    "Block or mute directly from profile detail with confirmation.",
                    "Block all followers of an account — runs as a background task with progress and retry.",
                    "View and toggle membership in moderation lists from the profile screen."
                ]
            )

            detailCard(
                title: "Audit & History",
                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tone: Color(red: 0.70, green: 0.35, blue: 0.90),
                lines: [
                    "Local list snapshots captured on each load — compare any two to see what changed.",
                    "Operation log tracks bulk actions with success/failure breakdown.",
                    "Pending actions sheet shows running background tasks with progress, cancel, and retry.",
                    "Saved and recent profile searches restored across launches."
                ]
            )
        }
    }

    private var openSourceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                    .foregroundStyle(Color.skyPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.skyPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Open Source")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                Link(destination: URL(string: "https://github.com/zopyx/bluesky-who-blocks-me-and-block-back")!) {
                    HStack {
                        Text("View on GitHub")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 16, y: 10)
    }

    private var footerCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.headline)
                .foregroundStyle(Color.skyPrimary)
                .frame(width: 36, height: 36)
                .background(Color.skyPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Account secrets stay in the iOS Keychain.")
                    .font(.subheadline.weight(.semibold))
                Text("All list actions, profile lookups, imports, exports, and moderation requests run against the selected account. No data is sent to any server other than the Bluesky PDS you authenticate with.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var authorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.square")
                    .font(.headline)
                    .foregroundStyle(Color.skyAccent)
                    .frame(width: 34, height: 34)
                    .background(Color.skyAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Author and Legal")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Created by Andreas Jung.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.84))

                Link("Website: py-consultant.com", destination: URL(string: "https://www.py-consultant.com/")!)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Link("Imprint", destination: URL(string: "https://www.py-consultant.com/imprint-privacy.html")!)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Link("Privacy Policy", destination: URL(string: "https://www.py-consultant.com/imprint-privacy.html")!)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 16, y: 10)
    }

    private func heroBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.18), in: Capsule())
    }

    private func claimCard(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.skyAccent)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func detailCard(
        title: String,
        systemImage: String,
        tone: Color,
        lines: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tone)
                    .frame(width: 34, height: 34)
                    .background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(tone)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.84))
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 16, y: 10)
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
