import AppIntents
import SwiftUI
import WidgetKit
#if canImport(BeijingTimeCore)
import BeijingTimeCore
#endif

enum InnerZoneChoice: String, AppEnum {
    case losAngeles = "America/Los_Angeles"
    case vancouver = "America/Vancouver"
    case denver = "America/Denver"
    case chicago = "America/Chicago"
    case newYork = "America/New_York"
    case stJohns = "America/St_Johns"
    case saoPaulo = "America/Sao_Paulo"
    case utc = "UTC"
    case london = "Europe/London"
    case paris = "Europe/Paris"
    case cairo = "Africa/Cairo"
    case moscow = "Europe/Moscow"
    case tehran = "Asia/Tehran"
    case kolkata = "Asia/Kolkata"
    case kathmandu = "Asia/Kathmandu"
    case shanghai = "Asia/Shanghai"
    case tokyo = "Asia/Tokyo"
    case adelaide = "Australia/Adelaide"
    case eucla = "Australia/Eucla"
    case sydney = "Australia/Sydney"
    case auckland = "Pacific/Auckland"
    case chatham = "Pacific/Chatham"
    case honolulu = "Pacific/Honolulu"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "内圈时区")
    }

    static var caseDisplayRepresentations: [InnerZoneChoice: DisplayRepresentation] {
        [
            .losAngeles: "洛杉矶",
            .vancouver: "温哥华",
            .denver: "丹佛",
            .chicago: "芝加哥",
            .newYork: "纽约",
            .stJohns: "纽芬兰",
            .saoPaulo: "圣保罗",
            .utc: "UTC",
            .london: "伦敦",
            .paris: "巴黎",
            .cairo: "开罗",
            .moscow: "莫斯科",
            .tehran: "德黑兰",
            .kolkata: "加尔各答",
            .kathmandu: "加德满都",
            .shanghai: "北京",
            .tokyo: "东京",
            .adelaide: "阿德莱德",
            .eucla: "尤克拉",
            .sydney: "悉尼",
            .auckland: "奥克兰",
            .chatham: "查塔姆",
            .honolulu: "檀香山"
        ]
    }
}

struct DualClockIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "双时区环"
    static var description = IntentDescription("外圈是北京时间。内圈选择另一个时区，默认洛杉矶。")

    @Parameter(title: "内圈时区", default: .losAngeles)
    var innerZone: InnerZoneChoice
}

struct DualClockEntry: TimelineEntry {
    var date: Date
    var innerIdentifier: String
}

struct DualClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DualClockEntry {
        DualClockEntry(date: Date(), innerIdentifier: DualClockDial.defaultInnerIdentifier)
    }

    func snapshot(for configuration: DualClockIntent, in context: Context) async -> DualClockEntry {
        entry(for: configuration, at: Date())
    }

    func timeline(for configuration: DualClockIntent, in context: Context) async -> Timeline<DualClockEntry> {
        let zone = DualClockDial.resolvedInnerZone(identifier: configuration.innerZone.rawValue)
        let now = Date()
        let dates = DualClockDial.timelineDates(startingAt: now, innerZone: zone)
        let entries = dates.map { date in
            DualClockEntry(date: date, innerIdentifier: zone.identifier)
        }
        let next = dates.last?.addingTimeInterval(DualClockDial.timelineSpacing) ?? now.addingTimeInterval(DualClockDial.timelineSpacing)
        return Timeline(entries: entries, policy: .after(next))
    }

    private func entry(for configuration: DualClockIntent, at date: Date) -> DualClockEntry {
        let zone = DualClockDial.resolvedInnerZone(identifier: configuration.innerZone.rawValue)
        return DualClockEntry(date: date, innerIdentifier: zone.identifier)
    }
}

struct DualClockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "local.beijingclock.jingshi.dual-clock",
            intent: DualClockIntent.self,
            provider: DualClockProvider()
        ) { entry in
            DualClockWidgetView(entry: entry)
        }
        .configurationDisplayName("京时双环")
        .description("外圈北京时间，内圈为所选时区。同一角度是同一个时刻。北京早 8 点有刻度标记。")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct BeijingClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        DualClockWidget()
    }
}
