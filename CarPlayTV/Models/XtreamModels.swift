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
}
