import Foundation

/// Delegate that allows self-signed, untrusted, or IP-based SSL certificates for IPTV providers
final class InsecureSSLDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

/// Helper wrapper allowing array decoding to skip corrupted elements rather than failing the whole payload
public struct LossyDecodable<T: Decodable>: Decodable {
    public let value: T?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try? container.decode(T.self)
    }
}

public final class XtreamCodesClient {
    public static let shared = XtreamCodesClient()

    private let sslDelegate = InsecureSSLDelegate()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 90.0
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        ]
        return URLSession(configuration: config, delegate: sslDelegate, delegateQueue: nil)
    }()

    private init() {}

    private func cleanServerURL(_ server: String) -> String {
        var clean = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "http://" + clean
        }
        while clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        // Normalize if user accidentally pasted /player_api.php, /get.php, or /c
        if clean.lowercased().hasSuffix("/player_api.php") {
            clean = String(clean.dropLast("/player_api.php".count))
        } else if clean.lowercased().hasSuffix("/get.php") {
            clean = String(clean.dropLast("/get.php".count))
        } else if clean.lowercased().hasSuffix("/c") {
            clean = String(clean.dropLast("/c".count))
        }
        while clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        return clean
    }

    private func encoded(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    private func encodePathComponent(_ string: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func decodeResilient<T: Decodable>(_ type: T.Type, from data: Data) -> [T] {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([T].self, from: data) {
            return direct
        }
        if let lossy = try? decoder.decode([LossyDecodable<T>].self, from: data) {
            return lossy.compactMap { $0.value }
        }
        return []
    }

    // MARK: - Secure Keychain Storage
    public func saveCredentials(server: String, username: String, password: String) {
        let key = credentialKey(server: server, username: username)
        KeychainHelper.shared.saveString(key: key, value: password)
    }

    public func getStoredPassword(server: String, username: String) -> String? {
        let key = credentialKey(server: server, username: username)
        return KeychainHelper.shared.readString(key: key)
    }

    public func deleteCredentials(server: String, username: String) {
        let key = credentialKey(server: server, username: username)
        KeychainHelper.shared.delete(key: key)
    }

    private func credentialKey(server: String, username: String) -> String {
        let clean = cleanServerURL(server)
        return "xtream_\(clean)_\(username)"
    }

    public func authenticate(server: String, username: String, password: String) async throws -> XtreamAuthResponse {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
        let urlString = "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)"
        guard let url = URL(string: urlString) else {
            SanitizedLogger.error("Geçersiz Xtream sunucu URL'si: \(urlString)")
            throw URLError(.badURL)
        }

        SanitizedLogger.info("Xtream sunucusuna bağlanılıyor: \(urlString)")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            SanitizedLogger.error("Xtream sunucu hatası: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let auth = try decoder.decode(XtreamAuthResponse.self, from: data)
        // Başarılı girişte şifreyi iOS Keychain'e kaydet
        saveCredentials(server: server, username: username, password: password)
        SanitizedLogger.info("Xtream kimlik doğrulaması başarılı. Kimlik bilgileri Keychain'e kaydedildi.")
        return auth
    }

    // MARK: - Live TV & Category Methods
    public func fetchLiveCategories(server: String, username: String, password: String) async throws -> [XtreamCategory] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
        guard let url = URL(string: "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)&action=get_live_categories") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return decodeResilient(XtreamCategory.self, from: data)
    }

    public func fetchLiveStreams(server: String, username: String, password: String, categoryId: String? = nil) async throws -> [Channel] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)

        // 1. Fetch categories to map ID ("1", "42") to actual human-readable category name ("Ulusal", "Spor")
        let categories = (try? await fetchLiveCategories(server: server, username: username, password: password)) ?? []
        var categoryMap: [String: String] = [:]
        for cat in categories {
            categoryMap[cat.categoryId] = cat.categoryName
        }

        var urlString = "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)&action=get_live_streams"
        if let catId = categoryId {
            urlString += "&category_id=\(catId)"
        }

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let streams = decodeResilient(XtreamLiveStream.self, from: data)

        let pathUser = encodePathComponent(username)
        let pathPass = encodePathComponent(password)

        // Convert XtreamLiveStream to uniform Channel model with mapped category names
        return streams.compactMap { stream -> Channel? in
            let streamUrlString = "\(cleanBase)/live/\(pathUser)/\(pathPass)/\(stream.streamId).m3u8"
            guard let streamURL = URL(string: streamUrlString) else { return nil }

            let logoURL = stream.streamIcon.flatMap { URL(string: $0) }
            let groupName = stream.categoryId.flatMap { categoryMap[$0] } ?? "Genel"

            return Channel(
                id: "\(stream.streamId)",
                name: stream.name,
                streamURL: streamURL,
                logoURL: logoURL,
                groupTitle: groupName,
                tvgId: stream.epgChannelId,
                tvgName: stream.name,
                isFavorite: false
            )
        }
    }

    // MARK: - VOD (Movies) Methods
    public func fetchVodCategories(server: String, username: String, password: String) async throws -> [XtreamCategory] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
        guard let url = URL(string: "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)&action=get_vod_categories") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return decodeResilient(XtreamCategory.self, from: data)
    }

    public func fetchVodStreams(server: String, username: String, password: String, categoryId: String? = nil) async throws -> [VODItem] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)

        // Fetch categories to map ID to actual category name
        let categories = (try? await fetchVodCategories(server: server, username: username, password: password)) ?? []
        var vodCatMap: [String: String] = [:]
        for cat in categories {
            vodCatMap[cat.categoryId] = cat.categoryName
        }

        var urlString = "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)&action=get_vod_streams"
        if let catId = categoryId {
            urlString += "&category_id=\(catId)"
        }

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let vodStreams = decodeResilient(XtreamVodStream.self, from: data)
        let pathUser = encodePathComponent(username)
        let pathPass = encodePathComponent(password)

        return vodStreams.compactMap { stream -> VODItem? in
            guard stream.streamId > 0 else { return nil }
            var ext = stream.containerExtension?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". \t\r\n")) ?? "mp4"
            if ext.isEmpty { ext = "mp4" }
            let streamUrlString = "\(cleanBase)/movie/\(pathUser)/\(pathPass)/\(stream.streamId).\(ext)"
            guard let streamURL = URL(string: streamUrlString) else { return nil }

            let poster = stream.streamIcon.flatMap { URL(string: $0) }
            let ratingVal = stream.rating.flatMap { Double($0) }
            let categoryName = stream.categoryId.flatMap { vodCatMap[$0] } ?? "Filmler"

            return VODItem(
                id: "vod_\(stream.streamId)",
                title: stream.name,
                streamURL: streamURL,
                posterURL: poster,
                backdropURL: poster,
                rating: ratingVal,
                categoryName: categoryName,
                type: .movie
            )
        }
    }

    // MARK: - Series Methods
    public func fetchSeriesCategories(server: String, username: String, password: String) async throws -> [XtreamCategory] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
        guard let url = URL(string: "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)&action=get_series_categories") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return decodeResilient(XtreamCategory.self, from: data)
    }

    public func fetchSeries(server: String, username: String, password: String, categoryId: String? = nil) async throws -> [Series] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)

        // Fetch categories to map ID to actual category name
        let categories = (try? await fetchSeriesCategories(server: server, username: username, password: password)) ?? []
        var seriesCatMap: [String: String] = [:]
        for cat in categories {
            seriesCatMap[cat.categoryId] = cat.categoryName
        }

        var urlString = "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)&action=get_series"
        if let catId = categoryId {
            urlString += "&category_id=\(catId)"
        }

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let seriesItems = decodeResilient(XtreamSeriesItem.self, from: data)

        return seriesItems.map { item in
            let cover = item.cover.flatMap { URL(string: $0) }
            let ratingVal = item.rating.flatMap { Double($0) }
            let categoryName = item.categoryId.flatMap { seriesCatMap[$0] } ?? "Diziler"

            return Series(
                id: "series_\(item.seriesId)",
                title: item.name,
                coverURL: cover,
                backdropURL: cover,
                rating: ratingVal,
                year: item.releaseDate,
                genre: item.genre,
                plot: item.plot,
                categoryName: categoryName
            )
        }
    }

    /// Fetches seasons and playable episodes for a given series using action=get_series_info
    public func fetchSeriesDetails(server: String, username: String, password: String, series: Series) async throws -> Series {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
        let rawId = series.id.replacingOccurrences(of: "series_", with: "")

        guard let url = URL(string: "\(cleanBase)/player_api.php?username=\(encUser)&password=\(encPass)&action=get_series_info&series_id=\(rawId)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let details = (try? decoder.decode(XtreamSeriesInfoResponse.self, from: data))

        var seasonsDict: [Int: [VODItem]] = [:]
        var seasonNames: [Int: String] = [:]

        let pathUser = encodePathComponent(username)
        let pathPass = encodePathComponent(password)

        if let details = details {
            for s in details.seasons {
                seasonNames[s.seasonNumber] = s.name
            }

            for (seasonKey, epList) in details.episodes {
                let sNum = Int(seasonKey) ?? 1
                var vodEpisodes: [VODItem] = []

                for ep in epList {
                    guard !ep.id.isEmpty && ep.id != "0" else { continue }
                    var ext = (ep.containerExtension ?? ep.info?.containerExtension)?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". \t\r\n")) ?? "mp4"
                    if ext.isEmpty { ext = "mp4" }
                    let streamUrlString = "\(cleanBase)/series/\(pathUser)/\(pathPass)/\(ep.id).\(ext)"
                    guard let streamURL = URL(string: streamUrlString) else { continue }

                    let posterURL = ep.info?.movieImage.flatMap { URL(string: $0) } ?? series.coverURL
                    let dur = Double(ep.info?.durationSecs ?? 0)

                    let vodEp = VODItem(
                        id: "ep_\(ep.id)",
                        title: ep.title,
                        streamURL: streamURL,
                        posterURL: posterURL,
                        backdropURL: posterURL,
                        rating: ep.info?.rating ?? series.rating,
                        year: series.year,
                        genre: series.genre,
                        plot: ep.info?.plot ?? series.plot,
                        duration: dur,
                        categoryName: series.categoryName,
                        type: .seriesEpisode,
                        seriesId: series.id,
                        seasonNumber: sNum,
                        episodeNumber: ep.episodeNum
                    )
                    vodEpisodes.append(vodEp)
                }

                // Sort episodes by episodeNumber
                vodEpisodes.sort { ($0.episodeNumber ?? 0) < ($1.episodeNumber ?? 0) }
                seasonsDict[sNum] = vodEpisodes
            }
        }

        // Build sorted array of SeriesSeason
        var resultSeasons: [SeriesSeason] = []
        for sNum in seasonsDict.keys.sorted() {
            let episodes = seasonsDict[sNum] ?? []
            let sName = seasonNames[sNum] ?? "\(sNum). Sezon"
            resultSeasons.append(SeriesSeason(seasonNumber: sNum, name: sName, episodes: episodes))
        }

        var updated = series
        if !resultSeasons.isEmpty {
            updated.seasons = resultSeasons
        }
        return updated
    }
}

