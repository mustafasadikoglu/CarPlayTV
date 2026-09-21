import Foundation
import Combine

public final class PlaylistStore: ObservableObject {
    public static let shared = PlaylistStore()

    @Published public var channels: [Channel] = []
    @Published public var playlists: [Playlist] = []
    @Published public var favoriteChannels: [Channel] = []
    @Published public var recentChannels: [Channel] = []
    @Published public var categories: [ChannelCategory] = []
    @Published public var isLoading: Bool = false
    @Published public var parseProgressText: String?
    @Published public var errorMessage: String?

    // In-memory O(1) category dictionary index
    private var categoryMap: [String: [Channel]] = [:]

    private let fileManager = FileManager.default
    private let recentsKey = "carplaytv_recents_cache"
    private let userDefaults = UserDefaults.standard

    private var storageDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("CarPlayTV", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var channelsFileURL: URL {
        storageDirectory.appendingPathComponent("channels_store.json")
    }

    private var playlistsFileURL: URL {
        storageDirectory.appendingPathComponent("playlists_store.json")
    }

    public init() {
        loadFromStorage()
        if channels.isEmpty {
            loadSampleChannels()
        }
    }

    public func loadSampleChannels() {
        let samples = M3UParser.sampleChannels()
        self.channels = samples
        updateDerivedData()
        saveChannelsAsync()
    }

    // MARK: - Streaming Chunked M3U Download
    public func addM3UPlaylist(name: String, url: URL) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.parseProgressText = "Bağlanıyor..."
        }

        do {
            var playlist = Playlist(name: name, type: .m3u, url: url, channelCount: 0)

            await MainActor.run {
                self.playlists.append(playlist)
            }

            let totalCount = try await M3UParser.shared.fetchAndParseStreaming(from: url, chunkSize: 500) { [weak self] chunk in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.channels.append(contentsOf: chunk)
                    self.parseProgressText = "\(self.channels.count) kanal yüklendi..."
                    self.updateDerivedData()
                }
            }

