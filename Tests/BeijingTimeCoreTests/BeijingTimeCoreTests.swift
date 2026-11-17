import Foundation
import XCTest
@testable import BeijingTimeCore

final class BeijingTimeCoreTests: XCTestCase {
    private let policy = AlarmPolicy.standard

    override func setUp() {
        super.setUp()
        print("HOST_TIMEZONE=\(TimeZone.current.identifier)")
        print("HOST_LOCALE=\(Locale.current.identifier)")
    }

    func testShanghaiOffsetHasNoDaylightSaving() {
        XCTAssertEqual(BeijingTime.timeZone.identifier, "Asia/Shanghai")
        XCTAssertEqual(BeijingTime.timeZone.secondsFromGMT(for: utc("2026-01-15T00:00:00Z")), 8 * 3600)
        XCTAssertEqual(BeijingTime.timeZone.secondsFromGMT(for: utc("2026-07-15T00:00:00Z")), 8 * 3600)
    }

    func testLosAngelesConversionDoesNotUseHostZone() {
        let instant = utc("2026-11-17T00:30:00Z")
        let beijing = BeijingTime.parts(instant)
        XCTAssertEqual(beijing.year, 2026)
        XCTAssertEqual(beijing.month, 11)
        XCTAssertEqual(beijing.day, 17)
        XCTAssertEqual(beijing.hour, 8)
        XCTAssertEqual(beijing.minute, 30)
        XCTAssertEqual(beijing.weekday, 3)

        guard let losAngeles = TimeZone(identifier: "America/Los_Angeles") else {
            return XCTFail("缺少 America/Los_Angeles 时区数据")
        }
        let la = BeijingTime.parts(instant, in: losAngeles)
        XCTAssertEqual(la.year, 2026)
        XCTAssertEqual(la.month, 11)
        XCTAssertEqual(la.day, 16)
        XCTAssertEqual(la.hour, 16)
        XCTAssertEqual(la.minute, 30)
    }

    func testBeijingMidnightIsNextCivilDay() {
        let instant = utc("2026-11-17T16:00:00Z")
        let beijing = BeijingTime.parts(instant)
        XCTAssertEqual(beijing.civilDate, CivilDate(year: 2026, month: 11, day: 18))
        XCTAssertEqual(beijing.hour, 0)
        XCTAssertEqual(beijing.minute, 0)
        XCTAssertEqual(beijing.second, 0)

        guard let losAngeles = TimeZone(identifier: "America/Los_Angeles") else {
            return XCTFail("缺少 America/Los_Angeles 时区数据")
        }
        let la = BeijingTime.parts(instant, in: losAngeles)
        XCTAssertEqual(la.day, 17)
        XCTAssertEqual(la.hour, 8)
    }

    func testInvalidCivilDatesAreRejected() {
        XCTAssertNil(BeijingTime.date(CivilDate(year: 2026, month: 2, day: 31), hour: 7, minute: 30))
        XCTAssertNil(BeijingTime.date(CivilDate(year: 2026, month: 11, day: 17), hour: 24, minute: 0))
        XCTAssertNil(BeijingTime.date(CivilDate(year: 2026, month: 11, day: 17), hour: 7, minute: 60))
        let made = Alarm.make(title: "x", hour: 7, minute: 30, enabled: true, schedule: .once(CivilDate(year: 2026, month: 2, day: 31)))
        guard case .failure(let error) = made else {
            return XCTFail("2 月 31 日应被拒绝")
        }
        XCTAssertEqual(error, .invalidDate)
        guard case .failure(let timeError) = Alarm.make(title: "x", hour: 24, minute: 0, enabled: true, schedule: .daily) else {
            return XCTFail("24 点应被拒绝")
        }
        XCTAssertEqual(timeError, .invalidTime)
    }

