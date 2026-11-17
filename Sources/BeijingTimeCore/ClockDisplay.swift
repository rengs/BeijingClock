import Foundation

public enum HourCycle: String, Codable, Equatable {
    /// 使用语言区域的公开小时周期，不读取菜单栏时钟的私有偏好。
    case followLocale
    case h12
    case h24
}

public enum LocaleChoice: String, Codable, Equatable {
    case system
    case simplifiedChinese
}

/// 菜单栏文字选项。默认接近常见系统时钟：系统字号、不标「北京」、不显示秒。
/// 不读取 com.apple.menuextra.clock 或控制中心的私有键。
public struct ClockDisplayOptions: Codable, Equatable {
    public var showDate: Bool
    public var showWeekday: Bool
    public var hourCycle: HourCycle
    public var showSeconds: Bool
    public var flashSeparators: Bool
    public var showBeijingMark: Bool
    public var localeChoice: LocaleChoice
    /// nil 表示使用系统菜单栏字体和字号。
    public var customFontSize: Double?

    public init(
        showDate: Bool = false,
        showWeekday: Bool = true,
        hourCycle: HourCycle = .followLocale,
        showSeconds: Bool = false,
        flashSeparators: Bool = false,
        showBeijingMark: Bool = false,
        localeChoice: LocaleChoice = .system,
        customFontSize: Double? = nil
    ) {
        self.showDate = showDate
        self.showWeekday = showWeekday
        self.hourCycle = hourCycle
        self.showSeconds = showSeconds
        self.flashSeparators = flashSeparators
        self.showBeijingMark = showBeijingMark
        self.localeChoice = localeChoice
        self.customFontSize = customFontSize
    }

    public static let standard = ClockDisplayOptions()
}

public enum MenuBarMetrics {
    public static let customFontSizeBounds: ClosedRange<Double> = 10...14

    public static func clampedFontSize(_ value: Double) -> Double {
        min(customFontSizeBounds.upperBound, max(customFontSizeBounds.lowerBound, value))
    }
}

public enum ClockFormatter {
    public static func resolvedLocale(options: ClockDisplayOptions, systemLocale: Locale) -> Locale {
        switch options.localeChoice {
        case .system:
            return systemLocale
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    /// 菜单栏上的一行字。分隔符闪烁只是近似，不能与系统时钟同步。
    public static func menuBarString(
        at date: Date,
        options: ClockDisplayOptions,
        systemLocale: Locale = .current,
        separatorsVisible: Bool = true
    ) -> String {
        let locale = resolvedLocale(options: options, systemLocale: systemLocale)
        var parts: [String] = []
        if options.showDate {
            parts.append(dateToken(date, locale: locale, options: options))
        }
        if options.showWeekday {
            parts.append(weekdayToken(date, locale: locale, options: options))
        }
        parts.append(timeToken(date, locale: locale, options: options))
        var text = parts.joined(separator: " ")
        if options.showBeijingMark {
            text += " 北京"
        }
        if options.flashSeparators, !separatorsVisible {
            text = text.replacingOccurrences(of: ":", with: "\u{2007}")
        }
        return text
    }

    /// 弹出层始终用北京时间 24 小时制并带秒，避免和菜单栏的 12 小时选项混淆。
    public static func popoverTime(at date: Date) -> String {
        let parts = BeijingTime.parts(date)
        return String(format: "%02d:%02d:%02d", parts.hour, parts.minute, parts.second)
    }

    public static func popoverDate(at date: Date) -> String {
        let parts = BeijingTime.parts(date)
        let calendar = BeijingTime.calendar(locale: Locale(identifier: "zh-Hans"))
        let symbols = calendar.weekdaySymbols
        let index = parts.weekday - 1
        let weekday = symbols.indices.contains(index) ? symbols[index] : ""
        return "\(parts.year)年\(parts.month)月\(parts.day)日 \(weekday)"
    }

    private static func dateToken(_ date: Date, locale: Locale, options: ClockDisplayOptions) -> String {
        if options.localeChoice == .simplifiedChinese {
            return format(date, locale: locale, dateFormat: "M月d日")
        }
        return format(date, locale: locale, template: "MMMd")
    }

    private static func weekdayToken(_ date: Date, locale: Locale, options: ClockDisplayOptions) -> String {
        if options.localeChoice == .simplifiedChinese {
            return format(date, locale: Locale(identifier: "zh-Hans"), dateFormat: "EEE")
        }
        return format(date, locale: locale, template: "EEE")
    }

    private static func timeToken(_ date: Date, locale: Locale, options: ClockDisplayOptions) -> String {
        switch options.hourCycle {
        case .h24:
            let pattern = options.showSeconds ? "HH:mm:ss" : "HH:mm"
            return format(date, locale: locale, dateFormat: pattern)
        case .h12:
            let template = options.showSeconds ? "hmmss a" : "hmm a"
            return format(date, locale: locale, template: template)
        case .followLocale:
            let template = options.showSeconds ? "jmmss" : "jmm"
            return format(date, locale: locale, template: template)
        }
    }

    private static func format(_ date: Date, locale: Locale, dateFormat: String) -> String {
        let formatter = makeFormatter(locale: locale)
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    private static func format(_ date: Date, locale: Locale, template: String) -> String {
        let formatter = makeFormatter(locale: locale)
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private static func makeFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = BeijingTime.timeZone
        formatter.calendar = BeijingTime.calendar(locale: locale)
        return formatter
    }
}