            await MainActor.run {
                if let idx = self.playlists.firstIndex(where: { $0.id == playlist.id }) {
                    self.playlists[idx].channelCount = totalCount
                }
                self.saveChannelsAsync()
                self.savePlaylistsAsync()
                self.parseProgressText = nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "M3U listesi yüklenemedi: \(error.localizedDescription)"
                self.parseProgressText = nil
                self.isLoading = false
            }
        }
    }

    public func addXtreamPlaylist(name: String, server: String, user: String, pass: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.parseProgressText = "Xtream sunucusuna bağlanılıyor..."
        }

        do {
            _ = try await XtreamCodesClient.shared.authenticate(server: server, username: user, password: pass)
            let fetched = try await XtreamCodesClient.shared.fetchLiveStreams(server: server, username: user, password: pass)

            await MainActor.run {
                let playlist = Playlist(
                    name: name,
                    type: .xtream,
                    xtreamServer: server,
                    xtreamUsername: user,
                    xtreamPassword: nil, // Şifre JSON dosyasında düz metin olarak tutulmaz
                    channelCount: fetched.count
                )
                // Şifre iOS Keychain (Secure Enclave) donanım anahtarlığında saklanır
                KeychainHelper.shared.saveString(key: "playlist_pass_\(playlist.id)", value: pass)
                
                self.playlists.append(playlist)
                self.channels.append(contentsOf: fetched)
                self.updateDerivedData()
                self.saveChannelsAsync()
                self.savePlaylistsAsync()
                self.parseProgressText = nil
                self.isLoading = false
                SanitizedLogger.info("Xtream listesi eklendi: \(name), \(fetched.count) kanal.")
            }
        } catch {
            await MainActor.run {
                let safeErr = URLSanitizer.sanitize(error.localizedDescription)
                self.errorMessage = "Xtream sunucusuna bağlanılamadı: \(safeErr)"
                SanitizedLogger.error("Xtream bağlantı hatası", error: error)
                self.parseProgressText = nil
                self.isLoading = false
            }
        }
    }

    public func deletePlaylist(at offsets: IndexSet) {
        for index in offsets {
            guard index < playlists.count else { continue }
            let pl = playlists[index]
            KeychainHelper.shared.delete(key: "playlist_pass_\(pl.id)")
        }
        playlists.remove(atOffsets: offsets)
        savePlaylistsAsync()
    }

    public func toggleFavorite(channelId: String) {
        if let index = channels.firstIndex(where: { $0.id == channelId }) {
            channels[index].isFavorite.toggle()
            updateDerivedData()
            saveChannelsAsync()
        }
    }

    public func recordRecent(channel: Channel) {
        var updated = recentChannels.filter { $0.id != channel.id }
        updated.insert(channel, at: 0)
        if updated.count > 20 {
            updated = Array(updated.prefix(20))
        }
        recentChannels = updated
        saveRecents()
    }

    // Fast O(1) category lookup
    public func channels(for category: String) -> [Channel] {
        if category == "Tümü" {
            return channels
        }
        return categoryMap[category] ?? []
    }

    // High performance background debounced search with result capping
    public func searchChannels(query: String, category: String = "Tümü", limit: Int = 100) async -> [Channel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = channels(for: category)

        guard !trimmed.isEmpty else {
            return Array(source.prefix(limit))
        }

        return await Task.detached(priority: .userInitiated) {
            var results: [Channel] = []
            for ch in source {
                if ch.name.lowercased().contains(trimmed) || ch.groupTitle.lowercased().contains(trimmed) {
                    results.append(ch)
                    if results.count >= limit { break }
                }
            }
            return results
        }.value
    }

    private func updateDerivedData() {
        favoriteChannels = channels.filter { $0.isFavorite }

        // Build category map and counts in single pass
        var groupDict: [String: [Channel]] = [:]
        for ch in channels {
            groupDict[ch.groupTitle, default: []].append(ch)
        }
        self.categoryMap = groupDict

        var cats = groupDict.map { key, chs in
            ChannelCategory(name: key, channelCount: chs.count, iconName: iconForCategory(key))
        }.sorted { $0.name < $1.name }

        cats.insert(ChannelCategory(name: "Tümü", channelCount: channels.count, iconName: "tv.fill"), at: 0)
        self.categories = cats
    }

    private func iconForCategory(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("haber") || lower.contains("news") { return "newspaper.fill" }
        if lower.contains("spor") || lower.contains("sport") { return "sportscourt.fill" }
        if lower.contains("film") || lower.contains("sinema") || lower.contains("movie") { return "film.fill" }
        if lower.contains("çocuk") || lower.contains("kids") { return "figure.child" }
        if lower.contains("belgesel") || lower.contains("doc") { return "globe.europe.africa.fill" }
        if lower.contains("müzik") || lower.contains("music") { return "music.note" }
        return "tv"
    }

    // MARK: - Disk-Backed Fast Persistence
    private func saveChannelsAsync() {
        let chs = self.channels
        let file = self.channelsFileURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(chs) {
                try? data.write(to: file, options: [.atomic])
            }
        }
    }

    private func savePlaylistsAsync() {
        let pls = self.playlists
        let file = self.playlistsFileURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(pls) {
                try? data.write(to: file, options: [.atomic])
            }
        }
    }

    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recentChannels) {
            userDefaults.set(data, forKey: recentsKey)
        }
    }

    private func loadFromStorage() {
        // Load channels from disk file
        if let data = try? Data(contentsOf: channelsFileURL),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            self.channels = decoded
        }
        // Load playlists from disk file
        if let data = try? Data(contentsOf: playlistsFileURL),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = decoded
        }
        // Load recents
        if let data = userDefaults.data(forKey: recentsKey),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            self.recentChannels = decoded
        }
        updateDerivedData()
    }
}