    func testEmptyTitleBecomesDefault() {
        guard case .success(let alarm) = Alarm.make(title: "  ", hour: 7, minute: 5, enabled: true, schedule: .daily) else {
            return XCTFail("空标题应得到默认名称")
        }
        XCTAssertEqual(alarm.title, "闹钟")
    }

    func testAddingDaysRollsMonthAndYear() {
        XCTAssertEqual(
            BeijingTime.addingDays(1, to: CivilDate(year: 2026, month: 11, day: 30)),
            CivilDate(year: 2026, month: 12, day: 1)
        )
        XCTAssertEqual(
            BeijingTime.addingDays(1, to: CivilDate(year: 2026, month: 12, day: 31)),
            CivilDate(year: 2027, month: 1, day: 1)
        )
        XCTAssertEqual(
            BeijingTime.addingDays(1, to: CivilDate(year: 2026, month: 2, day: 28)),
            CivilDate(year: 2026, month: 3, day: 1)
        )
    }

    func testDailyAndOnceNextOccurrenceAroundBeijingMidnight() {
        let daily = requireAlarm(Alarm.make(title: "早", hour: 0, minute: 10, enabled: true, schedule: .daily))
        let before = beijing(2026, 11, 18, 0, 5)
        let next = AlarmScheduling.nextOccurrence(of: daily, now: before)
        XCTAssertEqual(next?.civilDate, CivilDate(year: 2026, month: 11, day: 18))
        XCTAssertEqual(next?.hour, 0)
        XCTAssertEqual(next?.minute, 10)

        let after = beijing(2026, 11, 18, 0, 15)
        let rolled = AlarmScheduling.nextOccurrence(of: daily, now: after)
        XCTAssertEqual(rolled?.civilDate, CivilDate(year: 2026, month: 11, day: 19))

        let evening = beijing(2026, 11, 17, 23, 50)
        let soon = AlarmScheduling.nextOccurrence(of: daily, now: evening)
        XCTAssertEqual(soon?.civilDate, CivilDate(year: 2026, month: 11, day: 18))
        XCTAssertEqual(soon?.minute, 10)

        let lateToday = requireAlarm(Alarm.make(title: "晚", hour: 23, minute: 0, enabled: true, schedule: .daily))
        let justAfterMidnight = AlarmScheduling.nextOccurrence(of: lateToday, now: beijing(2026, 11, 18, 0, 5))
        XCTAssertEqual(justAfterMidnight?.civilDate, CivilDate(year: 2026, month: 11, day: 18))
        XCTAssertEqual(justAfterMidnight?.hour, 23)

        let once = requireAlarm(Alarm.make(
            title: "开会",
            hour: 9,
            minute: 0,
            enabled: true,
            schedule: .once(CivilDate(year: 2026, month: 11, day: 20))
        ))
        let future = AlarmScheduling.nextOccurrence(of: once, now: beijing(2026, 11, 17, 12, 0))
        XCTAssertEqual(future?.civilDate, CivilDate(year: 2026, month: 11, day: 20))
        XCTAssertEqual(future?.hour, 9)
        XCTAssertNil(AlarmScheduling.latestDue(of: once, now: beijing(2026, 11, 17, 12, 0)))
        XCTAssertNil(AlarmScheduling.nextOccurrence(of: once, now: beijing(2026, 11, 20, 9, 0)))
        XCTAssertNotNil(AlarmScheduling.latestDue(of: once, now: beijing(2026, 11, 20, 9, 0)))

        let monthEnd = requireAlarm(Alarm.make(title: "月末", hour: 10, minute: 0, enabled: true, schedule: .daily))
        let nextMonth = AlarmScheduling.nextOccurrence(of: monthEnd, now: beijing(2026, 11, 30, 11, 0))
        XCTAssertEqual(nextMonth?.civilDate, CivilDate(year: 2026, month: 12, day: 1))
    }

    func testDocumentedPolicyBounds() {
        XCTAssertEqual(policy.catchUp, 3 * 60)
        XCTAssertEqual(policy.missedNotice, 12 * 60 * 60)
        XCTAssertEqual(policy.handledRetention, 14 * 24 * 60 * 60)
    }

