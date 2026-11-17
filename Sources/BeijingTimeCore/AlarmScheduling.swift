import Foundation

/// 迟到处理是有界的，避免睡眠很久后一次响很多闹钟。
///
/// - 0 … catchUp（含）：响铃。默认 3 分钟。
/// - 超过 catchUp 且小于 missedNotice：不循环响铃，记为错过并提示一次。默认 12 小时。
/// - 达到或超过 missedNotice：静默标记已处理，不再提示。
/// 单次闹钟在响铃、错过或过期后关闭。每天闹钟保持开启，下一次按北京日期计算。
/// 同一 occurrence key 写入持久化记录后，刷新或重启都不会再处理。
public struct AlarmPolicy: Equatable {
    public var catchUp: TimeInterval
    public var missedNotice: TimeInterval
    public var handledRetention: TimeInterval

    public init(catchUp: TimeInterval, missedNotice: TimeInterval, handledRetention: TimeInterval) {
        self.catchUp = catchUp
        self.missedNotice = missedNotice
        self.handledRetention = handledRetention
    }

    public static let standard = AlarmPolicy(
        catchUp: 3 * 60,
        missedNotice: 12 * 60 * 60,
        handledRetention: 14 * 24 * 60 * 60
    )
}

public struct Occurrence: Equatable {
    public var alarmID: UUID
    public var civilDate: CivilDate
    public var hour: Int
    public var minute: Int
    public var fireAt: Date
    public var key: String

    public init(alarmID: UUID, civilDate: CivilDate, hour: Int, minute: Int, fireAt: Date, key: String) {
        self.alarmID = alarmID
        self.civilDate = civilDate
        self.hour = hour
        self.minute = minute
        self.fireAt = fireAt
        self.key = key
    }

    public static func makeKey(alarmID: UUID, civil: CivilDate, hour: Int, minute: Int) -> String {
        String(
            format: "%@|%04d-%02d-%02d|%02d:%02d",
            alarmID.uuidString,
            civil.year,
            civil.month,
            civil.day,
            hour,
            minute
        )
    }
}

public struct DueAlarm: Equatable {
    public var alarm: Alarm
    public var occurrence: Occurrence

    public init(alarm: Alarm, occurrence: Occurrence) {
        self.alarm = alarm
        self.occurrence = occurrence
    }
}

public struct ScheduleResult: Equatable {
    public var alarms: [Alarm]
    public var handled: [HandledOccurrence]
    public var rings: [DueAlarm]
    public var missed: [DueAlarm]
    public var expired: [DueAlarm]

    public init(
        alarms: [Alarm],
        handled: [HandledOccurrence],
        rings: [DueAlarm],
        missed: [DueAlarm],
        expired: [DueAlarm]
    ) {
        self.alarms = alarms
        self.handled = handled
        self.rings = rings
        self.missed = missed
        self.expired = expired
    }
}

public struct UpcomingAlarm: Equatable {
    public var alarm: Alarm
    public var occurrence: Occurrence
    public var summary: String

    public init(alarm: Alarm, occurrence: Occurrence, summary: String) {
        self.alarm = alarm
        self.occurrence = occurrence
        self.summary = summary
    }
}

public enum AlarmScheduling {
    public static func occurrence(alarm: Alarm, on civil: CivilDate) -> Occurrence? {
        guard let fireAt = BeijingTime.date(civil, hour: alarm.hour, minute: alarm.minute) else {
            return nil
        }
        return Occurrence(
            alarmID: alarm.id,
            civilDate: civil,
            hour: alarm.hour,
            minute: alarm.minute,
            fireAt: fireAt,
            key: Occurrence.makeKey(alarmID: alarm.id, civil: civil, hour: alarm.hour, minute: alarm.minute)
        )
    }

    /// 严格晚于 now 的下一次。已到点的今天不算“下一次”。
    public static func nextOccurrence(of alarm: Alarm, now: Date) -> Occurrence? {
        guard alarm.enabled else { return nil }
        switch alarm.schedule {
        case .daily:
            let today = BeijingTime.parts(now).civilDate
            if let todayFire = occurrence(alarm: alarm, on: today), todayFire.fireAt > now {
                return todayFire
            }
            guard let tomorrow = BeijingTime.addingDays(1, to: today) else { return nil }
            return occurrence(alarm: alarm, on: tomorrow)
        case .once(let day):
            guard let once = occurrence(alarm: alarm, on: day), once.fireAt > now else { return nil }
            return once
        }
    }

