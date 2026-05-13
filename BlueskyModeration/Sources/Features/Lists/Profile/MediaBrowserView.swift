import SwiftUI
import AVKit

struct MediaBrowserView: View {
    let did: String
    let handle: String

    @StateObject private var viewModel: MediaBrowserViewModel
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var blueskyClient: LiveBlueskyClient
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingFolderPicker = false
    @State private var selectedDownloadFolder: URL?
    @State private var previewItem: MediaItem?

    init(did: String, handle: String) {
        self.did = did
        self.handle = handle
        _viewModel = StateObject(wrappedValue: MediaBrowserViewModel(did: did))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isDownloading {
                    if let progress = viewModel.downloadProgress {
                        VStack(spacing: 4) {
                            ProgressView(value: Double(progress.current), total: Double(progress.total))
                                .padding(.horizontal)
                            Text("\(progress.current) / \(progress.total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                    }
                }

                if !viewModel.items.isEmpty || viewModel.isScanning {
                    if viewModel.availableFilters.count > 1 {
                        HStack(spacing: 8) {
                        Picker("Filter", selection: $viewModel.filter) {
                            ForEach(viewModel.availableFilters, id: \.self) { f in
                                Text(filterLabel(f, count: f == .images ? viewModel.imageCount : viewModel.videoCount))
                                    .tag(f)
                            }
                        }
                            .pickerStyle(.segmented)
                            .frame(width: 240)

                            Spacer()

                            Text(viewModel.summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if viewModel.isScanning {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text(verbatim: loc("profile.media.scanning"))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                    } else {
                        HStack(spacing: 8) {
                            Text(viewModel.summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if viewModel.isScanning {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text(verbatim: loc("profile.media.scanning"))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }

                if !viewModel.items.isEmpty {
                    Text("Tap to select · Double-tap to preview")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }

                toolbar

                Group {
                    if viewModel.isLoading && viewModel.items.isEmpty {
                        Spacer()
                        LoadingPanel(message: loc("profile.posts.loading"))
                        Spacer()
                    } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                        ContentUnavailableView(
                            loc("list.detail.alert_title"),
                            systemImage: "exclamationmark.bubble",
                            description: Text(error)
                        )
                    } else if viewModel.items.isEmpty {
                        ContentUnavailableView(
                            loc("profile.media.empty"),
                            systemImage: "photo.on.rectangle",
                            description: Text(verbatim: loc("profile.media.empty_desc"))
                        )
                    } else {
                        ScrollView {
                            let displayItems = viewModel.filteredItems
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                                ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                                    mediaThumbnail(item, index: index)
                                        .onAppear {
                                            if index >= displayItems.count - 12 {
                                                Task { await loadMore() }
                                            }
                                        }
                                }
                            }
                        }
                        .refreshable {
                            await refresh()
                        }
                    }
                }
            }
            .navigationTitle(loc("profile.media.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("actions.close")) { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingFolderPicker) {
                FolderPicker { url in
                    selectedDownloadFolder = url
                }
            }
            .fullScreenCover(item: $previewItem) { item in
                MediaPreviewView(item: item) { previewItem = nil }
            }
            .sheet(item: $viewModel.downloadSummary) { summary in
                NavigationStack {
                    List {
                        Section {
                            LabeledContent(loc("profile.media.download_total"), value: "\(summary.total)")
                            LabeledContent(loc("profile.media.download_succeeded"), value: "\(summary.succeeded)")
                            if summary.failed > 0 {
                                LabeledContent(loc("profile.media.download_failed"), value: "\(summary.failed)")
                                    .foregroundStyle(.red)
                            }
                            LabeledContent(loc("profile.media.download_folder"), value: summary.directory.lastPathComponent)
                        }
                        if !summary.files.isEmpty {
                            Section {
                                ForEach(summary.files, id: \.self) { file in
                                    Text(file)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                Text(verbatim: loc("profile.media.download_files"))
                            }
                        }
                        if !summary.errors.isEmpty {
                            Section {
                                ForEach(summary.errors, id: \.name) { item in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.caption.weight(.semibold))
                                        Text(item.error)
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                            } header: {
                                Text(verbatim: loc("profile.media.download_errors"))
                            }
                        }
                    }
                    .navigationTitle(loc("profile.media.download_complete"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(loc("actions.done")) {
                                viewModel.clearDownloadSummary()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .onChange(of: viewModel.filter) { _, _ in viewModel.pruneSelection() }
            .onChange(of: selectedDownloadFolder) { _, url in
                guard let url else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                Task {
                    await performDownload(to: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
            .task {
                await loadInitial()
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            if !viewModel.items.isEmpty {
                Button {
                    viewModel.selectAll.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.selectAll ? "checkmark.circle.fill" : "circle")
                        Text(loc("profile.media.select_all"))
                    }
                    .font(.body.weight(.medium))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                Spacer()

                if !viewModel.selectedIDs.isEmpty {
                    Text("\(viewModel.selectedIDs.count)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Button {
                    guard !viewModel.selectedIDs.isEmpty else { return }
                    isShowingFolderPicker = true
                } label: {
                    Label(loc("profile.media.download_selected"), systemImage: "arrow.down.circle")
                        .font(.body.weight(.medium))
                        .padding(.vertical, 6)
                }
                .disabled(viewModel.selectedIDs.isEmpty || viewModel.isDownloading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func mediaThumbnail(_ item: MediaItem, index: Int) -> some View {
        let isSelected = viewModel.selectedIDs.contains(item.id)
        let imageURL = URL(string: item.thumbnailURL ?? item.url)

        ZStack(alignment: .topTrailing) {
            if let url = imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.skyPrimary.opacity(0.08))
                        .overlay { ProgressView().scaleEffect(0.5) }
                }
                .frame(minWidth: 0, minHeight: 0)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
            }

            VStack {
                Spacer()
                HStack {
                    if let age = ageText(for: item) {
                        Text(age)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                    Spacer()
                }
            }

            if item.type == .video {
                VStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.15))
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .shadow(color: .black.opacity(0.4), radius: 2)
                .padding(6)
        }
        .onTapGesture(count: 2) {
            previewItem = item
        }
        .onTapGesture {
            if isSelected {
                viewModel.selectedIDs.remove(item.id)
            } else {
                viewModel.selectedIDs.insert(item.id)
            }
        }
    }

    private func filterLabel(_ f: MediaFilter, count: Int) -> String {
        "\(f.label) (\(count))"
    }

    private func ageText(for item: MediaItem) -> String? {
        guard let raw = item.indexedAt, let date = parseDate(raw) else { return nil }
        let interval = date.distance(to: .now)
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        if interval < 2592000 { return "\(Int(interval / 604800))w" }
        if interval < 31536000 { return "\(Int(interval / 2592000))mo" }
        return "\(Int(interval / 31536000))y"
    }

    private func loadInitial() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        await viewModel.load(account: account, appPassword: appPassword, using: blueskyClient)
    }

    private func loadMore() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        await viewModel.loadMore(account: account, appPassword: appPassword, using: blueskyClient)
    }

    private func refresh() async {
        guard let account = accountStore.activeAccount,
              let appPassword = accountStore.appPassword(for: account) else { return }
        await viewModel.load(account: account, appPassword: appPassword, using: blueskyClient)
    }

    private func performDownload(to directory: URL) async {
        await viewModel.downloadSelected(to: directory, handle: handle)
    }
}

private struct MediaPreviewView: View {
    let item: MediaItem
    let onDismiss: () -> Void

    var body: some View {
        if item.type == .video, let playlist = item.playlistURL.flatMap(URL.init) {
            VideoPlayerView(url: playlist, onDismiss: onDismiss)
        } else {
            ImagePreviewView(url: item.thumbnailURL ?? item.url, onDismiss: onDismiss)
        }
    }
}

private struct VideoPlayerView: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                if let player {
                    AVPlayerControllerRepresentable(player: player)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
            .onAppear {
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                try? AVAudioSession.sharedInstance().setActive(true)
                let p = AVPlayer(url: url)
                p.play()
                player = p
            }
            .onDisappear {
                player?.pause()
                player = nil
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
    }
}

private struct AVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let c = AVPlayerViewController()
        c.player = player
        c.showsPlaybackControls = true
        c.entersFullScreenWhenPlaybackBegins = true
        return c
    }

    func updateUIViewController(_: AVPlayerViewController, context: Context) {}
}

private struct ImagePreviewView: View {
    let url: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                if let url = URL(string: url) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = max(1, lastScale * value)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    if scale > 1 {
                                        scale = 1
                                        offset = .zero
                                        lastScale = 1
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                        lastScale = 2.5
                                    }
                                }
                            }
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
            .onTapGesture {
                if scale <= 1 { onDismiss() }
            }
    }
}

private struct FolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