    func testCatchUpMissedAndExpiredBoundaries() {
        let fire = beijing(2026, 11, 18, 7, 30)
        let onceTemplate = { () -> Alarm in
            self.requireAlarm(Alarm.make(
                title: "单次",
                hour: 7,
                minute: 30,
                enabled: true,
                schedule: .once(CivilDate(year: 2026, month: 11, day: 18))
            ))
        }
        let dailyTemplate = { () -> Alarm in
            self.requireAlarm(Alarm.make(title: "每天", hour: 7, minute: 30, enabled: true, schedule: .daily))
        }

        for sample in [onceTemplate(), dailyTemplate()] {
            let onTime = AlarmScheduling.evaluate(alarms: [sample], now: fire, handled: [], policy: policy)
            XCTAssertEqual(onTime.rings.count, 1, sample.title)
            XCTAssertTrue(onTime.missed.isEmpty)
            XCTAssertTrue(onTime.expired.isEmpty)

            let edge = AlarmScheduling.evaluate(
                alarms: [sample],
                now: fire.addingTimeInterval(policy.catchUp),
                handled: [],
                policy: policy
            )
            XCTAssertEqual(edge.rings.count, 1, sample.title)

            let missed = AlarmScheduling.evaluate(
                alarms: [sample],
                now: fire.addingTimeInterval(policy.catchUp + 1),
                handled: [],
                policy: policy
            )
            XCTAssertTrue(missed.rings.isEmpty, sample.title)
            XCTAssertEqual(missed.missed.count, 1, sample.title)

            let expired = AlarmScheduling.evaluate(
                alarms: [sample],
                now: fire.addingTimeInterval(policy.missedNotice),
                handled: [],
                policy: policy
            )
            XCTAssertTrue(expired.rings.isEmpty, sample.title)
            XCTAssertTrue(expired.missed.isEmpty, sample.title)
            XCTAssertEqual(expired.expired.count, 1, sample.title)
        }

        let once = onceTemplate()
        for now in [fire, fire.addingTimeInterval(policy.catchUp + 1), fire.addingTimeInterval(policy.missedNotice)] {
            let result = AlarmScheduling.evaluate(alarms: [once], now: now, handled: [], policy: policy)
            XCTAssertFalse(result.alarms[0].enabled)
        }
        let daily = dailyTemplate()
        for now in [fire, fire.addingTimeInterval(policy.catchUp + 1), fire.addingTimeInterval(policy.missedNotice)] {
            let result = AlarmScheduling.evaluate(alarms: [daily], now: now, handled: [], policy: policy)
            XCTAssertTrue(result.alarms[0].enabled)
        }
    }

    func testDuplicateRefreshAndRestartDoNotRingAgain() throws {
        let alarm = requireAlarm(Alarm.make(id: UUID(), title: "起床", hour: 7, minute: 30, enabled: true, schedule: .daily))
        let now = beijing(2026, 11, 18, 7, 31)
        let first = AlarmScheduling.evaluate(alarms: [alarm], now: now, handled: [])
        XCTAssertEqual(first.rings.map(\.occurrence.key), [first.handled.last?.key])
        let again = AlarmScheduling.evaluate(alarms: first.alarms, now: now, handled: first.handled)
        XCTAssertTrue(again.rings.isEmpty)
        XCTAssertTrue(again.missed.isEmpty)
        XCTAssertTrue(again.expired.isEmpty)

        let url = try temporaryStateURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var state = PersistedState.empty
        state.alarms = first.alarms
        state.handled = first.handled
        let store = AlarmStore(fileURL: url)
        try store.save(state)
        let loaded = try AlarmStore(fileURL: url).load()
        XCTAssertNil(loaded.backupURL)
        let restarted = AlarmScheduling.evaluate(
            alarms: loaded.state.alarms,
            now: now,
            handled: loaded.state.handled
        )
        XCTAssertTrue(restarted.rings.isEmpty)
        XCTAssertTrue(restarted.missed.isEmpty)
        XCTAssertEqual(restarted.handled.map(\.key), first.handled.map(\.key))
    }

