import Foundation

public struct XtreamAuthResponse: Codable {
    public let userInfo: XtreamUserInfo?
    public let serverInfo: XtreamServerInfo?

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }
}

public struct XtreamUserInfo: Codable {
    public let username: String?
    public let status: String?
    public let expDate: String?
    public let isTrial: String?
    public let activeCons: String?
    public let maxCons: String?

    enum CodingKeys: String, CodingKey {
        case username
        case status
        case expDate = "exp_date"
        case isTrial = "is_trial"
        case activeCons = "active_cons"
        case maxCons = "max_connections"
    }

    public init(
        username: String? = nil,
        status: String? = nil,
        expDate: String? = nil,
        isTrial: String? = nil,
        activeCons: String? = nil,
        maxCons: String? = nil
    ) {
        self.username = username
        self.status = status
        self.expDate = expDate
        self.isTrial = isTrial
        self.activeCons = activeCons
        self.maxCons = maxCons
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.username = try? container.decode(String.self, forKey: .username)
        self.status = try? container.decode(String.self, forKey: .status)

        if let expStr = try? container.decode(String.self, forKey: .expDate) {
            self.expDate = expStr
        } else if let expInt = try? container.decode(Int.self, forKey: .expDate) {
            self.expDate = String(expInt)
        } else {
            self.expDate = nil
        }

        self.isTrial = try? container.decode(String.self, forKey: .isTrial)
        self.activeCons = try? container.decode(String.self, forKey: .activeCons)

        if let mcStr = try? container.decode(String.self, forKey: .maxCons) {
            self.maxCons = mcStr
        } else if let mcInt = try? container.decode(Int.self, forKey: .maxCons) {
            self.maxCons = String(mcInt)
        } else {
            self.maxCons = nil
        }
    }
}

public struct XtreamServerInfo: Codable {
    public let url: String?
    public let port: String?
    public let httpsPort: String?
    public let serverProtocol: String?
    public let timezone: String?

    enum CodingKeys: String, CodingKey {
        case url
        case port
        case httpsPort = "https_port"
        case serverProtocol = "server_protocol"
        case timezone
    }
}

public struct XtreamCategory: Codable, Identifiable {
    public var id: String { categoryId }
    public let categoryId: String
    public let categoryName: String

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
    }

    public init(categoryId: String, categoryName: String) {
        self.categoryId = categoryId
        self.categoryName = categoryName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idStr = try? container.decode(String.self, forKey: .categoryId) {
            self.categoryId = idStr
        } else if let idInt = try? container.decode(Int.self, forKey: .categoryId) {
            self.categoryId = String(idInt)
        } else {
            self.categoryId = UUID().uuidString
        }
        self.categoryName = (try? container.decode(String.self, forKey: .categoryName)) ?? "Genel"
    }
}

public struct XtreamLiveStream: Codable, Identifiable {
    public var id: Int { streamId }
    public let streamId: Int
    public let num: Int?
    public let name: String
    public let streamType: String?
    public let streamIcon: String?
    public let epgChannelId: String?
    public let categoryId: String?

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case num
        case name
        case streamType = "stream_type"
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case categoryId = "category_id"
    }

    public init(
        streamId: Int,
        num: Int? = nil,
        name: String,
        streamType: String? = nil,
        streamIcon: String? = nil,
        epgChannelId: String? = nil,
        categoryId: String? = nil
    ) {
        self.streamId = streamId
        self.num = num
        self.name = name
        self.streamType = streamType
        self.streamIcon = streamIcon
        self.epgChannelId = epgChannelId
        self.categoryId = categoryId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let sId = try? container.decode(Int.self, forKey: .streamId) {
            self.streamId = sId
        } else if let sStr = try? container.decode(String.self, forKey: .streamId), let sInt = Int(sStr) {
            self.streamId = sInt
        } else {
            self.streamId = 0
        }

        if let n = try? container.decode(Int.self, forKey: .num) {
            self.num = n
        } else if let nStr = try? container.decode(String.self, forKey: .num) {
            self.num = Int(nStr)
        } else {
            self.num = nil
        }

        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Kanal"
        self.streamType = try? container.decode(String.self, forKey: .streamType)
        self.streamIcon = try? container.decode(String.self, forKey: .streamIcon)
        self.epgChannelId = try? container.decode(String.self, forKey: .epgChannelId)

        if let catStr = try? container.decode(String.self, forKey: .categoryId) {
            self.categoryId = catStr
        } else if let catInt = try? container.decode(Int.self, forKey: .categoryId) {
            self.categoryId = String(catInt)
        } else {
            self.categoryId = nil
        }
    }
}

public struct XtreamVodStream: Codable, Identifiable {
    public var id: Int { streamId }
    public let streamId: Int
    public let num: Int?
    public let name: String
    public let streamType: String?
    public let streamIcon: String?
    public let rating: String?
    public let categoryId: String?
    public let containerExtension: String?

    enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case num
        case name
        case streamType = "stream_type"
        case streamIcon = "stream_icon"
        case rating
        case categoryId = "category_id"
        case containerExtension = "container_extension"
    }

    public init(
        streamId: Int,
        num: Int? = nil,
        name: String,
        streamType: String? = nil,
        streamIcon: String? = nil,
        rating: String? = nil,
        categoryId: String? = nil,
        containerExtension: String? = nil
    ) {
        self.streamId = streamId
        self.num = num
        self.name = name
        self.streamType = streamType
        self.streamIcon = streamIcon
        self.rating = rating
        self.categoryId = categoryId
        self.containerExtension = containerExtension
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let sId = try? container.decode(Int.self, forKey: .streamId) {
            self.streamId = sId
        } else if let sStr = try? container.decode(String.self, forKey: .streamId), let sInt = Int(sStr) {
            self.streamId = sInt
        } else {
            self.streamId = 0
        }

        if let n = try? container.decode(Int.self, forKey: .num) {
            self.num = n
        } else if let nStr = try? container.decode(String.self, forKey: .num) {
            self.num = Int(nStr)
        } else {
            self.num = nil
        }

        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Film"
        self.streamType = try? container.decode(String.self, forKey: .streamType)
        self.streamIcon = try? container.decode(String.self, forKey: .streamIcon)

        // Rating can be String, Double, or Int in JSON
        if let rStr = try? container.decode(String.self, forKey: .rating) {
            self.rating = rStr
        } else if let rDbl = try? container.decode(Double.self, forKey: .rating) {
            self.rating = String(format: "%.1f", rDbl)
        } else if let rInt = try? container.decode(Int.self, forKey: .rating) {
            self.rating = String(rInt)
        } else {
            self.rating = nil
        }

        if let catStr = try? container.decode(String.self, forKey: .categoryId) {
            self.categoryId = catStr
        } else if let catInt = try? container.decode(Int.self, forKey: .categoryId) {
            self.categoryId = String(catInt)
        } else {
            self.categoryId = nil
        }

        self.containerExtension = try? container.decode(String.self, forKey: .containerExtension)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(streamId, forKey: .streamId)
        try container.encodeIfPresent(num, forKey: .num)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(streamType, forKey: .streamType)
        try container.encodeIfPresent(streamIcon, forKey: .streamIcon)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(containerExtension, forKey: .containerExtension)
    }
}

public struct XtreamSeriesItem: Codable, Identifiable {
    public var id: Int { seriesId }
    public let seriesId: Int
    public let num: Int?
    public let name: String
    public let cover: String?
    public let plot: String?
    public let cast: String?
    public let director: String?
    public let genre: String?
    public let releaseDate: String?
    public let rating: String?
    public let categoryId: String?

    enum CodingKeys: String, CodingKey {
        case seriesId = "series_id"
        case num
        case name
        case cover
        case plot
        case cast
        case director
        case genre
        case releaseDate = "releaseDate"
        case rating
        case categoryId = "category_id"
    }

    /// Additional keys used only during decoding (snake_case variants)
    private enum AdditionalKeys: String, CodingKey {
        case releaseDateSnake = "release_date"
    }

    public init(
        seriesId: Int,
        num: Int? = nil,
        name: String,
        cover: String? = nil,
        plot: String? = nil,
        cast: String? = nil,
        director: String? = nil,
        genre: String? = nil,
        releaseDate: String? = nil,
        rating: String? = nil,
        categoryId: String? = nil
    ) {
        self.seriesId = seriesId
        self.num = num
        self.name = name
        self.cover = cover
        self.plot = plot
        self.cast = cast
        self.director = director
        self.genre = genre
        self.releaseDate = releaseDate
        self.rating = rating
        self.categoryId = categoryId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let altContainer = try decoder.container(keyedBy: AdditionalKeys.self)

        if let sId = try? container.decode(Int.self, forKey: .seriesId) {
            self.seriesId = sId
        } else if let sStr = try? container.decode(String.self, forKey: .seriesId), let sInt = Int(sStr) {
            self.seriesId = sInt
        } else {
            self.seriesId = 0
        }

        if let n = try? container.decode(Int.self, forKey: .num) {
            self.num = n
        } else if let nStr = try? container.decode(String.self, forKey: .num) {
            self.num = Int(nStr)
        } else {
            self.num = nil
        }

        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Dizi"
        self.cover = try? container.decode(String.self, forKey: .cover)
        self.plot = try? container.decode(String.self, forKey: .plot)
        self.cast = try? container.decode(String.self, forKey: .cast)
        self.director = try? container.decode(String.self, forKey: .director)
        self.genre = try? container.decode(String.self, forKey: .genre)

        if let rd = try? container.decode(String.self, forKey: .releaseDate) {
            self.releaseDate = rd
        } else {
            self.releaseDate = try? altContainer.decode(String.self, forKey: .releaseDateSnake)
        }

        if let rStr = try? container.decode(String.self, forKey: .rating) {
            self.rating = rStr
        } else if let rDbl = try? container.decode(Double.self, forKey: .rating) {
            self.rating = String(format: "%.1f", rDbl)
        } else if let rInt = try? container.decode(Int.self, forKey: .rating) {
            self.rating = String(rInt)
        } else {
            self.rating = nil
        }

        if let catStr = try? container.decode(String.self, forKey: .categoryId) {
            self.categoryId = catStr
        } else if let catInt = try? container.decode(Int.self, forKey: .categoryId) {
            self.categoryId = String(catInt)
        } else {
            self.categoryId = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seriesId, forKey: .seriesId)
        try container.encodeIfPresent(num, forKey: .num)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(plot, forKey: .plot)
        try container.encodeIfPresent(cast, forKey: .cast)
        try container.encodeIfPresent(director, forKey: .director)
        try container.encodeIfPresent(genre, forKey: .genre)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
    }
}

