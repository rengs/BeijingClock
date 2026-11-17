import Foundation

public enum AlarmSchedule: Equatable, Codable {
    case daily
    case once(CivilDate)

    private enum Kind: String, Codable {
        case daily
        case once
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case year
        case month
        case day
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .daily:
            self = .daily
        case .once:
            let date = CivilDate(
                year: try container.decode(Int.self, forKey: .year),
                month: try container.decode(Int.self, forKey: .month),
                day: try container.decode(Int.self, forKey: .day)
            )
            self = .once(date)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode(Kind.daily, forKey: .type)
        case .once(let date):
            try container.encode(Kind.once, forKey: .type)
            try container.encode(date.year, forKey: .year)
            try container.encode(date.month, forKey: .month)
            try container.encode(date.day, forKey: .day)
        }
    }
}

public struct Alarm: Codable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var hour: Int
    public var minute: Int
    public var enabled: Bool
    public var schedule: AlarmSchedule

    public init(id: UUID, title: String, hour: Int, minute: Int, enabled: Bool, schedule: AlarmSchedule) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.enabled = enabled
        self.schedule = schedule
    }
}

public enum AlarmValidationError: Error, Equatable {
    case invalidTime
    case invalidDate
}

public extension Alarm {
    static func make(
        id: UUID = UUID(),
        title: String,
        hour: Int,
        minute: Int,
        enabled: Bool,
        schedule: AlarmSchedule
    ) -> Result<Alarm, AlarmValidationError> {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return .failure(.invalidTime)
        }
        if case .once(let date) = schedule {
            guard BeijingTime.date(date, hour: hour, minute: minute) != nil else {
                return .failure(.invalidDate)
            }
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty ? "闹钟" : String(trimmed.prefix(80))
        return .success(Alarm(
            id: id,
            title: finalTitle,
            hour: hour,
            minute: minute,
            enabled: enabled,
            schedule: schedule
        ))
    }
}

public enum HandlingKind: String, Codable, Equatable {
    case rang
    case missedNotice
    case expiredSilent
}

public struct HandledOccurrence: Codable, Equatable {
    public var key: String
    public var alarmID: UUID
    public var kind: HandlingKind
    public var handledAt: Date

    public init(key: String, alarmID: UUID, kind: HandlingKind, handledAt: Date) {
        self.key = key
        self.alarmID = alarmID
        self.kind = kind
        self.handledAt = handledAt
    }
}

public struct PersistedState: Codable, Equatable {
    public static let schema = 1

    public var schemaVersion: Int
    public var alarms: [Alarm]
    public var handled: [HandledOccurrence]
    public var clock: ClockDisplayOptions
    public var soundEnabled: Bool

    public init(
        schemaVersion: Int = PersistedState.schema,
        alarms: [Alarm] = [],
        handled: [HandledOccurrence] = [],
        clock: ClockDisplayOptions = .standard,
        soundEnabled: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.alarms = alarms
        self.handled = handled
        self.clock = clock
        self.soundEnabled = soundEnabled
    }

    public static let empty = PersistedState()
}