    func testWakeWithinCatchUpRingsOnce() {
        let alarm = requireAlarm(Alarm.make(title: "午睡", hour: 13, minute: 0, enabled: true, schedule: .daily))
        let fire = beijing(2026, 11, 18, 13, 0)
        let woke = fire.addingTimeInterval(2 * 60)
        let result = AlarmScheduling.evaluate(alarms: [alarm], now: woke, handled: [])
        XCTAssertEqual(result.rings.count, 1)
        let second = AlarmScheduling.evaluate(alarms: result.alarms, now: woke, handled: result.handled)
        XCTAssertTrue(second.rings.isEmpty)
    }

    func testEditingTimeCanRingNewOccurrenceAndDeleteRemovesIt() throws {
        let id = UUID()
        let original = requireAlarm(Alarm.make(id: id, title: "开会", hour: 7, minute: 30, enabled: true, schedule: .daily))
        let firstNow = beijing(2026, 11, 18, 7, 31)
        let first = AlarmScheduling.evaluate(alarms: [original], now: firstNow, handled: [])
        XCTAssertEqual(first.rings.count, 1)

        var edited = first.alarms[0]
        edited.minute = 32
        let secondNow = beijing(2026, 11, 18, 7, 33)
        let second = AlarmScheduling.evaluate(alarms: [edited], now: secondNow, handled: first.handled)
        XCTAssertEqual(second.rings.count, 1)
        XCTAssertNotEqual(second.rings[0].occurrence.key, first.rings[0].occurrence.key)

        var state = PersistedState(alarms: second.alarms, handled: second.handled)
        state = AlarmBook.deleting(id: id, from: state)
        XCTAssertTrue(state.alarms.isEmpty)
        XCTAssertTrue(state.handled.isEmpty)
        let afterDelete = AlarmScheduling.evaluate(alarms: state.alarms, now: secondNow, handled: state.handled)
        XCTAssertTrue(afterDelete.rings.isEmpty)
    }

    func testReenableOnceDoesNotRepeatHandledOccurrence() {
        let alarm = requireAlarm(Alarm.make(
            title: "一次",
            hour: 9,
            minute: 0,
            enabled: true,
            schedule: .once(CivilDate(year: 2026, month: 11, day: 20))
        ))
        let now = beijing(2026, 11, 20, 9, 1)
        let fired = AlarmScheduling.evaluate(alarms: [alarm], now: now, handled: [])
        XCTAssertFalse(fired.alarms[0].enabled)
        var reenabled = fired.alarms[0]
        reenabled.enabled = true
        let again = AlarmScheduling.evaluate(alarms: [reenabled], now: now, handled: fired.handled)
        XCTAssertTrue(again.rings.isEmpty)
        XCTAssertTrue(again.missed.isEmpty)
    }

    func testUpcomingUsesNextBeijingDateAndHidesHandled() {
        let alarm = requireAlarm(Alarm.make(title: "起床", hour: 7, minute: 30, enabled: true, schedule: .daily))
        let before = beijing(2026, 11, 18, 7, 0)
        let upcoming = AlarmScheduling.upcoming(alarms: [alarm], now: before, handledKeys: [])
        XCTAssertEqual(upcoming.hidden, 0)
        XCTAssertEqual(upcoming.items.map(\.summary), ["11月18日 07:30 · 每天 · 起床"])

        let fired = AlarmScheduling.evaluate(alarms: [alarm], now: beijing(2026, 11, 18, 7, 30), handled: [])
        let keys = Set(fired.handled.map(\.key))
        let after = AlarmScheduling.upcoming(alarms: fired.alarms, now: beijing(2026, 11, 18, 7, 31), handledKeys: keys)
        XCTAssertEqual(after.items.map(\.summary), ["11月19日 07:30 · 每天 · 起床"])
    }

