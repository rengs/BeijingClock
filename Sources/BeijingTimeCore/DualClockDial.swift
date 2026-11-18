import Foundation

/// 24 小时双环。外圈固定为北京时间的一个公历日：00 在正上方，顺时针增加。
/// 同一个角度是同一个绝对时刻，不是两只各自把 12 点放在上方的钟。
/// 内圈时区的夏令时可以在这一天中改变，所以不能把一个偏移套到整天。
public enum DualClockDial {
    public static let defaultInnerIdentifier = "America/Los_Angeles"
    public static let emphasizedBeijingHour = 8
    public static let emphasizedMark = "早8"

    /// 小组件时间线的刷新间隔。WidgetKit 有系统预算，这里不请求每秒刷新。
    public static let timelineSpacing: TimeInterval = 15 * 60
    public static let timelineHorizon: TimeInterval = 6 * 60 * 60
    public static let timelineEntryLimit = 28

    /// 常见内圈时区。含半小时、45 分钟偏移，不只有整小时。
    public static let suggestedInnerIdentifiers: [String] = [
        "America/Los_Angeles",
        "America/Vancouver",
        "America/Denver",
        "America/Chicago",
        "America/New_York",
        "America/St_Johns",
        "America/Sao_Paulo",
        "UTC",
        "Europe/London",
        "Europe/Paris",
        "Africa/Cairo",
        "Europe/Moscow",
        "Asia/Tehran",
        "Asia/Kolkata",
        "Asia/Kathmandu",
        "Asia/Shanghai",
        "Asia/Tokyo",
        "Australia/Adelaide",
        "Australia/Eucla",
        "Australia/Sydney",
        "Pacific/Auckland",
        "Pacific/Chatham",
        "Pacific/Honolulu"
    ]

    public static func resolvedInnerZone(identifier: String?) -> TimeZone {
        let fallback = TimeZone(identifier: defaultInnerIdentifier) ?? TimeZone(secondsFromGMT: -8 * 60 * 60) ?? TimeZone.gmt
        guard let raw = identifier?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return fallback
        }
        guard let zone = TimeZone(identifier: raw) else { return fallback }
        if TimeZone.knownTimeZoneIdentifiers.contains(raw)
            || TimeZone.knownTimeZoneIdentifiers.contains(zone.identifier) {
            return zone
        }
        // 有的 Foundation 承认带斜线的 IANA 名称，但不把它列进 knownTimeZoneIdentifiers。
        if raw.contains("/") { return zone }
        if raw == "UTC" || raw == "GMT" || raw == "Etc/UTC" || raw == "Etc/GMT" {
            return zone
        }
        return fallback
    }

    /// 外圈角度：0 在正上方，顺时针。24 小时转一圈，不是 12 小时。
    public static func angleDegrees(hour: Int, minute: Int, second: Int = 0) -> Double {
        let seconds = Double(hour * 3600 + minute * 60 + second)
        return seconds / 86_400.0 * 360.0
    }

    public static func reading(_ date: Date, in zone: TimeZone) -> ZoneReading {
        let parts = BeijingTime.parts(date, in: zone)
        return ZoneReading(
            timeZoneIdentifier: zone.identifier,
            year: parts.year,
            month: parts.month,
            day: parts.day,
            hour: parts.hour,
            minute: parts.minute,
            second: parts.second,
            offsetSeconds: zone.secondsFromGMT(for: date),
            isDaylightSavingTime: zone.isDaylightSavingTime(for: date)
        )
    }

    public static func pair(at date: Date, innerZone: TimeZone) -> AbsolutePair {
        let beijing = reading(date, in: BeijingTime.timeZone)
        let inner = reading(date, in: innerZone)
        return AbsolutePair(
            instant: date,
            beijing: beijing,
            inner: inner,
            dayRelation: dayRelation(inner: inner.civilDate, beijing: beijing.civilDate)
        )
    }

    /// 外圈是「此刻」所在的那一个北京公历日，不是以现在为中心滚动的 24 小时窗。
    public static func beijingDay(containing date: Date, innerZone: TimeZone) -> BeijingDialDay {
        let beijingNow = reading(date, in: BeijingTime.timeZone)
        let civil = beijingNow.civilDate
        var spokes: [DialSpoke] = []
        spokes.reserveCapacity(24)
        for hour in 0..<24 {
            guard let instant = BeijingTime.date(civil, hour: hour, minute: 0) else { continue }
            let inner = reading(instant, in: innerZone)
            spokes.append(DialSpoke(
                beijingHour: hour,
                angleDegrees: angleDegrees(hour: hour, minute: 0),
                instant: instant,
                inner: inner
            ))
        }
        return BeijingDialDay(civilDate: civil, spokes: spokes)
    }

    public static func timelineDates(startingAt now: Date, innerZone: TimeZone) -> [Date] {
        var dates: [Date] = [now]
        let end = now.addingTimeInterval(timelineHorizon)
        var cursor = now
        while dates.count < timelineEntryLimit {
            let next = cursor.addingTimeInterval(timelineSpacing)
            if next > end { break }
            dates.append(next)
            cursor = next
        }
        if let transition = innerZone.nextDaylightSavingTimeTransition(after: now),
           transition > now,
           transition <= end,
           !dates.contains(transition),
           dates.count < timelineEntryLimit {
            dates.append(transition)
        }
        return dates.sorted()
    }

    public static func dayRelation(inner: CivilDate, beijing: CivilDate) -> DayRelation {
        switch dayDelta(from: beijing, to: inner) {
        case -1: return .yesterday
        case 0: return .today
        case 1: return .tomorrow
        default:
            return .other(dayDelta(from: beijing, to: inner))
        }
    }

    public static func clockLabel(_ reading: ZoneReading) -> String {
        if reading.minute == 0 && reading.second == 0 {
            return String(format: "%02d", reading.hour)
        }
        return String(format: "%02d:%02d", reading.hour, reading.minute)
    }

    /// 只描述这一个瞬间的时差，不把它说成全天不变。
    public static func instantOffsetPhrase(beijing: ZoneReading, inner: ZoneReading) -> String {
        let delta = inner.offsetSeconds - beijing.offsetSeconds
        if delta == 0 { return "此刻与北京同一时刻读数的时差是 0" }
        let direction = delta < 0 ? "晚" : "早"
        let absSeconds = abs(delta)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        if minutes == 0 {
            return "此刻内圈比北京\(direction) \(hours) 小时"
        }
        return "此刻内圈比北京\(direction) \(hours) 小时 \(minutes) 分"
    }

    public static func dayDelta(from start: CivilDate, to end: CivilDate) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.gmt
        let startDate = calendar.date(from: DateComponents(year: start.year, month: start.month, day: start.day))
        let endDate = calendar.date(from: DateComponents(year: end.year, month: end.month, day: end.day))
        guard let startDate, let endDate else { return 0 }
        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

