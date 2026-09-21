import Foundation

/// Sanitizes sensitive credentials (passwords, tokens, API keys) from URLs and log messages.
public struct URLSanitizer {

    private static let queryParamRegex = try? NSRegularExpression(
        pattern: #"(?i)(password|pass|token|api_key|auth_token)=([^&]+)"#,
        options: []
    )

    // Xtream stream path pattern: /live/{username}/{password}/{id}.{ext}
    private static let xtreamStreamRegex = try? NSRegularExpression(
        pattern: #"/(live|movie|series)/([^/]+)/([^/]+)/([^/\s?#]+)"#,
        options: []
    )

    /// Masks passwords and tokens in a URL string.
    ///
    /// Examples:
    /// - `http://s.com/player_api.php?username=alice&password=secret123` -> `...password=***`
    /// - `http://s.com/live/alice/secret123/102.m3u8` -> `http://s.com/live/alice/***/102.m3u8`
    public static func sanitize(_ urlString: String) -> String {
        var sanitized = urlString

        // 1. Mask query parameters
        if let queryRegex = queryParamRegex {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = queryRegex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "$1=***"
            )
        }

        // 2. Mask Xtream path credentials
        if let streamRegex = xtreamStreamRegex {
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = streamRegex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: "/$1/$2/***/$4"
            )
        }

        return sanitized
    }

    /// Masks credentials inside an optional URL.
    public static func sanitize(_ url: URL?) -> String {
        guard let url = url else { return "nil" }
        return sanitize(url.absoluteString)
    }
}

/// Zero-Leakage Logger: Automatically sanitizes messages before logging to system console.
public final class SanitizedLogger {
    public static func debug(_ message: String) {
        #if DEBUG
        let safe = URLSanitizer.sanitize(message)
        print("🔍 [DEBUG] \(safe)")
        #endif
    }

    public static func info(_ message: String) {
        let safe = URLSanitizer.sanitize(message)
        print("ℹ️ [INFO] \(safe)")
    }

    public static func warning(_ message: String) {
        let safe = URLSanitizer.sanitize(message)
        print("⚠️ [WARN] \(safe)")
    }

    public static func error(_ message: String, error: Error? = nil) {
        let safe = URLSanitizer.sanitize(message)
        let errorDetails = error != nil ? URLSanitizer.sanitize(error!.localizedDescription) : ""
        let full = errorDetails.isEmpty ? safe : "\(safe) - Error: \(errorDetails)"
        print("❌ [ERROR] \(full)")
    }
}