    func testDisabledAlarmIsNotDueOrUpcoming() {
        let alarm = requireAlarm(Alarm.make(title: "关", hour: 7, minute: 30, enabled: false, schedule: .daily))
        let now = beijing(2026, 11, 18, 7, 31)
        XCTAssertNil(AlarmScheduling.latestDue(of: alarm, now: now))
        XCTAssertNil(AlarmScheduling.nextOccurrence(of: alarm, now: now))
        let result = AlarmScheduling.evaluate(alarms: [alarm], now: now, handled: [])
        XCTAssertTrue(result.rings.isEmpty)
    }

    func testClockDefaultsOmitBeijingMarkAndUseTwentyFourHourDigits() {
        let standard = ClockDisplayOptions.standard
        XCTAssertFalse(standard.showDate)
        XCTAssertTrue(standard.showWeekday)
        XCTAssertEqual(standard.hourCycle, .followLocale)
        XCTAssertFalse(standard.showSeconds)
        XCTAssertFalse(standard.flashSeparators)
        XCTAssertFalse(standard.showBeijingMark)
        XCTAssertEqual(standard.localeChoice, .system)
        XCTAssertNil(standard.customFontSize)

        let instant = utc("2026-11-17T00:30:00Z")
        var options = ClockDisplayOptions(
            showDate: false,
            showWeekday: false,
            hourCycle: .h24,
            showSeconds: false,
            showBeijingMark: false,
            localeChoice: .simplifiedChinese
        )
        XCTAssertEqual(
            ClockFormatter.menuBarString(at: instant, options: options, systemLocale: Locale(identifier: "en_US")),
            "08:30"
        )
        options.showSeconds = true
        XCTAssertEqual(
            ClockFormatter.menuBarString(at: instant, options: options, systemLocale: Locale(identifier: "en_US")),
            "08:30:00"
        )
        options.showSeconds = false
        options.showBeijingMark = true
        XCTAssertEqual(
            ClockFormatter.menuBarString(at: instant, options: options, systemLocale: Locale(identifier: "en_US")),
            "08:30 北京"
        )
        options.showBeijingMark = false
        options.flashSeparators = true
        XCTAssertEqual(
            ClockFormatter.menuBarString(at: instant, options: options, systemLocale: Locale(identifier: "en_US"), separatorsVisible: false),
            "08\u{2007}30"
        )
    }

    func testMenuBarDateFollowsBeijingNotLosAngeles() {
        let instant = utc("2026-11-17T16:00:00Z")
        let options = ClockDisplayOptions(
            showDate: true,
            showWeekday: false,
            hourCycle: .h24,
            showSeconds: true,
            showBeijingMark: false,
            localeChoice: .simplifiedChinese
        )
        let text = ClockFormatter.menuBarString(at: instant, options: options, systemLocale: Locale(identifier: "en_US"))
        XCTAssertEqual(text, "11月18日 00:00:00")
        XCTAssertFalse(text.contains("11月17日"))
        XCTAssertFalse(text.contains("08:00"))
        XCTAssertFalse(text.contains("北京"))
    }

