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
    @Published public var errorMessage: String?

    private let userDefaults = UserDefaults.standard
    private let channelsKey = "carplaytv_channels_cache"
    private let playlistsKey = "carplaytv_playlists_cache"
    private let favoritesKey = "carplaytv_favorites_ids"
    private let recentsKey = "carplaytv_recents_cache"

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
        saveChannels()
    }

    public func addM3UPlaylist(name: String, url: URL) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let fetched = try await M3UParser.shared.fetchAndParse(from: url)
            await MainActor.run {
                let playlist = Playlist(name: name, type: .m3u, url: url, channelCount: fetched.count)
                self.playlists.append(playlist)
                self.channels.append(contentsOf: fetched)
                self.updateDerivedData()
                self.saveChannels()
                self.savePlaylists()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "M3U listesi yüklenemedi: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    public func addXtreamPlaylist(name: String, server: String, user: String, pass: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
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
                    xtreamPassword: pass,
                    channelCount: fetched.count
                )
                self.playlists.append(playlist)
                self.channels.append(contentsOf: fetched)
                self.updateDerivedData()
                self.saveChannels()
                self.savePlaylists()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Xtream sunucusuna bağlanılamadı: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    public func toggleFavorite(channelId: String) {
        if let index = channels.firstIndex(where: { $0.id == channelId }) {
            channels[index].isFavorite.toggle()
            updateDerivedData()
            saveChannels()
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

    public func channels(for category: String) -> [Channel] {
        if category == "Tümü" {
            return channels
        }
        return channels.filter { $0.groupTitle == category }
    }

    private func updateDerivedData() {
        favoriteChannels = channels.filter { $0.isFavorite }

        // Compute categories
        var groupDict: [String: Int] = [:]
        for ch in channels {
            groupDict[ch.groupTitle, default: 0] += 1
        }

        var cats = groupDict.map { key, count in
            ChannelCategory(name: key, channelCount: count, iconName: iconForCategory(key))
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

    // MARK: - Persistence
    private func saveChannels() {
        if let data = try? JSONEncoder().encode(channels) {
            userDefaults.set(data, forKey: channelsKey)
        }
    }

    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            userDefaults.set(data, forKey: playlistsKey)
        }
    }

    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recentChannels) {
            userDefaults.set(data, forKey: recentsKey)
        }
    }

    private func loadFromStorage() {
        if let data = userDefaults.data(forKey: channelsKey),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            self.channels = decoded
        }
        if let data = userDefaults.data(forKey: playlistsKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = decoded
        }
        if let data = userDefaults.data(forKey: recentsKey),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            self.recentChannels = decoded
        }
        updateDerivedData()
    }
}
