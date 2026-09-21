import Foundation
import Combine

public final class VODStore: ObservableObject {
    public static let shared = VODStore()

    @Published public var movies: [VODItem] = []
    @Published public var series: [Series] = []
    @Published public var categories: [VODCategory] = []
    @Published public var continueWatching: [VODItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let userDefaults = UserDefaults.standard
    private let continueWatchingKey = "carplaytv_continue_watching"
    private let moviesCacheKey = "carplaytv_movies_cache"

    public init() {
        loadContinueWatching()
        loadSampleMovies()
    }

    public func loadSampleMovies() {
        self.movies = VODStore.sampleMovies()
        self.series = VODStore.sampleSeries()
        updateCategories()
    }

    public func setMovies(_ newMovies: [VODItem]) {
        self.movies = newMovies
        updateCategories()
    }

    public func setSeries(_ newSeries: [Series]) {
        self.series = newSeries
        updateCategories()
    }

    public func setLibrary(movies: [VODItem], series: [Series]) {
        self.movies = movies
        self.series = series
        updateCategories()
    }

    public func saveProgress(for item: VODItem, position: Double, duration: Double) {
        guard duration > 0 else { return }

        var updatedItem = item
        updatedItem.lastPosition = position
        updatedItem.duration = duration

        // If completed (e.g. > 95%), remove from continue watching
        if position / duration > 0.95 {
            continueWatching.removeAll(where: { $0.id == item.id })
        } else if position > 10 { // Only save if watched at least 10 seconds
            var list = continueWatching.filter { $0.id != item.id }
            list.insert(updatedItem, at: 0)
            if list.count > 20 {
                list = Array(list.prefix(20))
            }
            continueWatching = list
        }

        // Also update in main movies list if present
        if let idx = movies.firstIndex(where: { $0.id == item.id }) {
            movies[idx].lastPosition = position
            movies[idx].duration = duration
        }

        persistContinueWatching()
    }

    public func loadXtreamVOD(server: String, user: String, pass: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let fetchedMovies = try await XtreamCodesClient.shared.fetchVodStreams(server: server, username: user, password: pass)
            let fetchedSeries = try await XtreamCodesClient.shared.fetchSeries(server: server, username: user, password: pass)

            await MainActor.run {
                self.movies = fetchedMovies
                self.series = fetchedSeries
                self.updateCategories()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Film & Dizi arşivi yüklenemedi: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Loads seasons and episodes for a series, either from active Xtream account or returns cached.
    public func fetchSeriesEpisodes(for series: Series, forceRefresh: Bool = false) async -> Series {
        if !forceRefresh {
            // If already has episodes loaded, return cached only if valid
            if !series.seasons.isEmpty && series.seasons.contains(where: { !$0.episodes.isEmpty }) {
                let hasBroken = series.seasons.contains { season in
                    season.episodes.contains { !$0.isPlayable || $0.streamURL.absoluteString.hasSuffix("/0.mp4") }
                }
                if !hasBroken {
                    return series
                }
            }

            // Check if stored series in library already has episodes
            if let stored = self.series.first(where: { $0.id == series.id }),
               !stored.seasons.isEmpty && stored.seasons.contains(where: { !$0.episodes.isEmpty }) {
                let hasBroken = stored.seasons.contains { season in
                    season.episodes.contains { !$0.isPlayable || $0.streamURL.absoluteString.hasSuffix("/0.mp4") }
                }
                if !hasBroken {
                    return stored
                }
            }
        }

        guard let active = XtreamAccountStore.shared.activeAccount,
              let pass = active.securePassword else {
            return series
        }

        do {
            let updated = try await XtreamCodesClient.shared.fetchSeriesDetails(
                server: active.server,
                username: active.username,
                password: pass,
                series: series
            )

            await MainActor.run {
                if let idx = self.series.firstIndex(where: { $0.id == series.id }) {
                    self.series[idx] = updated
                }
            }

            return updated
        } catch {
            SanitizedLogger.warning("Dizi bölümleri yüklenemedi: \(error.localizedDescription)")
            return series
        }
    }

    private func updateCategories() {
        var cats: [VODCategory] = []
        let uniqueMovieCats = Set(movies.map { $0.categoryName })
        for c in uniqueMovieCats.sorted() {
            cats.append(VODCategory(categoryId: c, categoryName: c, isSeries: false))
        }
        let uniqueSeriesCats = Set(series.map { $0.categoryName })
        for c in uniqueSeriesCats.sorted() {
            cats.append(VODCategory(categoryId: c, categoryName: c, isSeries: true))
        }
        self.categories = cats
    }

    private func persistContinueWatching() {
        if let data = try? JSONEncoder().encode(continueWatching) {
            userDefaults.set(data, forKey: continueWatchingKey)
        }
    }

    private func loadContinueWatching() {
        if let data = userDefaults.data(forKey: continueWatchingKey),
           let decoded = try? JSONDecoder().decode([VODItem].self, from: data) {
            self.continueWatching = decoded
        }
    }

    // MARK: - Sample High Quality Free VOD Content
    public static func sampleMovies() -> [VODItem] {
        return [
            VODItem(
                id: "sample_bbb",
                title: "Big Buck Bunny",
                streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg"),
                rating: 8.2,
                year: "2008",
                genre: "Animasyon, Komedi",
                plot: "Ormanda yaşayan sevimli dev tavşan Big Buck Bunny, huzurunu bozan uçan sincap ve yaramaz sincap çetesine unutulmaz bir ders verir.",
                duration: 596,
                categoryName: "Animasyon",
                type: .movie
            ),
            VODItem(
                id: "sample_tos",
                title: "Tears of Steel",
                streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4")!,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Tears_of_Steel_poster.jpg/440px-Tears_of_Steel_poster.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Tears_of_Steel_poster.jpg/440px-Tears_of_Steel_poster.jpg"),
                rating: 7.5,
                year: "2012",
                genre: "Bilim Kurgu, Aksiyon",
                plot: "Kıyamet sonrası gelecekte bir grup asker ve bilim insanı, dünyayı robot istilasından kurtarmak için geçmişteki bir aşk hikayesini yeniden canlandırmaya çalışır.",
                duration: 734,
                categoryName: "Bilim Kurgu",
                type: .movie
            ),
            VODItem(
                id: "sample_sintel",
                title: "Sintel",
                streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4")!,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/440px-Sintel_poster.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/440px-Sintel_poster.jpg"),
                rating: 8.0,
                year: "2010",
                genre: "Macera, Fantastik",
                plot: "Yaralı bir bebek ejderha bulan genç savaşçı Sintel, ejderhası kaçırılınca onu kurtarmak için tehlikeli dağları aşarak intikam arayışına girer.",
                duration: 888,
                categoryName: "Animasyon",
                type: .movie
            ),
            VODItem(
                id: "sample_elephants",
                title: "Elephants Dream",
                streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4")!,
                posterURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/Elephants_Dream_poster.jpg/440px-Elephants_Dream_poster.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/Elephants_Dream_poster.jpg/440px-Elephants_Dream_poster.jpg"),
                rating: 7.1,
                year: "2006",
                genre: "Bilim Kurgu, Gizem",
                plot: "Proog ve Emo adlı iki karakter, devasa ve karmaşık bir makinenin içinde gerçeklik ve yanılsama arasında felsefi bir yolculuğa çıkar.",
                duration: 654,
                categoryName: "Bilim Kurgu",
                type: .movie
            )
        ]
    }

    public static func sampleSeries() -> [Series] {
        return [
            Series(
                id: "sample_series_1",
                title: "Açık Kaynak Belgeselleri",
                coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/440px-Sintel_poster.jpg"),
                backdropURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/440px-Sintel_poster.jpg"),
                rating: 8.8,
                year: "2024",
                genre: "Belgesel, Teknoloji",
                plot: "Sinema ve animasyon dünyasında devrim yaratan açık kaynaklı film projelerinin perde arkası.",
                categoryName: "Belgesel",
                seasons: [
                    SeriesSeason(
                        seasonNumber: 1,
                        name: "1. Sezon",
                        episodes: [
                            VODItem(
                                id: "ep_1",
                                title: "1. Bölüm: Başlangıç",
                                streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
                                duration: 596,
                                categoryName: "Belgesel",
                                type: .seriesEpisode,
                                seriesId: "sample_series_1",
                                seasonNumber: 1,
                                episodeNumber: 1
                            ),
                            VODItem(
                                id: "ep_2",
                                title: "2. Bölüm: Robotlar Çağı",
                                streamURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4")!,
                                duration: 734,
                                categoryName: "Belgesel",
                                type: .seriesEpisode,
                                seriesId: "sample_series_1",
                                seasonNumber: 1,
                                episodeNumber: 2
                            )
                        ]
                    )
                ]
            )
        ]
    }
}