    func testFollowLocaleTimeUsesShanghaiZone() {
        let instant = utc("2026-11-17T00:30:00Z")
        let locale = Locale(identifier: "en_US")
        let options = ClockDisplayOptions(
            showDate: false,
            showWeekday: false,
            hourCycle: .followLocale,
            showSeconds: false,
            showBeijingMark: false,
            localeChoice: .system
        )
        let text = ClockFormatter.menuBarString(at: instant, options: options, systemLocale: locale)
        let shanghai = DateFormatter()
        shanghai.locale = locale
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")
        shanghai.calendar = Calendar(identifier: .gregorian)
        shanghai.calendar.timeZone = shanghai.timeZone
        shanghai.calendar.locale = locale
        shanghai.setLocalizedDateFormatFromTemplate("jmm")
        XCTAssertEqual(text, shanghai.string(from: instant))

        guard let losAngeles = TimeZone(identifier: "America/Los_Angeles") else {
            return XCTFail("缺少 America/Los_Angeles 时区数据")
        }
        let la = DateFormatter()
        la.locale = locale
        la.timeZone = losAngeles
        la.calendar = Calendar(identifier: .gregorian)
        la.calendar.timeZone = losAngeles
        la.setLocalizedDateFormatFromTemplate("jmm")
        XCTAssertNotEqual(text, la.string(from: instant))
    }

    func testPopoverClockIsAlwaysBeijingTwentyFourHour() {
        let morning = utc("2026-11-17T00:30:00Z")
        XCTAssertEqual(ClockFormatter.popoverTime(at: morning), "08:30:00")
        let morningText = ClockFormatter.popoverDate(at: morning)
        XCTAssertTrue(morningText.hasPrefix("2026年11月17日 "), morningText)
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh-Hans")
        calendar.timeZone = BeijingTime.timeZone
        XCTAssertTrue(morningText.contains(calendar.weekdaySymbols[2]), morningText)

        let midnight = utc("2026-11-17T16:00:00Z")
        XCTAssertEqual(ClockFormatter.popoverTime(at: midnight), "00:00:00")
        XCTAssertTrue(ClockFormatter.popoverDate(at: midnight).hasPrefix("2026年11月18日 "))
    }

    func testFontSizeClamp() {
        XCTAssertEqual(MenuBarMetrics.clampedFontSize(9), 10)
        XCTAssertEqual(MenuBarMetrics.clampedFontSize(12), 12)
        XCTAssertEqual(MenuBarMetrics.clampedFontSize(20), 14)
    }

    func testStoreRoundTripEditDeleteAndCorruptFile() throws {
        let url = try temporaryStateURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AlarmStore(fileURL: url)
        let missing = try store.load()
        XCTAssertEqual(missing.state, .empty)
        XCTAssertNil(missing.backupURL)

        let id = UUID()
        let alarm = requireAlarm(Alarm.make(
            id: id,
            title: "开会",
            hour: 9,
            minute: 15,
            enabled: true,
            schedule: .once(CivilDate(year: 2026, month: 11, day: 20))
        ))
        var state = PersistedState.empty
        guard case .success(let added) = AlarmBook.adding(alarm, to: state) else {
            return XCTFail("添加失败")
        }
        state = added
        state.clock.showSeconds = true
        state.clock.hourCycle = .h24
        state.clock.localeChoice = .simplifiedChinese
        state.soundEnabled = false
        state.handled = [
            HandledOccurrence(
                key: "sample",
                alarmID: id,
                kind: .rang,
                handledAt: Date(timeIntervalSince1970: 1_763_361_600)
            )
        ]
        try store.save(state)
        let loaded = try AlarmStore(fileURL: url).load()
        XCTAssertEqual(loaded.state.alarms, state.alarms)
        XCTAssertEqual(loaded.state.clock, state.clock)
        XCTAssertEqual(loaded.state.soundEnabled, false)
        XCTAssertEqual(loaded.state.handled.map(\.key), ["sample"])
        XCTAssertEqual(loaded.state.handled.map(\.kind), [.rang])
        XCTAssertEqual(loaded.state.handled[0].handledAt.timeIntervalSince1970, 1_763_361_600, accuracy: 1)

        let json = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(json.contains("once"), json)
        XCTAssertTrue(json.contains("\"year\""), json)
        XCTAssertTrue(json.contains("\"month\""), json)
        XCTAssertTrue(json.contains("\"day\""), json)

        guard case .success(let edited) = Alarm.make(
            id: id,
            title: "改期",
            hour: 10,
            minute: 0,
            enabled: false,
            schedule: .daily
        ) else {
            return XCTFail("编辑失败")
        }
        guard case .success(let updated) = AlarmBook.updating(edited, in: loaded.state) else {
            return XCTFail("更新失败")
        }
        XCTAssertEqual(updated.alarms[0].title, "改期")
        XCTAssertEqual(updated.alarms[0].schedule, .daily)
        XCTAssertFalse(updated.alarms[0].enabled)
        let toggled: PersistedState
        guard case .success(let toggledState) = AlarmBook.toggling(id: id, in: updated) else {
            return XCTFail("切换失败")
        }
        toggled = toggledState
        XCTAssertTrue(toggled.alarms[0].enabled)
        let deleted = AlarmBook.deleting(id: id, from: toggled)
        XCTAssertTrue(deleted.alarms.isEmpty)
        XCTAssertTrue(deleted.handled.isEmpty)

        try store.save(state)
        var text = try String(contentsOf: url, encoding: .utf8)
        if let range = text.range(of: "\"schemaVersion\" : 1") {
            text.replaceSubrange(range, with: "\"schemaVersion\" : 99")
        } else if let range = text.range(of: "\"schemaVersion\": 1") {
            text.replaceSubrange(range, with: "\"schemaVersion\": 99")
        } else {
            return XCTFail("找不到 schemaVersion：\(text)")
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        let badSchema = try store.load()
        XCTAssertEqual(badSchema.state, .empty)
        XCTAssertNotNil(badSchema.backupURL)
        if let backup = badSchema.backupURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
            XCTAssertTrue(backup.lastPathComponent.hasPrefix("state.bad-"))
        }

        try Data("not-json".utf8).write(to: url)
        let garbage = try store.load()
        XCTAssertEqual(garbage.state, .empty)
        XCTAssertNotNil(garbage.backupURL)
    }

