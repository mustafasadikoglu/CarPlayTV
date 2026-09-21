import Foundation

/// Represents a distinct Xtream Codes IPTV provider account/profile.
public struct XtreamAccount: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var server: String
    public var username: String
    public var isActive: Bool
    public var channelCount: Int
    public var vodCount: Int
    public var seriesCount: Int
    public var status: String?
    public var expirationDate: String?
    public var maxConnections: String?
    public var lastSynced: Date?

    public init(
        id: String = UUID().uuidString,
        name: String,
        server: String,
        username: String,
        isActive: Bool = false,
        channelCount: Int = 0,
        vodCount: Int = 0,
        seriesCount: Int = 0,
        status: String? = "Active",
        expirationDate: String? = nil,
        maxConnections: String? = nil,
        lastSynced: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.server = server
        self.username = username
        self.isActive = isActive
        self.channelCount = channelCount
        self.vodCount = vodCount
        self.seriesCount = seriesCount
        self.status = status
        self.expirationDate = expirationDate
        self.maxConnections = maxConnections
        self.lastSynced = lastSynced
    }

    // MARK: - Secure Keychain Access
    /// Hardware-backed retrieval of account password from iOS Keychain
    public var securePassword: String? {
        get {
            KeychainHelper.shared.readString(key: "xtream_acc_pass_\(id)")
        }
        set {
            if let val = newValue {
                KeychainHelper.shared.saveString(key: "xtream_acc_pass_\(id)", value: val)
            } else {
                KeychainHelper.shared.delete(key: "xtream_acc_pass_\(id)")
            }
        }
    }

    public var cleanServerURL: String {
        var clean = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "http://" + clean
        }
        if clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        return clean
    }

    public var hostDisplayName: String {
        if let url = URL(string: cleanServerURL), let host = url.host {
            let port = url.port != nil ? ":\(url.port!)" : ""
            return "\(host)\(port)"
        }
        return server
    }

    public var formattedLastSynced: String {
        guard let date = lastSynced else { return "Henüz senkronize edilmedi" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