public struct ZoneReading: Equatable {
    public var timeZoneIdentifier: String
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var offsetSeconds: Int
    public var isDaylightSavingTime: Bool

    public var civilDate: CivilDate {
        CivilDate(year: year, month: month, day: day)
    }

    public init(
        timeZoneIdentifier: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        offsetSeconds: Int,
        isDaylightSavingTime: Bool
    ) {
        self.timeZoneIdentifier = timeZoneIdentifier
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.offsetSeconds = offsetSeconds
        self.isDaylightSavingTime = isDaylightSavingTime
    }
}

public struct AbsolutePair: Equatable {
    public var instant: Date
    public var beijing: ZoneReading
    public var inner: ZoneReading
    public var dayRelation: DayRelation

    public init(instant: Date, beijing: ZoneReading, inner: ZoneReading, dayRelation: DayRelation) {
        self.instant = instant
        self.beijing = beijing
        self.inner = inner
        self.dayRelation = dayRelation
    }
}

public struct DialSpoke: Equatable {
    public var beijingHour: Int
    public var angleDegrees: Double
    public var instant: Date
    public var inner: ZoneReading

    public init(beijingHour: Int, angleDegrees: Double, instant: Date, inner: ZoneReading) {
        self.beijingHour = beijingHour
        self.angleDegrees = angleDegrees
        self.instant = instant
        self.inner = inner
    }
}

public struct BeijingDialDay: Equatable {
    public var civilDate: CivilDate
    public var spokes: [DialSpoke]

    public init(civilDate: CivilDate, spokes: [DialSpoke]) {
        self.civilDate = civilDate
        self.spokes = spokes
    }

    public var distinctOffsets: [Int] {
        Array(Set(spokes.map(\.inner.offsetSeconds))).sorted()
    }

    public func spoke(beijingHour: Int) -> DialSpoke? {
        spokes.first { $0.beijingHour == beijingHour }
    }

    /// 同一内圈公历日、同一钟点出现在两个以上角度。秋令时回拨会这样，普通跨日不会。
    public var repeatedInnerClockHours: [InnerClockHour] {
        var counts: [InnerClockHour: Int] = [:]
        for spoke in spokes {
            let key = InnerClockHour(
                year: spoke.inner.year,
                month: spoke.inner.month,
                day: spoke.inner.day,
                hour: spoke.inner.hour
            )
            counts[key, default: 0] += 1
        }
        return counts.filter { $0.value > 1 }.map(\.key).sorted { lhs, rhs in
            (lhs.year, lhs.month, lhs.day, lhs.hour) < (rhs.year, rhs.month, rhs.day, rhs.hour)
        }
    }
}

public struct InnerClockHour: Equatable, Hashable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int

    public init(year: Int, month: Int, day: Int, hour: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
    }
}

public enum DayRelation: Equatable {
    case yesterday
    case today
    case tomorrow
    case other(Int)

    public var title: String {
        switch self {
        case .yesterday: return "昨天"
        case .today: return "今天"
        case .tomorrow: return "明天"
        case .other(let delta):
            if delta < 0 { return "早 \(abs(delta)) 天" }
            return "晚 \(delta) 天"
        }
    }
}