    /// 最近一个已经到达的发生时刻：每天只看今天，若今天还没到则看昨天。更早的不再补。
    public static func latestDue(of alarm: Alarm, now: Date) -> Occurrence? {
        guard alarm.enabled else { return nil }
        switch alarm.schedule {
        case .daily:
            let today = BeijingTime.parts(now).civilDate
            if let todayFire = occurrence(alarm: alarm, on: today), todayFire.fireAt <= now {
                return todayFire
            }
            guard let yesterday = BeijingTime.addingDays(-1, to: today) else { return nil }
            guard let previous = occurrence(alarm: alarm, on: yesterday), previous.fireAt <= now else {
                return nil
            }
            return previous
        case .once(let day):
            guard let once = occurrence(alarm: alarm, on: day), once.fireAt <= now else { return nil }
            return once
        }
    }

    public static func evaluate(
        alarms: [Alarm],
        now: Date,
        handled: [HandledOccurrence],
        policy: AlarmPolicy = .standard
    ) -> ScheduleResult {
        var alarms = alarms
        var handled = handled
        let handledKeys = Set(handled.map(\.key))
        var rings: [DueAlarm] = []
        var missed: [DueAlarm] = []
        var expired: [DueAlarm] = []

        for index in alarms.indices {
            let alarm = alarms[index]
            guard let due = latestDue(of: alarm, now: now) else { continue }
            if handledKeys.contains(due.key) { continue }
            let lateness = now.timeIntervalSince(due.fireAt)
            let dueAlarm = DueAlarm(alarm: alarm, occurrence: due)
            let kind: HandlingKind
            if lateness <= policy.catchUp {
                rings.append(dueAlarm)
                kind = .rang
            } else if lateness < policy.missedNotice {
                missed.append(dueAlarm)
                kind = .missedNotice
            } else {
                expired.append(dueAlarm)
                kind = .expiredSilent
            }
            handled.append(HandledOccurrence(
                key: due.key,
                alarmID: alarm.id,
                kind: kind,
                handledAt: now
            ))
            if case .once = alarm.schedule {
                alarms[index].enabled = false
            }
        }

        return ScheduleResult(
            alarms: alarms,
            handled: handled,
            rings: rings,
            missed: missed,
            expired: expired
        )
    }

    public static func prune(
        _ handled: [HandledOccurrence],
        now: Date,
        policy: AlarmPolicy = .standard
    ) -> [HandledOccurrence] {
        handled.filter { now.timeIntervalSince($0.handledAt) <= policy.handledRetention }
    }

    public static func summary(alarm: Alarm, occurrence: Occurrence) -> String {
        let when = "\(BeijingTime.monthDay(occurrence.civilDate)) \(BeijingTime.hourMinute(hour: occurrence.hour, minute: occurrence.minute))"
        let kind: String
        switch alarm.schedule {
        case .daily:
            kind = "每天"
        case .once:
            kind = "仅一次"
        }
        return "\(when) · \(kind) · \(alarm.title)"
    }

    public static func upcoming(
        alarms: [Alarm],
        now: Date,
        handledKeys: Set<String>,
        policy: AlarmPolicy = .standard,
        limit: Int = 8
    ) -> (items: [UpcomingAlarm], hidden: Int) {
        let rows: [UpcomingAlarm] = alarms.compactMap { alarm in
            let occurrence: Occurrence?
            if let due = latestDue(of: alarm, now: now),
               !handledKeys.contains(due.key),
               now.timeIntervalSince(due.fireAt) <= policy.catchUp {
                occurrence = due
            } else {
                occurrence = nextOccurrence(of: alarm, now: now)
            }
            guard let occurrence else { return nil }
            return UpcomingAlarm(
                alarm: alarm,
                occurrence: occurrence,
                summary: summary(alarm: alarm, occurrence: occurrence)
            )
        }
        .sorted { lhs, rhs in
            if lhs.occurrence.fireAt != rhs.occurrence.fireAt {
                return lhs.occurrence.fireAt < rhs.occurrence.fireAt
            }
            return lhs.alarm.title < rhs.alarm.title
        }
        let capped = max(0, limit)
        if rows.count <= capped {
            return (rows, 0)
        }
        return (Array(rows.prefix(capped)), rows.count - capped)
    }
}
