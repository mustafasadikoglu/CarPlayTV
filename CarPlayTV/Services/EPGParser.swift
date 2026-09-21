import Foundation

/// High-performance parser for XMLTV XML format and Xtream Codes EPG JSON.
public final class EPGParser: NSObject, XMLParserDelegate {
    public static let shared = EPGParser()

    private override init() {}

    // MARK: - XMLTV Parsing

    private var programsByChannel: [String: [EPGProgram]] = [:]
    private var currentChannelId: String?
    private var currentStart: Date?
    private var currentEnd: Date?
    private var currentTitle: String = ""
    private var currentDesc: String = ""
    private var currentElement: String = ""

    private let xmltvDateFormatterWithTZ: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmss Z"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private let xmltvDateFormatterNoTZ: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private func parseXMLTVDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = xmltvDateFormatterWithTZ.date(from: trimmed) {
            return date
        }
        return xmltvDateFormatterNoTZ.date(from: trimmed)
    }

    /// Parses an XMLTV XML file data into a dictionary of channel ID -> [EPGProgram]
    public func parseXMLTV(data: Data) -> [String: [EPGProgram]] {
        programsByChannel = [:]
        currentChannelId = nil
        currentStart = nil
        currentEnd = nil
        currentTitle = ""
        currentDesc = ""
        currentElement = ""

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return programsByChannel
    }

    // MARK: - XMLParserDelegate

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        if elementName.lowercased() == "programme" {
            currentChannelId = attributeDict["channel"]
            if let startStr = attributeDict["start"] {
                currentStart = parseXMLTVDate(startStr)
            }
            if let stopStr = attributeDict["stop"] {
                currentEnd = parseXMLTVDate(stopStr)
            }
            currentTitle = ""
            currentDesc = ""
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if currentElement.lowercased() == "title" {
            currentTitle += (currentTitle.isEmpty ? "" : " ") + trimmed
        } else if currentElement.lowercased() == "desc" {
            currentDesc += (currentDesc.isEmpty ? "" : " ") + trimmed
        }
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName.lowercased() == "programme" {
            if let chId = currentChannelId,
               let start = currentStart,
               let end = currentEnd,
               !currentTitle.isEmpty {
                let program = EPGProgram(
                    channelId: chId,
                    title: currentTitle,
                    description: currentDesc.isEmpty ? nil : currentDesc,
                    startTime: start,
                    endTime: end
                )
                programsByChannel[chId, default: []].append(program)
            }
            currentChannelId = nil
            currentStart = nil
            currentEnd = nil
            currentTitle = ""
            currentDesc = ""
        }
        currentElement = ""
    }

    // MARK: - Xtream Codes EPG JSON Parsing

    /// Parses Xtream Codes Short EPG API response (`get_short_epg`)
    public func parseXtreamEPG(data: Data, channelId: String) -> [EPGProgram] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let listings = json["epg_listings"] as? [[String: Any]] else {
            return []
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        var result: [EPGProgram] = []

        for item in listings {
            guard let title = item["title"] as? String else { continue }
            let desc = item["description"] as? String

            var startDate: Date?
            var endDate: Date?

            if let startTs = item["start_timestamp"] as? Double {
                startDate = Date(timeIntervalSince1970: startTs)
            } else if let startStr = item["start"] as? String {
                startDate = dateFormatter.date(from: startStr)
            }

            if let stopTs = item["stop_timestamp"] as? Double {
                endDate = Date(timeIntervalSince1970: stopTs)
            } else if let endStr = item["end"] as? String {
                endDate = dateFormatter.date(from: endStr)
            }

            if let start = startDate, let end = endDate {
                // Decode base64 title if encoded
                let decodedTitle: String
                if let decodedData = Data(base64Encoded: title),
                   let utf8 = String(data: decodedData, encoding: .utf8) {
                    decodedTitle = utf8
                } else {
                    decodedTitle = title
                }

                result.append(EPGProgram(
                    channelId: channelId,
                    title: decodedTitle,
                    description: desc,
                    startTime: start,
                    endTime: end
                ))
            }
        }

        return result.sorted(by: { $0.startTime < $1.startTime })
    }
}
