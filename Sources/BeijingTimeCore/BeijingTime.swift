import Foundation

/// 公历日期，按北京时间的年月日理解，不携带时区偏移。
public struct CivilDate: Codable, Hashable, Equatable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

public struct BeijingParts: Equatable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var second: Int
    /// Gregorian weekday, 1 = Sunday … 7 = Saturday.
    public var weekday: Int

    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, weekday: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.weekday = weekday
    }

    public var civilDate: CivilDate {
        CivilDate(year: year, month: month, day: day)
    }
}

/// 所有钟点与日期都固定在 Asia/Shanghai，不读取系统时区。
public enum BeijingTime {
    public static let identifier = "Asia/Shanghai"

    public static let timeZone: TimeZone = {
        if let zone = TimeZone(identifier: identifier) {
            return zone
        }
        // ICU 始终带有该标识。缺失时明确失败，而不是退回系统时区。
        return TimeZone(secondsFromGMT: 8 * 60 * 60) ?? TimeZone.gmt
    }()

    public static func calendar(locale: Locale) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        return calendar
    }

    public static func parts(_ date: Date, in zone: TimeZone? = nil) -> BeijingParts {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone ?? timeZone
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday],
            from: date
        )
        return BeijingParts(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            weekday: components.weekday ?? 0
        )
    }

    /// 把北京公历日期和钟点变成绝对瞬间。非法日期（例如 2 月 31 日）返回 nil。
    public static func date(_ civil: CivilDate, hour: Int, minute: Int, second: Int = 0) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            return nil
        }
        let calendar = self.calendar(locale: Locale(identifier: "en_US_POSIX"))
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = civil.year
        components.month = civil.month
        components.day = civil.day
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let date = calendar.date(from: components) else { return nil }
        let back = parts(date)
        guard back.year == civil.year,
              back.month == civil.month,
              back.day == civil.day,
              back.hour == hour,
              back.minute == minute,
              back.second == second
        else {
            return nil
        }
        return date
    }

    public static func addingDays(_ delta: Int, to civil: CivilDate) -> CivilDate? {
        guard let noon = date(civil, hour: 12, minute: 0) else { return nil }
        let calendar = self.calendar(locale: Locale(identifier: "en_US_POSIX"))
        guard let shifted = calendar.date(byAdding: .day, value: delta, to: noon) else { return nil }
        return parts(shifted).civilDate
    }

    public static func hourMinute(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static func monthDay(_ date: CivilDate) -> String {
        "\(date.month)月\(date.day)日"
    }
}
