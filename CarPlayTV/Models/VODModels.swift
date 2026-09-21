import Foundation

public enum VODContentType: String, Codable {
    case movie
    case seriesEpisode
}

public struct VODItem: Identifiable, Codable, Hashable {
    public let id: String
    public var title: String
    public var streamURL: URL
    public var posterURL: URL?
    public var backdropURL: URL?
    public var rating: Double?
    public var year: String?
    public var genre: String?
    public var plot: String?
    public var duration: Double // in seconds
    public var lastPosition: Double // in seconds
    public var categoryName: String
    public var type: VODContentType
    public var seriesId: String?
    public var seasonNumber: Int?
    public var episodeNumber: Int?

    public init(
        id: String = UUID().uuidString,
        title: String,
        streamURL: URL,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        rating: Double? = nil,
        year: String? = nil,
        genre: String? = nil,
        plot: String? = nil,
        duration: Double = 0,
        lastPosition: Double = 0,
        categoryName: String = "Genel",
        type: VODContentType = .movie,
        seriesId: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.streamURL = streamURL
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.rating = rating
        self.year = year
        self.genre = genre
        self.plot = plot
        self.duration = duration
        self.lastPosition = lastPosition
        self.categoryName = categoryName
        self.type = type
        self.seriesId = seriesId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
    }

    public var progressPercent: Double {
        guard duration > 0 else { return 0 }
        return min(max(lastPosition / duration, 0), 1.0)
    }

    public var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours) sa \(minutes) dk"
        }
        return "\(minutes) dk"
    }

    public var isPlayable: Bool {
        let host = streamURL.host?.lowercased() ?? ""
        return !host.contains("example.com") && !streamURL.absoluteString.isEmpty
    }
}

public struct Series: Identifiable, Codable, Hashable {
    public let id: String
    public var title: String
    public var coverURL: URL?
    public var backdropURL: URL?
    public var rating: Double?
    public var year: String?
    public var genre: String?
    public var plot: String?
    public var categoryName: String
    public var seasons: [SeriesSeason]

    public init(
        id: String,
        title: String,
        coverURL: URL? = nil,
        backdropURL: URL? = nil,
        rating: Double? = nil,
        year: String? = nil,
        genre: String? = nil,
        plot: String? = nil,
        categoryName: String = "Diziler",
        seasons: [SeriesSeason] = []
    ) {
        self.id = id
        self.title = title
        self.coverURL = coverURL
        self.backdropURL = backdropURL
        self.rating = rating
        self.year = year
        self.genre = genre
        self.plot = plot
        self.categoryName = categoryName
        self.seasons = seasons
    }

    public var sampleVODItem: VODItem {
        VODItem(
            id: id,
            title: title,
            streamURL: URL(string: "https://example.com")!,
            posterURL: coverURL,
            backdropURL: backdropURL,
            rating: rating,
            year: year,
            genre: genre,
            plot: plot,
            categoryName: categoryName,
            type: .seriesEpisode
        )
    }
}

public struct SeriesSeason: Identifiable, Codable, Hashable {
    public var id: Int { seasonNumber }
    public let seasonNumber: Int
    public var name: String
    public var episodes: [VODItem]

    public init(seasonNumber: Int, name: String, episodes: [VODItem] = []) {
        self.seasonNumber = seasonNumber
        self.name = name
        self.episodes = episodes
    }
}

public struct VODCategory: Identifiable, Codable, Hashable {
    public var id: String { categoryId }
    public let categoryId: String
    public let categoryName: String
    public var isSeries: Bool

    public init(categoryId: String, categoryName: String, isSeries: Bool = false) {
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.isSeries = isSeries
    }
}
