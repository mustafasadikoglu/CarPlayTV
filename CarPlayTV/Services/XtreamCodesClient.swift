import Foundation

public final class XtreamCodesClient {
    public static let shared = XtreamCodesClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25.0
        config.timeoutIntervalForResource = 60.0
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        ]
        return URLSession(configuration: config)
    }()

    private init() {}

    private func cleanServerURL(_ server: String) -> String {
        var clean = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "http://" + clean
        }
        if clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        return clean
    }

    private func encoded(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
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

        let decoder = JSONDecoder()
        return try decoder.decode([XtreamCategory].self, from: data)
    }

    public func fetchLiveStreams(server: String, username: String, password: String, categoryId: String? = nil) async throws -> [Channel] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
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

        let decoder = JSONDecoder()
        let streams = try decoder.decode([XtreamLiveStream].self, from: data)

        // Convert XtreamLiveStream to uniform Channel model
        return streams.compactMap { stream -> Channel? in
            let streamUrlString = "\(cleanBase)/live/\(username)/\(password)/\(stream.streamId).m3u8"
            guard let streamURL = URL(string: streamUrlString) else { return nil }

            let logoURL = stream.streamIcon.flatMap { URL(string: $0) }

            return Channel(
                id: "\(stream.streamId)",
                name: stream.name,
                streamURL: streamURL,
                logoURL: logoURL,
                groupTitle: stream.categoryId ?? "Genel",
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

        return try JSONDecoder().decode([XtreamCategory].self, from: data)
    }

    public func fetchVodStreams(server: String, username: String, password: String, categoryId: String? = nil) async throws -> [VODItem] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
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

        let vodStreams = try JSONDecoder().decode([XtreamVodStream].self, from: data)

        return vodStreams.compactMap { stream -> VODItem? in
            let ext = stream.containerExtension ?? "mp4"
            let streamUrlString = "\(cleanBase)/movie/\(username)/\(password)/\(stream.streamId).\(ext)"
            guard let streamURL = URL(string: streamUrlString) else { return nil }

            let poster = stream.streamIcon.flatMap { URL(string: $0) }
            let ratingVal = stream.rating.flatMap { Double($0) }

            return VODItem(
                id: "vod_\(stream.streamId)",
                title: stream.name,
                streamURL: streamURL,
                posterURL: poster,
                backdropURL: poster,
                rating: ratingVal,
                categoryName: stream.categoryId ?? "Filmler",
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

        return try JSONDecoder().decode([XtreamCategory].self, from: data)
    }

    public func fetchSeries(server: String, username: String, password: String, categoryId: String? = nil) async throws -> [Series] {
        let cleanBase = cleanServerURL(server)
        let encUser = encoded(username)
        let encPass = encoded(password)
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

        let seriesItems = try JSONDecoder().decode([XtreamSeriesItem].self, from: data)

        return seriesItems.map { item in
            let cover = item.cover.flatMap { URL(string: $0) }
            let ratingVal = item.rating.flatMap { Double($0) }

            return Series(
                id: "series_\(item.seriesId)",
                title: item.name,
                coverURL: cover,
                backdropURL: cover,
                rating: ratingVal,
                year: item.releaseDate,
                genre: item.genre,
                plot: item.plot,
                categoryName: item.categoryId ?? "Diziler"
            )
        }
    }
}
