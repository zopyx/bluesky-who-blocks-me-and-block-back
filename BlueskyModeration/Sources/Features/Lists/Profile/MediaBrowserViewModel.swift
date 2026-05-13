import Foundation
import AVFoundation

enum MediaType {
    case image, video
}

enum MediaFilter: String, CaseIterable {
    case images
    case videos

    var label: String {
        switch self {
        case .images: return "Images"
        case .videos: return "Videos"
        }
    }
}

struct MediaItem: Identifiable {
    let id: String
    let url: String
    let thumbnailURL: String?
    let type: MediaType
    let alt: String?
    let postURI: String
    let postText: String?
    let indexedAt: String?
    let playlistURL: String?
}

private let maxMediaItems = 2000

struct DownloadResult {
    let index: Int
    let name: String?
    let error: String?
}

struct DownloadSummary: Identifiable {
    let id = UUID()
    let directory: URL
    let total: Int
    let succeeded: Int
    let files: [String]
    let errors: [(name: String, error: String)]

    var failed: Int { total - succeeded }
}

private let sharedCache: URLCache = {
    let cache = URLCache(memoryCapacity: 256 * 1024 * 1024, diskCapacity: 2 * 1024 * 1024 * 1024, diskPath: "media-thumbnails")
    URLCache.shared = cache
    return cache
}()

