import Foundation

public final class M3UParser {
    public static let shared = M3UParser()

    private init() {}

    public func parse(content: String) -> [Channel] {
        var channels: [Channel] = []
        let lines = content.components(separatedBy: .newlines)

        var currentTvgId: String?
        var currentTvgName: String?
        var currentTvgLogo: String?
        var currentGroupTitle: String = "Genel"
        var currentChannelName: String?
        var currentUserAgent: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTINF:") {
                // Parse attributes
                currentTvgId = extractAttribute(named: "tvg-id", from: line)
                currentTvgName = extractAttribute(named: "tvg-name", from: line)
                currentTvgLogo = extractAttribute(named: "tvg-logo", from: line)
                currentGroupTitle = extractAttribute(named: "group-title", from: line) ?? "Genel"

                // Extract title after last comma
                if let commaIndex = line.lastIndex(of: ",") {
                    let nameSubstring = line[line.index(after: commaIndex)...]
                    currentChannelName = nameSubstring.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if line.hasPrefix("#EXTVLCOPT:http-user-agent=") {
                currentUserAgent = String(line.dropFirst("#EXTVLCOPT:http-user-agent=".count))
            } else if !line.hasPrefix("#") {
                // This is a stream URL line
                if let streamURL = URL(string: line) {
                    let channelName = currentChannelName ?? currentTvgName ?? "Kanal \(channels.count + 1)"
                    let logoURL = currentTvgLogo.flatMap { URL(string: $0) }

                    let channel = Channel(
                        id: UUID().uuidString,
                        name: channelName,
                        streamURL: streamURL,
                        logoURL: logoURL,
                        groupTitle: currentGroupTitle,
                        tvgId: currentTvgId,
                        tvgName: currentTvgName,
                        isFavorite: false,
                        httpUserAgent: currentUserAgent
                    )
                    channels.append(channel)
                }

                // Reset per-channel temp variables
                currentTvgId = nil
                currentTvgName = nil
                currentTvgLogo = nil
                currentGroupTitle = "Genel"
                currentChannelName = nil
                currentUserAgent = nil
            }
        }

        return channels
    }

    public func fetchAndParse(from url: URL) async throws -> [Channel] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw URLError(.cannotDecodeContentData)
        }
        return parse(content: string)
    }

    private func extractAttribute(named name: String, from line: String) -> String? {
        let pattern = "\(name)=\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, options: [], range: nsRange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: line) {
                return String(line[range])
            }
        }
        return nil
    }

    /// Sample legal Live HLS streams for testing on iPhone and CarPlay
    public static func sampleChannels() -> [Channel] {
        return [
            Channel(
                name: "NASA TV Public HD",
                streamURL: URL(string: "https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8")!,
                logoURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/e/e5/NASA_logo.svg"),
                groupTitle: "Bilim & Uzay",
                tvgId: "NASA.us",
                tvgName: "NASA TV HD",
                isFavorite: true
            ),
            Channel(
                name: "TRT World HD",
                streamURL: URL(string: "https://tv-trtworld.medya.trt.com.tr/master.m3u8")!,
                logoURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/e/e4/TRT_World_logo.svg"),
                groupTitle: "Haberler",
                tvgId: "TRTWorld.tr",
                tvgName: "TRT World",
                isFavorite: true
            ),
            Channel(
                name: "DW English HD",
                streamURL: URL(string: "https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/master.m3u8")!,
                logoURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/7/75/Deutsche_Welle_symbol_2012.svg"),
                groupTitle: "Haberler",
                tvgId: "DW.de",
                tvgName: "DW English",
                isFavorite: false
            ),
            Channel(
                name: "Euronews English",
                streamURL: URL(string: "https://rakuten-euronews-1-eu.samsung.wurl.tv/manifest/playlist.m3u8")!,
                logoURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/0/02/Euronews_2016_logo.svg"),
                groupTitle: "Haberler",
                tvgId: "Euronews.eu",
                tvgName: "Euronews",
                isFavorite: false
            ),
            Channel(
                name: "Red Bull TV Live",
                streamURL: URL(string: "https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8")!,
                logoURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/thumb/f/f5/Red_Bull_TV_logo.svg/512px-Red_Bull_TV_logo.svg.png"),
                groupTitle: "Spor & Aksiyon",
                tvgId: "RedBullTV.us",
                tvgName: "Red Bull TV",
                isFavorite: true
            )
        ]
    }
}
