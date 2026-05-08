import SwiftUI

struct InfoView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    metricStrip
                    detailGrid
                    authorCard
                    footerCard
                }
                .padding(16)
            }
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bluesky Moderation")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Native iPhone tooling for list-driven moderation workflows.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.84))
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(red: 0.06, green: 0.36, blue: 0.80))
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                HStack(spacing: 10) {
                    heroBadge("Live API")
                    heroBadge("Keychain")
                    heroBadge("List Tools")
                }
            }
            .padding(22)
        }
        .frame(minHeight: 210)
        .shadow(color: Color.skyPrimary.opacity(0.22), radius: 22, y: 12)
    }

    private var metricStrip: some View {
        HStack(spacing: 12) {
            metricCard(title: "Accounts", value: "Multi", note: "switch fast")
            metricCard(title: "Lists", value: "Live", note: "regular + mod")
            metricCard(title: "Security", value: "Safe", note: "Keychain")
        }
    }

    private var detailGrid: some View {
        VStack(spacing: 12) {
            detailCard(
                title: "Core Workflows",
                systemImage: "checklist.checked",
                tone: .skyPrimary,
                lines: [
                    "Add multiple Bluesky accounts, store app passwords in Keychain, and switch the active account quickly.",
                    "Browse owned curation and moderation lists, inspect members, and edit list metadata.",
                    "Search for actors, add them to lists, remove current members, and run multi-select bulk actions."
                ]
            )

            detailCard(
                title: "Moderation Tools",
                systemImage: "hand.raised.square.on.square",
                tone: .skyAccent,
                lines: [
                    "Open profile inspection to review labels, account stats, owned-list membership, and direct moderation controls.",
                    "Mute, unmute, block, unblock, and add or remove an actor from moderation-oriented lists.",
                    "Compare lists, copy or move selected members, and export member CSV files for outside review."
                ]
            )

            detailCard(
                title: "Saved Work",
                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tone: Color(red: 0.96, green: 0.60, blue: 0.18),
                lines: [
                    "Save profile searches, reopen recent lookups, and keep the last-used query between launches.",
                    "Import handles from pasted text or files, then export current membership as CSV.",
                    "Capture local list snapshots so the app can show what changed between refreshes."
                ]
            )
        }
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
                Text("Every list action, profile lookup, import, export, and moderation request runs against the selected account context.")
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

    private func metricCard(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(note)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
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
