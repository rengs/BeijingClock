import Foundation
import XCTest
@testable import BeijingTimeCore

final class DualClockDialTests: XCTestCase {
    private var losAngeles: TimeZone { DualClockDial.resolvedInnerZone(identifier: "America/Los_Angeles") }

    func testDefaultAndInvalidZonesFallBackToLosAngeles() {
        XCTAssertEqual(DualClockDial.resolvedInnerZone(identifier: nil).identifier, "America/Los_Angeles")
        XCTAssertEqual(DualClockDial.resolvedInnerZone(identifier: "").identifier, "America/Los_Angeles")
        XCTAssertEqual(DualClockDial.resolvedInnerZone(identifier: "   ").identifier, "America/Los_Angeles")
        XCTAssertEqual(DualClockDial.resolvedInnerZone(identifier: "Not/AZone").identifier, "America/Los_Angeles")
        XCTAssertEqual(DualClockDial.resolvedInnerZone(identifier: "PST").identifier, "America/Los_Angeles")
        XCTAssertEqual(DualClockDial.resolvedInnerZone(identifier: "America/Los_Angeles").identifier, "America/Los_Angeles")
        XCTAssertEqual(DualClockDial.shortName(for: nil), "洛杉矶")
        XCTAssertEqual(DualClockDial.shortName(for: "America/Los_Angeles"), "洛杉矶")
        XCTAssertEqual(DualClockDial.shortName(for: "Asia/Kolkata"), "加尔各答")
        XCTAssertTrue(DualClockDial.suggestedInnerIdentifiers.contains("America/Los_Angeles"))
        XCTAssertEqual(DualClockDial.suggestedInnerIdentifiers.first, "America/Los_Angeles")
    }

