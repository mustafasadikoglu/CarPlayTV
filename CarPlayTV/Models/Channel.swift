import Foundation

public struct Channel: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var streamURL: URL
    public var logoURL: URL?
    public var groupTitle: String
    public var tvgId: String?
    public var tvgName: String?
    public var isFavorite: Bool
    public var httpUserAgent: String?
    public var httpReferrer: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        streamURL: URL,
        logoURL: URL? = nil,
        groupTitle: String = "Genel",
        tvgId: String? = nil,
        tvgName: String? = nil,
        isFavorite: Bool = false,
        httpUserAgent: String? = nil,
        httpReferrer: String? = nil
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.groupTitle = groupTitle
        self.tvgId = tvgId
        self.tvgName = tvgName
        self.isFavorite = isFavorite
        self.httpUserAgent = httpUserAgent
        self.httpReferrer = httpReferrer
    }
}

public struct ChannelCategory: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public var channelCount: Int
    public var iconName: String

    public init(name: String, channelCount: Int = 0, iconName: String = "tv") {
        self.name = name
        self.channelCount = channelCount
        self.iconName = iconName
    }
}

public enum PlaylistType: String, Codable {
    case m3u
    case xtream
}

public struct Playlist: Identifiable, Codable {
    public let id: String
    public var name: String
    public var type: PlaylistType
    public var url: URL?
    public var xtreamServer: String?
    public var xtreamUsername: String?
    public var xtreamPassword: String?
    public var lastUpdated: Date
    public var channelCount: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: PlaylistType,
        url: URL? = nil,
        xtreamServer: String? = nil,
        xtreamUsername: String? = nil,
        xtreamPassword: String? = nil,
        lastUpdated: Date = Date(),
        channelCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.xtreamServer = xtreamServer
        self.xtreamUsername = xtreamUsername
        self.xtreamPassword = xtreamPassword
        self.lastUpdated = lastUpdated
        self.channelCount = channelCount
    }

    /// Retrieves the password securely from Keychain, falling back to legacy memory property if present
    public var securePassword: String? {
        KeychainHelper.shared.readString(key: "playlist_pass_\(id)") ?? xtreamPassword
    }
}
