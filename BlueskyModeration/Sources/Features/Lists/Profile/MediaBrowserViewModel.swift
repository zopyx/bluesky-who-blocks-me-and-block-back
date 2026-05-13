import Foundation

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
                url: thumb,
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
        defer { isDownloading = false }

        let targetDir = directory.appendingPathComponent(handle, isDirectory: true)
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let downloads: [(index: Int, url: URL, ext: String)] = selected.enumerated().compactMap { (i, item) in
            let urlString = item.type == .video ? (item.thumbnailURL ?? item.url) : item.url
            guard let url = URL(string: urlString) else { return nil }
            let ext = urlString.hasSuffix(".png") ? "png" : "jpg"
            return (i, url, ext)
        }

        let total = downloads.count
        let session = Self.downloadSession

        try? await withThrowingTaskGroup(of: (Int, Data?).self) { group in
            for (index, url, _) in downloads {
                group.addTask {
                    let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
                    let data = try? await session.data(for: request).0
                    return (index, data)
                }
            }

            var completed = 0
            for try await (index, data) in group {
                guard let data else { continue }
                let (_, _, ext) = downloads[index]
                let fileURL = targetDir.appendingPathComponent("image-\(index + 1).\(ext)")
                try? data.write(to: fileURL)
                completed += 1
                downloadProgress = (completed, total)
            }
        }
    }
}
