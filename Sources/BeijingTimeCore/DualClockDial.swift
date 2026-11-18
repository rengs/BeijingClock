import Foundation

/// 12 小时双环。12 在正上方，顺时针到 1…11。外圈和内圈共用圆心。
/// 同一条半径只对应此刻这一圈（上午或下午）里的一个绝对时刻。
/// 0 点与 12 点、早 8 与晚 8 角度相同，所以表盘数字不能单独代表全天 24 小时。
public enum DualClockDial {
    public static let defaultInnerIdentifier = "America/Los_Angeles"
    public static let emphasizedBeijingHour = 8
    public static let morningEightMark = "早8"
    public static let eveningEightMark = "晚8"

    public static func shortName(for identifier: String?) -> String {
        let raw = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch raw {
        case "", defaultInnerIdentifier: return "洛杉矶"
        case "America/Vancouver": return "温哥华"
        case "America/Denver": return "丹佛"
        case "America/Chicago": return "芝加哥"
        case "America/New_York": return "纽约"
        case "America/St_Johns": return "纽芬兰"
        case "America/Sao_Paulo": return "圣保罗"
        case "UTC", "GMT", "Etc/UTC", "Etc/GMT": return "UTC"
        case "Europe/London": return "伦敦"
        case "Europe/Paris": return "巴黎"
        case "Africa/Cairo": return "开罗"
        case "Europe/Moscow": return "莫斯科"
        case "Asia/Tehran": return "德黑兰"
        case "Asia/Kolkata", "Asia/Calcutta": return "加尔各答"
        case "Asia/Kathmandu", "Asia/Katmandu": return "加德满都"
        case "Asia/Shanghai": return "北京"
        case "Asia/Tokyo": return "东京"
        case "Australia/Adelaide": return "阿德莱德"
        case "Australia/Eucla": return "尤克拉"
        case "Australia/Sydney": return "悉尼"
        case "Pacific/Auckland": return "奥克兰"
        case "Pacific/Chatham": return "查塔姆"
        case "Pacific/Honolulu": return "檀香山"
        default:
            let resolved = resolvedInnerZone(identifier: raw).identifier
            if resolved == defaultInnerIdentifier && raw != defaultInnerIdentifier {
                return "洛杉矶"
            }
            return resolved.split(separator: "/").last.map(String.init) ?? "洛杉矶"
        }
    }

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

    /// 12 点在正上方，顺时针。8 点与 20 点得到同一个角度。
    public static func angleDegrees(hour: Int, minute: Int, second: Int = 0) -> Double {
        let wrapped = ((hour % 12) + 12) % 12
        let seconds = Double(wrapped * 3600 + minute * 60 + second)
        return seconds / 43_200.0 * 360.0
    }

    public static func halfDay(ofHour hour: Int) -> HalfDay {
        hour < 12 ? .morning : .afternoon
    }

    public static func twelveHour(_ reading: ZoneReading) -> TwelveHourReading {
        let period = halfDay(ofHour: reading.hour)
        let face = reading.hour % 12 == 0 ? 12 : reading.hour % 12
        let text = String(format: "%@ %d:%02d", period.title, face, reading.minute)
        return TwelveHourReading(hourOnFace: face, minute: reading.minute, period: period, text: text)
    }

    /// 上午 8 点写成「早8」。下午 8 点写成「晚8」，不能再叫早 8。
    public static func outerMark(beijingHour: Int) -> String {
        if beijingHour == 8 { return morningEightMark }
        if beijingHour == 20 { return eveningEightMark }
        return beijingHour % 12 == 0 ? "12" : "\(beijingHour % 12)"
    }

    public static func cycleHint(for half: HalfDay) -> String {
        switch half {
        case .morning:
            return "这一圈是北京上午，从午夜 12 点到中午前。8 点是早 8。"
        case .afternoon:
            return "这一圈是北京下午，从中午 12 点到午夜前。8 点是晚 8，不是早 8。"
        }
    }

    /// 只画出包含此刻的那 12 个北京小时。另一半要等时刻进入下一圈才换。
    public static func cycle(containing date: Date, innerZone: TimeZone) -> TwelveHourCycle {
        let beijingNow = reading(date, in: BeijingTime.timeZone)
        let half = halfDay(ofHour: beijingNow.hour)
        let start = half == .morning ? 0 : 12
        var spokes: [DialSpoke] = []
        spokes.reserveCapacity(12)
        for hour in start..<(start + 12) {
            guard let instant = BeijingTime.date(beijingNow.civilDate, hour: hour, minute: 0) else { continue }
            spokes.append(DialSpoke(
                beijingHour: hour,
                angleDegrees: angleDegrees(hour: hour, minute: 0),
                instant: instant,
                inner: reading(instant, in: innerZone)
            ))
        }
        return TwelveHourCycle(civilDate: beijingNow.civilDate, half: half, spokes: spokes)
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

    /// 北京这一公历日的 24 个整点。8 点与 20 点角度相同，不能靠角度区分早晚。
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

public enum HalfDay: Equatable {
    case morning
    case afternoon

    public var title: String {
        self == .morning ? "上午" : "下午"
    }
}

public struct TwelveHourReading: Equatable {
    public var hourOnFace: Int
    public var minute: Int
    public var period: HalfDay
    public var text: String

    public init(hourOnFace: Int, minute: Int, period: HalfDay, text: String) {
        self.hourOnFace = hourOnFace
        self.minute = minute
        self.period = period
        self.text = text
    }
}

public struct TwelveHourCycle: Equatable {
    public var civilDate: CivilDate
    public var half: HalfDay
    public var spokes: [DialSpoke]

    public init(civilDate: CivilDate, half: HalfDay, spokes: [DialSpoke]) {
        self.civilDate = civilDate
        self.half = half
        self.spokes = spokes
    }

    public var displayedDay: BeijingDialDay {
        BeijingDialDay(civilDate: civilDate, spokes: spokes)
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
