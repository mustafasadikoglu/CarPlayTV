import Foundation

/// Represents a single electronic program guide entry for a television channel.
public struct EPGProgram: Identifiable, Codable, Hashable {
    public let id: String
    public let channelId: String
    public let title: String
    public let description: String?
    public let startTime: Date
    public let endTime: Date
    public let category: String?

    public init(
        id: String = UUID().uuidString,
        channelId: String,
        title: String,
        description: String? = nil,
        startTime: Date,
        endTime: Date,
        category: String? = nil
    ) {
        self.id = id
        self.channelId = channelId
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
    }

    // MARK: - Computed Properties

    /// Indicates whether the program is currently on air
    public var isCurrentlyAiring: Bool {
        let now = Date()
        return now >= startTime && now < endTime
    }

    /// Indicates whether the program has already finished
    public var hasEnded: Bool {
        return Date() >= endTime
    }

    /// Ratio of elapsed time (0.0 to 1.0)
    public var progressPercentage: Double {
        let now = Date()
        guard now >= startTime else { return 0.0 }
        guard now < endTime else { return 1.0 }

        let totalDuration = endTime.timeIntervalSince(startTime)
        guard totalDuration > 0 else { return 0.0 }

        let elapsed = now.timeIntervalSince(startTime)
        return min(max(elapsed / totalDuration, 0.0), 1.0)
    }

    /// Remaining duration in minutes
    public var remainingMinutes: Int {
        let now = Date()
        guard now < endTime else { return 0 }
        let remainingSeconds = endTime.timeIntervalSince(now)
        return max(Int(ceil(remainingSeconds / 60.0)), 0)
    }

    /// Formatted time string (e.g., "35 dk kaldı")
    public var formattedRemainingTime: String {
        let mins = remainingMinutes
        if mins >= 60 {
            let hours = mins / 60
            let rem = mins % 60
            return rem > 0 ? "\(hours) sa \(rem) dk kaldı" : "\(hours) sa kaldı"
        }
        return "\(mins) dk kaldı"
    }

    /// Formatted time range (e.g. "20:00 - 21:30")
    public var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    public var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startTime)
    }

    public var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: endTime)
    }
}

/// Aggregated EPG information for a channel
public struct ChannelEPG: Identifiable, Codable {
    public var id: String { channelId }
    public let channelId: String
    public var programs: [EPGProgram]

    public init(channelId: String, programs: [EPGProgram] = []) {
        self.channelId = channelId
        self.programs = programs.sorted(by: { $0.startTime < $1.startTime })
    }

    public var currentProgram: EPGProgram? {
        let now = Date()
        return programs.first { now >= $0.startTime && now < $0.endTime }
    }

    public var nextProgram: EPGProgram? {
        let now = Date()
        return programs.first { $0.startTime >= now }
    }
}