@MainActor
final class MediaBrowserViewModel: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isScanning = false
    @Published private(set) var hasMore = true
    @Published var selectedIDs = Set<String>()
    @Published var errorMessage: String?
    @Published var isDownloading = false
    @Published var downloadProgress: (current: Int, total: Int)?
    @Published var filter: MediaFilter = .images
    @Published var downloadSummary: DownloadSummary?

    var filteredItems: [MediaItem] {
        let filtered: [MediaItem]
        switch filter {
        case .images: filtered = items.filter { $0.type == .image }
        case .videos: filtered = items.filter { $0.type == .video }
        }
        return filtered.sorted { a, b in
            guard let da = parseDate(a.indexedAt), let db = parseDate(b.indexedAt) else { return a.id > b.id }
            return da > db
        }
    }

    var availableFilters: [MediaFilter] {
        var result = [MediaFilter]()
        if items.contains(where: { $0.type == .image }) { result.append(.images) }
        if items.contains(where: { $0.type == .video }) { result.append(.videos) }
        return result
    }

    private var cursor: String?
    private let did: String

    init(did: String) {
        self.did = did
    }

    var imageCount: Int { items.filter { $0.type == .image }.count }
    var videoCount: Int { items.filter { $0.type == .video }.count }
    var summaryText: String {
        let total = items.count
        let shown = filteredItems.count
        if shown == total {
            let parts = [
                imageCount > 0 ? "\(imageCount) image\(imageCount != 1 ? "s" : "")" : nil,
                videoCount > 0 ? "\(videoCount) video\(videoCount != 1 ? "s" : "")" : nil,
            ].compactMap { $0 }
            return parts.joined(separator: " · ")
        }
        return "\(shown) of \(total)"
    }

    var selectAll: Bool {
        get { selectedIDs.count == filteredItems.count && !filteredItems.isEmpty }
        set {
            if newValue {
                selectedIDs = Set(filteredItems.map(\.id))
            } else {
                selectedIDs.removeAll()
            }
        }
    }
    func pruneSelection() {
        selectedIDs = Set(filteredItems.filter { selectedIDs.contains($0.id) }.map(\.id))
    }

    func load(account: AppAccount, appPassword: String, using client: LiveBlueskyClient) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        items = []
        cursor = nil
        hasMore = true
        await fetchPage(account: account, appPassword: appPassword, using: client)
        isLoading = false
        if hasMore {
            isScanning = true
            await scanRemaining(account: account, appPassword: appPassword, using: client)
            isScanning = false
        }
    }

    func loadMore(account: AppAccount, appPassword: String, using client: LiveBlueskyClient) async {
        guard !isLoadingMore, cursor != nil else { return }
        isLoadingMore = true
        await fetchPage(account: account, appPassword: appPassword, using: client)
        isLoadingMore = false
    }

    private func scanRemaining(account: AppAccount, appPassword: String, using client: LiveBlueskyClient) async {
        while let next = cursor, items.count < maxMediaItems {
            do {
                let response = try await client.fetchRichFeed(did: did, cursor: next, account: account, appPassword: appPassword)
                var batch: [MediaItem] = []
                for entry in response.feed {
                    guard let embed = entry.post.embed else { continue }
                    extractMedia(from: embed, postURI: entry.post.uri, postText: entry.post.safeRecord.text, indexedAt: entry.post.indexedAt, into: &batch)
                }
                if !batch.isEmpty { items += batch }
                cursor = response.cursor
                hasMore = response.cursor != nil
                if !hasMore || items.count >= maxMediaItems { break }
            } catch {
                break
            }
        }
    }

    private func fetchPage(account: AppAccount, appPassword: String, using client: LiveBlueskyClient) async {
        do {
            let response = try await client.fetchRichFeed(did: did, cursor: cursor, account: account, appPassword: appPassword)
            var batch: [MediaItem] = []
            for entry in response.feed {
                guard let embed = entry.post.embed else { continue }
                extractMedia(from: embed, postURI: entry.post.uri, postText: entry.post.safeRecord.text, indexedAt: entry.post.indexedAt, into: &batch)
            }
            if !batch.isEmpty { items += batch }
            cursor = response.cursor
            hasMore = response.cursor != nil
        } catch {
            errorMessage = AppError.userMessage(from: error)
            AppLogger.moderation.error("Failed to load media: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func extractMedia(from embed: RichEmbed, postURI: String, postText: String?, indexedAt: String?) {
        extractMedia(from: embed, postURI: postURI, postText: postText, indexedAt: indexedAt, into: &items)
    }

    private func extractMedia(from embed: RichEmbed, postURI: String, postText: String?, indexedAt: String?, into batch: inout [MediaItem]) {
        if let images = embed.images {
            for img in images {
                guard let fullsize = img.fullsize else { continue }
                let media = MediaItem(
                    id: "\(postURI)/\(fullsize)",
                    url: fullsize,
                    thumbnailURL: img.thumb ?? fullsize,
                    type: .image,
                    alt: img.alt,
                    postURI: postURI,
                    postText: postText,
                    indexedAt: indexedAt,
                    playlistURL: nil
                )
                batch.append(media)
            }
        }
        if let video = embed.video, let thumb = video.thumbnail {
            let media = MediaItem(
                id: "\(postURI)/video",
                url: video.playlist ?? thumb,
                thumbnailURL: thumb,
                type: .video,
                alt: nil,
                postURI: postURI,
                postText: postText,
                indexedAt: indexedAt,
                playlistURL: video.playlist
            )
            batch.append(media)
        }
    }

    private static let downloadSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 16
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    func downloadSelected(to directory: URL, handle: String) async {
        let selected = items.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        isDownloading = true
        downloadSummary = nil
        defer { isDownloading = false }

        let targetDir = directory.appendingPathComponent(handle, isDirectory: true)
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        var results: [DownloadResult] = []
        let session = Self.downloadSession

        try? await withThrowingTaskGroup(of: DownloadResult.self) { group in
            for (idx, item) in selected.enumerated() {
                if item.type == .video, let playlist = item.playlistURL.flatMap(URL.init) {
                    group.addTask {
                        let savedAs = await self.downloadVideo(playlist: playlist, index: idx, targetDir: targetDir)
                        return DownloadResult(index: idx, name: savedAs, error: savedAs == nil ? "Video download failed" : nil)
                    }
                } else {
                    let urlString = item.url
                    let ext = urlString.hasSuffix(".png") ? "png" : "jpg"
                    guard let url = URL(string: urlString) else {
                        results.append(DownloadResult(index: idx, name: nil, error: "Invalid URL"))
                        continue
                    }
                    let fname = "media-\(idx + 1).\(ext)"
                    group.addTask {
                        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
                        do {
                            let (data, response) = try await session.data(for: request)
                            guard let http = response as? HTTPURLResponse else {
                                return DownloadResult(index: idx, name: nil, error: "Non-HTTP response")
                            }
                            guard http.statusCode == 200 else {
                                return DownloadResult(index: idx, name: nil, error: "HTTP \(http.statusCode)")
                            }
                            let fileURL = targetDir.appendingPathComponent(fname)
                            try data.write(to: fileURL)
                            return DownloadResult(index: idx, name: fname, error: nil)
                        } catch {
                            return DownloadResult(index: idx, name: nil, error: error.localizedDescription)
                        }
                    }
                }
            }

            var completed = 0
            for try await result in group {
                results.append(result)
                completed += 1
                downloadProgress = (completed, selected.count)
            }
        }

        let sorted = results.sorted { $0.index < $1.index }
        downloadSummary = DownloadSummary(
            directory: targetDir,
            total: selected.count,
            succeeded: sorted.filter { $0.name != nil }.count,
            files: sorted.compactMap { $0.name },
            errors: sorted.compactMap { result -> (name: String, error: String)? in
                guard let error = result.error else { return nil }
                return ("media-\(result.index + 1)", error)
            }
        )
    }

    private func remuxToMP4(source: URL, destination: URL) async -> Bool {
        let asset = AVAsset(url: source)
        guard let reader = try? AVAssetReader(asset: asset),
              let writer = try? AVAssetWriter(outputURL: destination, fileType: .mp4) else { return false }

        var pairs: [(AVAssetReaderTrackOutput, AVAssetWriterInput)] = []

        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            for track in videoTracks {
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil)
                input.expectsMediaDataInRealTime = false
                guard writer.canAdd(input) else { continue }
                writer.add(input)
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
                guard reader.canAdd(output) else { continue }
                reader.add(output)
                pairs.append((output, input))
            }
        } catch { return false }

        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            for track in audioTracks {
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                input.expectsMediaDataInRealTime = false
                guard writer.canAdd(input) else { continue }
                writer.add(input)
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
                guard reader.canAdd(output) else { continue }
                reader.add(output)
                pairs.append((output, input))
            }
        } catch { }

        guard !pairs.isEmpty, reader.startReading(), writer.startWriting() else { return false }
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "remux", qos: .utility)
            queue.async {
                while reader.status == .reading {
                    var anySamples = false
                    for (output, input) in pairs where input.isReadyForMoreMediaData {
                        if let sample = output.copyNextSampleBuffer() {
                            anySamples = true
                            input.append(sample)
                        }
                    }
                    if !anySamples { break }
                }
                for (_, input) in pairs { input.markAsFinished() }
                writer.finishWriting { continuation.resume() }
            }
        }

        return writer.status == .completed
    }

    func clearDownloadSummary() {
        downloadSummary = nil
    }

    private func downloadVideo(playlist: URL, index: Int, targetDir: URL) async -> String? {
        do {
            let playlistData = try await Self.downloadSession.data(for: URLRequest(url: playlist)).0
            guard let playlistStr = String(data: playlistData, encoding: .utf8) else {
                return nil
            }

            let baseURL = playlist.deletingLastPathComponent()
            let lines = playlistStr.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

            if playlistStr.contains("#EXT-X-STREAM-INF") {
                for line in lines where !line.hasPrefix("#") && !line.isEmpty {
                    guard let variantURL = URL(string: line, relativeTo: baseURL) else { continue }
                    return await downloadVideo(playlist: variantURL, index: index, targetDir: targetDir)
                }
                return nil
            }

            let segmentURLs: [URL] = lines.compactMap { line in
                guard !line.hasPrefix("#"), !line.isEmpty else { return nil }
                return URL(string: line, relativeTo: baseURL)
            }

            guard !segmentURLs.isEmpty else { return nil }

            var segments = [(Int, Data)]()
            try? await withThrowingTaskGroup(of: (Int, Data?).self) { group in
                for (si, segURL) in segmentURLs.enumerated() {
                    group.addTask {
                        let data = try? await Self.downloadSession.data(for: URLRequest(url: segURL)).0
                        return (si, data)
                    }
                }
                for try await (si, data) in group {
                    guard let data else { continue }
                    segments.append((si, data))
                }
            }

            segments.sort { $0.0 < $1.0 }
            var allData = Data()
            for (_, data) in segments { allData.append(data) }
            guard !allData.isEmpty else { return nil }

            let tsURL = targetDir.appendingPathComponent("media-\(index + 1).ts")
            try allData.write(to: tsURL)

            let mp4URL = targetDir.appendingPathComponent("media-\(index + 1).mp4")
            if await remuxToMP4(source: tsURL, destination: mp4URL) {
                try? FileManager.default.removeItem(at: tsURL)
                return "media-\(index + 1).mp4"
            }

            return "media-\(index + 1).ts"
        } catch {
            return nil
        }
    }
}