    func testBeijingEightIsPreviousDaySixteenInWinterAndSeventeenInSummer() throws {
        let winter = try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 8, minute: 0))
        let winterPair = DualClockDial.pair(at: winter, innerZone: losAngeles)
        XCTAssertEqual(winterPair.beijing.hour, 8)
        XCTAssertEqual(winterPair.beijing.day, 15)
        XCTAssertEqual(winterPair.inner.year, 2024)
        XCTAssertEqual(winterPair.inner.month, 1)
        XCTAssertEqual(winterPair.inner.day, 14)
        XCTAssertEqual(winterPair.inner.hour, 16)
        XCTAssertEqual(winterPair.inner.minute, 0)
        XCTAssertEqual(winterPair.inner.offsetSeconds, -8 * 3600)
        XCTAssertFalse(winterPair.inner.isDaylightSavingTime)
        XCTAssertEqual(winterPair.dayRelation, .yesterday)
        XCTAssertEqual(DualClockDial.twelveHour(winterPair.beijing).text, "上午 8:00")
        XCTAssertEqual(DualClockDial.twelveHour(winterPair.inner).text, "下午 4:00")
        XCTAssertEqual(DualClockDial.angleDegrees(hour: 8, minute: 0), 240, accuracy: 0.001)
        XCTAssertEqual(DualClockDial.outerMark(beijingHour: 8), "早8")

        let summer = try require(BeijingTime.date(CivilDate(year: 2024, month: 7, day: 15), hour: 8, minute: 0))
        let summerPair = DualClockDial.pair(at: summer, innerZone: losAngeles)
        XCTAssertEqual(summerPair.inner.day, 14)
        XCTAssertEqual(summerPair.inner.hour, 17)
        XCTAssertEqual(summerPair.inner.offsetSeconds, -7 * 3600)
        XCTAssertTrue(summerPair.inner.isDaylightSavingTime)
        XCTAssertEqual(summerPair.dayRelation, .yesterday)
        XCTAssertEqual(DualClockDial.twelveHour(summerPair.inner).text, "下午 5:00")
        XCTAssertNotEqual(winterPair.inner.offsetSeconds, summerPair.inner.offsetSeconds)
    }

    func testBeijingMidnightCrossesToThePreviousLosAngelesDate() throws {
        let winter = try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 0, minute: 0))
        let winterPair = DualClockDial.pair(at: winter, innerZone: losAngeles)
        XCTAssertEqual(winterPair.beijing.hour, 0)
        XCTAssertEqual(winterPair.inner.day, 14)
        XCTAssertEqual(winterPair.inner.hour, 8)
        XCTAssertEqual(winterPair.dayRelation, .yesterday)
        XCTAssertEqual(DualClockDial.twelveHour(winterPair.beijing).text, "上午 12:00")
        XCTAssertEqual(DualClockDial.angleDegrees(hour: 0, minute: 0), 0, accuracy: 0.001)
        XCTAssertEqual(DualClockDial.angleDegrees(hour: 12, minute: 0), 0, accuracy: 0.001)
        let noon = try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 12, minute: 0))
        let noonReading = DualClockDial.twelveHour(DualClockDial.pair(at: noon, innerZone: losAngeles).beijing)
        XCTAssertEqual(noonReading.hourOnFace, 12)
        XCTAssertEqual(noonReading.period, .afternoon)
        XCTAssertEqual(noonReading.text, "下午 12:00")
        XCTAssertEqual(DualClockDial.halfDay(ofHour: 0), .morning)
        XCTAssertEqual(DualClockDial.halfDay(ofHour: 12), .afternoon)

        let summer = try require(BeijingTime.date(CivilDate(year: 2024, month: 7, day: 15), hour: 0, minute: 0))
        let summerPair = DualClockDial.pair(at: summer, innerZone: losAngeles)
        XCTAssertEqual(summerPair.inner.day, 14)
        XCTAssertEqual(summerPair.inner.hour, 9)
        XCTAssertEqual(summerPair.dayRelation, .yesterday)
    }

    func testSameAngleIsOneInstantNotTwoIndependentClocks() throws {
        let day = DualClockDial.beijingDay(
            containing: try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 12, minute: 0)),
            innerZone: losAngeles
        )
        let cycle = DualClockDial.cycle(containing: try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 8, minute: 0)), innerZone: losAngeles)
        XCTAssertEqual(cycle.half, .morning)
        XCTAssertEqual(cycle.spokes.count, 12)
        XCTAssertEqual(cycle.spokes.map(\.beijingHour), Array(0..<12))
        XCTAssertEqual(cycle.spokes.map(\.angleDegrees), (0..<12).map { DualClockDial.angleDegrees(hour: $0, minute: 0) })
        let eight = try XCTUnwrap(cycle.displayedDay.spoke(beijingHour: 8))
        XCTAssertEqual(eight.angleDegrees, 240, accuracy: 0.001)
        XCTAssertEqual(eight.inner.hour, 16)
        XCTAssertEqual(eight.inner.day, 14)
        let pair = DualClockDial.pair(at: eight.instant, innerZone: losAngeles)
        XCTAssertEqual(pair.instant, eight.instant)
        XCTAssertEqual(pair.inner, eight.inner)
        XCTAssertEqual(pair.beijing.hour, 8)
        let midnight = try requireSpoke(day, hour: 0)
        XCTAssertNotEqual(midnight.inner.hour, 0)
        XCTAssertEqual(midnight.angleDegrees, 0, accuracy: 0.001)
        XCTAssertEqual(DualClockDial.angleDegrees(hour: 3, minute: 0), 90, accuracy: 0.001)
        XCTAssertEqual(DualClockDial.angleDegrees(hour: 6, minute: 0), 180, accuracy: 0.001)
        XCTAssertEqual(DualClockDial.angleDegrees(hour: 9, minute: 0), 270, accuracy: 0.001)
        XCTAssertEqual(DualClockDial.angleDegrees(hour: 8, minute: 0), DualClockDial.angleDegrees(hour: 20, minute: 0), accuracy: 0.001)
        XCTAssertEqual(DualClockDial.outerMark(beijingHour: 20), "晚8")
        XCTAssertNotEqual(DualClockDial.outerMark(beijingHour: 8), DualClockDial.outerMark(beijingHour: 20))
        let evening = DualClockDial.cycle(containing: try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 20, minute: 0)), innerZone: losAngeles)
        XCTAssertEqual(evening.half, .afternoon)
        XCTAssertEqual(evening.displayedDay.spoke(beijingHour: 20)?.inner.hour, 4)
        XCTAssertEqual(evening.displayedDay.spoke(beijingHour: 20)?.inner.day, 15)
        XCTAssertEqual(DualClockDial.twelveHour(evening.displayedDay.spoke(beijingHour: 20)!.inner).text, "上午 4:00")
        XCTAssertNil(evening.displayedDay.spoke(beijingHour: 8))
        XCTAssertEqual(day.distinctOffsets, [-8 * 3600])
    }

    func testSpringForwardSkipsAnHourAndDoesNotUseOneOffsetAllDay() throws {
        let day = DualClockDial.cycle(
            containing: try require(BeijingTime.date(CivilDate(year: 2024, month: 3, day: 10), hour: 18, minute: 0)),
            innerZone: losAngeles
        ).displayedDay
        XCTAssertEqual(DualClockDial.cycle(containing: try require(BeijingTime.date(CivilDate(year: 2024, month: 3, day: 10), hour: 18, minute: 0)), innerZone: losAngeles).half, .afternoon)
        XCTAssertEqual(day.distinctOffsets, [-8 * 3600, -7 * 3600])
        let before = try requireSpoke(day, hour: 17)
        let after = try requireSpoke(day, hour: 18)
        XCTAssertEqual(before.inner.hour, 1)
        XCTAssertEqual(before.inner.day, 10)
        XCTAssertEqual(before.inner.offsetSeconds, -8 * 3600)
        XCTAssertFalse(before.inner.isDaylightSavingTime)
        XCTAssertEqual(after.inner.hour, 3)
        XCTAssertEqual(after.inner.day, 10)
        XCTAssertEqual(after.inner.offsetSeconds, -7 * 3600)
        XCTAssertTrue(after.inner.isDaylightSavingTime)
        XCTAssertFalse(day.spokes.contains { $0.inner.day == 10 && $0.inner.hour == 2 })
        XCTAssertTrue(day.repeatedInnerClockHours.isEmpty)
    }

    func testFallBackRepeatsAnHourWithTwoOffsets() throws {
        let day = DualClockDial.cycle(
            containing: try require(BeijingTime.date(CivilDate(year: 2024, month: 11, day: 3), hour: 16, minute: 0)),
            innerZone: losAngeles
        ).displayedDay
        XCTAssertEqual(day.distinctOffsets, [-8 * 3600, -7 * 3600])
        let first = try requireSpoke(day, hour: 16)
        let second = try requireSpoke(day, hour: 17)
        XCTAssertEqual(first.inner.hour, 1)
        XCTAssertEqual(second.inner.hour, 1)
        XCTAssertEqual(first.inner.day, 3)
        XCTAssertEqual(second.inner.day, 3)
        XCTAssertNotEqual(first.inner.offsetSeconds, second.inner.offsetSeconds)
        XCTAssertNotEqual(first.instant, second.instant)
        XCTAssertEqual(
            day.repeatedInnerClockHours,
            [InnerClockHour(year: 2024, month: 11, day: 3, hour: 1)]
        )
    }

    func testUtcAndFractionalOffsetsShareTheBeijingAngle() throws {
        let instant = try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 8, minute: 0))
        let utc = DualClockDial.pair(at: instant, innerZone: DualClockDial.resolvedInnerZone(identifier: "UTC"))
        XCTAssertEqual(utc.inner.hour, 0)
        XCTAssertEqual(utc.inner.day, 15)
        XCTAssertEqual(utc.inner.offsetSeconds, 0)
        XCTAssertEqual(utc.dayRelation, .today)

        let kolkata = DualClockDial.resolvedInnerZone(identifier: "Asia/Kolkata")
        let kolkataPair = DualClockDial.pair(at: instant, innerZone: kolkata)
        XCTAssertEqual(kolkataPair.inner.hour, 5)
        XCTAssertEqual(kolkataPair.inner.minute, 30)
        XCTAssertEqual(kolkataPair.inner.offsetSeconds, 5 * 3600 + 30 * 60)
        XCTAssertEqual(DualClockDial.clockLabel(kolkataPair.inner), "05:30")

        let kathmandu = DualClockDial.resolvedInnerZone(identifier: "Asia/Kathmandu")
        let kathmanduPair = DualClockDial.pair(at: instant, innerZone: kathmandu)
        XCTAssertEqual(kathmanduPair.inner.hour, 5)
        XCTAssertEqual(kathmanduPair.inner.minute, 45)
        XCTAssertEqual(kathmanduPair.inner.offsetSeconds, 5 * 3600 + 45 * 60)

        let stJohns = DualClockDial.resolvedInnerZone(identifier: "America/St_Johns")
        let stJohnsPair = DualClockDial.pair(at: instant, innerZone: stJohns)
        XCTAssertEqual(stJohnsPair.inner.minute, 30)
        XCTAssertEqual(stJohnsPair.inner.offsetSeconds % 3600, -1800)

        let day = DualClockDial.cycle(containing: instant, innerZone: kolkata).displayedDay
        let spoke = try requireSpoke(day, hour: 8)
        XCTAssertEqual(spoke.angleDegrees, DualClockDial.angleDegrees(hour: 8, minute: 0), accuracy: 0.001)
        XCTAssertEqual(spoke.inner.hour, 5)
        XCTAssertEqual(spoke.inner.minute, 30)
        XCTAssertEqual(spoke.instant, instant)
    }

    func testTimelineUsesQuarterHourBudgetAndInsertsDaylightTransition() throws {
        XCTAssertGreaterThanOrEqual(DualClockDial.timelineSpacing, 60)
        XCTAssertLessThanOrEqual(DualClockDial.timelineEntryLimit, 32)
        let quiet = try require(BeijingTime.date(CivilDate(year: 2024, month: 1, day: 15), hour: 12, minute: 0))
        let quietDates = DualClockDial.timelineDates(startingAt: quiet, innerZone: losAngeles)
        XCTAssertEqual(quietDates.first, quiet)
        XCTAssertLessThanOrEqual(quietDates.count, DualClockDial.timelineEntryLimit)
        XCTAssertEqual(quietDates.count, 25)
        for pair in zip(quietDates, quietDates.dropFirst()) {
            XCTAssertEqual(pair.1.timeIntervalSince(pair.0), DualClockDial.timelineSpacing, accuracy: 0.001)
        }

        let nearSpring = try require(BeijingTime.date(CivilDate(year: 2024, month: 3, day: 10), hour: 16, minute: 7))
        let springDates = DualClockDial.timelineDates(startingAt: nearSpring, innerZone: losAngeles)
        let transition = try XCTUnwrap(losAngeles.nextDaylightSavingTimeTransition(after: nearSpring))
        XCTAssertTrue(springDates.contains(transition))
        let before = DualClockDial.pair(at: transition.addingTimeInterval(-1), innerZone: losAngeles)
        let after = DualClockDial.pair(at: transition, innerZone: losAngeles)
        XCTAssertNotEqual(before.inner.offsetSeconds, after.inner.offsetSeconds)
        XCTAssertEqual(
            DualClockDial.instantOffsetPhrase(beijing: before.beijing, inner: before.inner),
            "此刻内圈比北京晚 16 小时"
        )
        XCTAssertEqual(
            DualClockDial.instantOffsetPhrase(beijing: after.beijing, inner: after.inner),
            "此刻内圈比北京晚 15 小时"
        )
    }

    func testWidgetSourcesKeepTheExtensionContract() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let widget = try String(
            contentsOf: root.appendingPathComponent("Sources/BeijingClockWidget/DualClockWidget.swift"),
            encoding: .utf8
        )
        let view = try String(
            contentsOf: root.appendingPathComponent("Sources/BeijingClockWidget/DualClockWidgetView.swift"),
            encoding: .utf8
        )
        XCTAssertEqual(view.components(separatedBy: "DualClockRing(").count - 1, 1)
        XCTAssertTrue(view.contains("containerBackground"))
        XCTAssertFalse(view.contains("Color(white:"))
        let plist = try String(
            contentsOf: root.appendingPathComponent("WidgetExtension/Info.plist"),
            encoding: .utf8
        )
        let entitlements = try String(
            contentsOf: root.appendingPathComponent("WidgetExtension/BeijingClockWidget.entitlements"),
            encoding: .utf8
        )
        let appPlist = try String(
            contentsOf: root.appendingPathComponent("Packaging/Info.plist"),
            encoding: .utf8
        )
        for identifier in DualClockDial.suggestedInnerIdentifiers {
            XCTAssertTrue(widget.contains("\"\(identifier)\""), identifier)
        }
        XCTAssertTrue(widget.contains("AppIntentConfiguration"))
        XCTAssertTrue(widget.contains("timelineSpacing"))
        XCTAssertFalse(widget.contains("WidgetCenter"))
        XCTAssertTrue(plist.contains("com.apple.widgetkit-extension"))
        XCTAssertTrue(plist.contains("<string>14.0</string>"))
        XCTAssertTrue(entitlements.contains("com.apple.security.app-sandbox"))
        XCTAssertFalse(entitlements.contains("application-groups"))
        XCTAssertTrue(appPlist.contains("<key>LSMinimumSystemVersion</key>"))
        XCTAssertTrue(appPlist.contains("<string>13.0</string>"))
        XCTAssertTrue(appPlist.contains("<string>1.0.1</string>"))
    }

    private func require(_ date: Date?, file: StaticString = #filePath, line: UInt = #line) throws -> Date {
        try XCTUnwrap(date, file: file, line: line)
    }

    private func requireSpoke(
        _ day: BeijingDialDay,
        hour: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> DialSpoke {
        try XCTUnwrap(day.spoke(beijingHour: hour), file: file, line: line)
    }
}