    func testAlarmCap() {
        var state = PersistedState.empty
        for index in 0..<AlarmBook.maximumCount {
            let alarm = requireAlarm(Alarm.make(title: "\(index)", hour: 1, minute: 0, enabled: true, schedule: .daily))
            guard case .success(let next) = AlarmBook.adding(alarm, to: state) else {
                return XCTFail("第 \(index) 个应能添加")
            }
            state = next
        }
        let extra = requireAlarm(Alarm.make(title: "多", hour: 2, minute: 0, enabled: true, schedule: .daily))
        guard case .failure(let error) = AlarmBook.adding(extra, to: state) else {
            return XCTFail("超过上限应失败")
        }
        XCTAssertEqual(error, .tooMany)
    }

    func testPruneDropsOldHandledRecords() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recent = HandledOccurrence(key: "new", alarmID: UUID(), kind: .rang, handledAt: now)
        let old = HandledOccurrence(
            key: "old",
            alarmID: UUID(),
            kind: .expiredSilent,
            handledAt: now.addingTimeInterval(-(policy.handledRetention + 5))
        )
        let pruned = AlarmScheduling.prune([recent, old], now: now, policy: policy)
        XCTAssertEqual(pruned.map(\.key), ["new"])
    }

    private func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = formatter.date(from: text) else {
            XCTFail("无法解析 \(text)")
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }

    private func beijing(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        guard let date = BeijingTime.date(CivilDate(year: year, month: month, day: day), hour: hour, minute: minute) else {
            XCTFail("无法构造北京时间")
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }

    private func requireAlarm(_ result: Result<Alarm, AlarmValidationError>, file: StaticString = #filePath, line: UInt = #line) -> Alarm {
        switch result {
        case .success(let alarm):
            return alarm
        case .failure(let error):
            XCTFail("\(error)", file: file, line: line)
            return Alarm(id: UUID(), title: "", hour: 0, minute: 0, enabled: false, schedule: .daily)
        }
    }

    private func temporaryStateURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("jingshi-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("state.json")
    }
}
