import AppKit
import UserNotifications
import BeijingTimeCore

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private var syncing = false
    private let previewLabel = NSTextField(labelWithString: "")
    private let dateCheck = NSButton(checkboxWithTitle: "显示日期", target: nil, action: nil)
    private let weekdayCheck = NSButton(checkboxWithTitle: "显示星期", target: nil, action: nil)
    private let secondsCheck = NSButton(checkboxWithTitle: "显示秒", target: nil, action: nil)
    private let flashCheck = NSButton(checkboxWithTitle: "闪烁分隔符（近似，不能与系统时钟同步）", target: nil, action: nil)
    private let markCheck = NSButton(checkboxWithTitle: "状态栏末尾显示「北京」", target: nil, action: nil)
    private let soundCheck = NSButton(checkboxWithTitle: "播放系统提示音", target: nil, action: nil)
    private let customFontCheck = NSButton(checkboxWithTitle: "自定字号（仍用菜单栏字体，限制在菜单栏高度内）", target: nil, action: nil)
    private let hourPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let localePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fontSlider = NSSlider(value: 13, minValue: 10, maxValue: 14, target: nil, action: nil)
    private let fontValue = NSTextField(labelWithString: "13")
    private let notificationLabel = NSTextField(wrappingLabelWithString: "通知：尚未请求")
    private let alarmDocument = TopDownView()
    private let alarmScroll = NSScrollView()
    private let editor: AlarmEditorController
    private let settingsScroll = NSScrollView()
    private var settingsStack: NSStackView?
    private var documentHeight: NSLayoutConstraint?

    init(model: AppModel) {
        self.model = model
        editor = AlarmEditorController(model: model)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "京时"
        window.minSize = NSSize(width: 520, height: 560)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        wireControls()
        buildLayout()
        editor.onSaved = { [weak self] in
            self?.reloadAlarms()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        syncControls()
        reloadAlarms()
        refreshNotificationStatus()
        window?.center()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            self?.updateSettingsDocumentHeight()
        }
    }

    func beginAdd() {
        show()
        editor.beginAdd(relativeTo: window)
    }

    func refreshIfVisible() {
        guard window?.isVisible == true else { return }
        syncControls()
        reloadAlarms()
    }

    func refreshPreviewIfVisible() {
        guard window?.isVisible == true else { return }
        previewLabel.stringValue = menuBarPreview(model.state.clock)
    }

    private func wireControls() {
        let checks = [dateCheck, weekdayCheck, secondsCheck, flashCheck, markCheck, soundCheck, customFontCheck]
        for check in checks {
            check.target = self
            check.action = #selector(optionChanged(_:))
        }
        hourPopup.target = self
        hourPopup.action = #selector(optionChanged(_:))
        localePopup.target = self
        localePopup.action = #selector(optionChanged(_:))
        fontSlider.target = self
        fontSlider.action = #selector(optionChanged(_:))
        fontSlider.isContinuous = false
        hourPopup.addItems(withTitles: ["跟随语言区域", "12 小时", "24 小时"])
        localePopup.addItems(withTitles: ["跟随系统", "简体中文"])
        notificationLabel.preferredMaxLayoutWidth = 500
        notificationLabel.maximumNumberOfLines = 3
        previewLabel.font = NSFont.menuBarFont(ofSize: 0)
    }

    private func buildLayout() {
        guard let content = window?.contentView else { return }
        let limit = NSTextField(wrappingLabelWithString: limitationText())
        limit.preferredMaxLayoutWidth = 510
        limit.maximumNumberOfLines = 14
        limit.textColor = .secondaryLabelColor
        limit.font = NSFont.systemFont(ofSize: 12)

        let clockHeading = heading("菜单栏显示")
        let hourRow = labeled("小时制", hourPopup)
        let localeRow = labeled("文字", localePopup)
        let fontRow = NSStackView(views: [fontSlider, fontValue])
        fontRow.orientation = .horizontal
        fontRow.spacing = 8
        fontSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let notifyHeading = heading("通知与声音")
        let request = NSButton(title: "请求通知权限", target: self, action: #selector(requestNotifications))
        notificationLabel.font = NSFont.systemFont(ofSize: 12)

        let alarmHeading = heading("闹钟（北京时间）")
        let add = NSButton(title: "新增闹钟", target: self, action: #selector(addAlarm))
        let quit = NSButton(title: "退出", target: self, action: #selector(quit))
        let alarmButtons = NSStackView(views: [add, quit])
        alarmButtons.orientation = .horizontal
        alarmButtons.spacing = 8

        alarmScroll.translatesAutoresizingMaskIntoConstraints = false
        alarmScroll.hasVerticalScroller = true
        alarmScroll.drawsBackground = false
        alarmScroll.borderType = .bezelBorder
        alarmScroll.documentView = alarmDocument
        alarmScroll.heightAnchor.constraint(equalToConstant: 180).isActive = true

        let policy = NSTextField(wrappingLabelWithString: policyText())
        policy.preferredMaxLayoutWidth = 510
        policy.maximumNumberOfLines = 5
        policy.textColor = .secondaryLabelColor
        policy.font = NSFont.systemFont(ofSize: 12)

        let widgetHeading = heading("桌面小组件")
        let widgetNote = NSTextField(wrappingLabelWithString: widgetText())
        widgetNote.preferredMaxLayoutWidth = 510
        widgetNote.maximumNumberOfLines = 8
        widgetNote.textColor = .secondaryLabelColor
        widgetNote.font = NSFont.systemFont(ofSize: 12)

        let stack = NSStackView(views: [
            limit,
            widgetHeading,
            widgetNote,
            clockHeading,
            previewLabel,
            dateCheck,
            weekdayCheck,
            secondsCheck,
            hourRow,
            localeRow,
            flashCheck,
            markCheck,
            customFontCheck,
            fontRow,
            notifyHeading,
            soundCheck,
            notificationLabel,
            request,
            alarmHeading,
            alarmScroll,
            alarmButtons,
            policy
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        settingsStack = stack
        settingsScroll.translatesAutoresizingMaskIntoConstraints = false
        settingsScroll.hasVerticalScroller = true
        settingsScroll.drawsBackground = false
        settingsScroll.documentView = stack
        content.addSubview(settingsScroll)
        let height = stack.heightAnchor.constraint(equalToConstant: 1560)
        documentHeight = height
        NSLayoutConstraint.activate([
            settingsScroll.topAnchor.constraint(equalTo: content.topAnchor),
            settingsScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            settingsScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            settingsScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.topAnchor.constraint(equalTo: settingsScroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: settingsScroll.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: settingsScroll.contentView.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: settingsScroll.contentView.widthAnchor),
            height,
            alarmScroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36)
        ])
    }

    private func heading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func labeled(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    private func limitationText() -> String {
        "如果菜单栏里看不到「京时」，通常是 macOS 没有空位，或系统把这项藏起来了。这个窗口不依赖菜单栏：这里有北京时间和闹钟。在 Finder 里再次打开本应用，也会把窗口带到前面。普通菜单栏应用不能保证排在系统时间右边，也无法自动读取所有系统时钟显示偏好；下面的选项由你自己设置，位置以 macOS 允许为准。可按住 Command 拖动本项，但不保证能放到系统时钟右侧，也不保证与系统时钟像素完全一致。本应用必须保持运行，且 Mac 处于唤醒状态，才会刷新时间和响铃；不能保证从睡眠中唤醒电脑，也不会修改开机启动或睡眠设置。"
    }

    private func widgetText() -> String {
        "macOS 14 及以上可以把「京时双环」放到桌面或通知中心。它是同一个圆盘上的内外同心环，共用一个圆心。表盘是 12 小时，12 在正上方；这一圈只表示北京的上午或下午，早 8 和晚 8 角度相同。内圈默认洛杉矶。时区在系统的小组件编辑里选择，记在这个小组件上，不写入闹钟，也不改系统时区。刷新按系统预算，大约 15 分钟，不是每秒。现有 1.0.1 预编译 zip 不含小组件。图库是否列出，取决于系统是否接受扩展签名。"
    }

    private func policyText() -> String {
        let catchUp = Int(AlarmPolicy.standard.catchUp / 60)
        let missed = Int(AlarmPolicy.standard.missedNotice / 3600)
        return "补响：迟到不超过 \(catchUp) 分钟仍会响铃。错过：超过 \(catchUp) 分钟、不满 \(missed) 小时只提示一次，不循环响铃。更早的不再提醒。单次闹钟在响铃、错过或过期后关闭。同一时刻即使刷新或重启也只处理一次。每天的闹钟按北京日期换日。时间编辑一律是北京时间。"
    }

    private func syncControls() {
        syncing = true
        defer { syncing = false }
        let clock = model.state.clock
        dateCheck.state = clock.showDate ? .on : .off
        weekdayCheck.state = clock.showWeekday ? .on : .off
        secondsCheck.state = clock.showSeconds ? .on : .off
        flashCheck.state = clock.flashSeparators ? .on : .off
        markCheck.state = clock.showBeijingMark ? .on : .off
        soundCheck.state = model.state.soundEnabled ? .on : .off
        switch clock.hourCycle {
        case .followLocale: hourPopup.selectItem(at: 0)
        case .h12: hourPopup.selectItem(at: 1)
        case .h24: hourPopup.selectItem(at: 2)
        }
        localePopup.selectItem(at: clock.localeChoice == .simplifiedChinese ? 1 : 0)
        let custom = clock.customFontSize
        customFontCheck.state = custom == nil ? .off : .on
        fontSlider.isEnabled = custom != nil
        let size = custom ?? 13
        fontSlider.doubleValue = size
        fontValue.stringValue = String(format: "%.0f", size)
        previewLabel.stringValue = menuBarPreview(clock)
    }

    private func menuBarPreview(_ clock: ClockDisplayOptions) -> String {
        "预览  " + ClockFormatter.menuBarString(at: Date(), options: clock)
    }

    @objc private func optionChanged(_ sender: Any?) {
        guard !syncing else { return }
        model.updateClock { clock in
            clock.showDate = dateCheck.state == .on
            clock.showWeekday = weekdayCheck.state == .on
            clock.showSeconds = secondsCheck.state == .on
            clock.flashSeparators = flashCheck.state == .on
            clock.showBeijingMark = markCheck.state == .on
            switch hourPopup.indexOfSelectedItem {
            case 1: clock.hourCycle = .h12
            case 2: clock.hourCycle = .h24
            default: clock.hourCycle = .followLocale
            }
            clock.localeChoice = localePopup.indexOfSelectedItem == 1 ? .simplifiedChinese : .system
            if customFontCheck.state == .on {
                clock.customFontSize = fontSlider.doubleValue
            } else {
                clock.customFontSize = nil
            }
        }
        model.setSoundEnabled(soundCheck.state == .on)
        syncControls()
    }

    @objc private func requestNotifications() {
        LocalNotifications.request { [weak self] status in
            self?.apply(notification: status)
        }
    }

    private func refreshNotificationStatus() {
        LocalNotifications.status { [weak self] status in
            self?.apply(notification: status)
        }
    }

    private func apply(notification status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            notificationLabel.stringValue = "通知：尚未请求。不授权也可以用应用内窗口和提示音。"
        case .authorized, .provisional, .ephemeral:
            notificationLabel.stringValue = "通知：已允许。通知是额外的视觉提示，循环提示音仍在应用窗口里。"
        case .denied:
            notificationLabel.stringValue = "通知：系统未允许。闹钟仍会在应用内显示。可在「系统设置 → 通知」中打开。本应用不会修改系统设置。"
        @unknown default:
            notificationLabel.stringValue = "通知：状态未知。闹钟仍会在应用内显示。"
        }
    }

    @objc private func addAlarm() {
        editor.beginAdd(relativeTo: window)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func windowDidResize(_ notification: Notification) {
        updateSettingsDocumentHeight()
        layoutAlarmRows(alarmDocument.subviews.compactMap { $0 as? AlarmRowView })
    }

    private func updateSettingsDocumentHeight() {
        guard let stack = settingsStack, let documentHeight else { return }
        stack.layoutSubtreeIfNeeded()
        let height = max(stack.fittingSize.height, 900)
        if abs(documentHeight.constant - height) > 2 {
            documentHeight.constant = height
        }
    }

    private func reloadAlarms() {
        alarmDocument.subviews.forEach { $0.removeFromSuperview() }
        let rows: [AlarmRowView] = model.state.alarms.map { alarm in
            let row = AlarmRowView(alarm: alarm)
            row.toggleButton.target = self
            row.toggleButton.action = #selector(toggleAlarm(_:))
            row.editButton.target = self
            row.editButton.action = #selector(editAlarm(_:))
            row.deleteButton.target = self
            row.deleteButton.action = #selector(deleteAlarm(_:))
            alarmDocument.addSubview(row)
            return row
        }
        if rows.isEmpty {
            let empty = NSTextField(labelWithString: "还没有闹钟。")
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: 8, y: 8, width: 240, height: 20)
            alarmDocument.addSubview(empty)
            alarmDocument.frame = NSRect(x: 0, y: 0, width: 480, height: 36)
            return
        }
        layoutAlarmRows(rows)
    }

    private func layoutAlarmRows(_ rows: [AlarmRowView]) {
        let width = max(alarmScroll.contentSize.width, 460)
        let height: CGFloat = 44
        for (index, row) in rows.enumerated() {
            row.frame = NSRect(x: 0, y: CGFloat(index) * height, width: width, height: height)
        }
        alarmDocument.frame = NSRect(x: 0, y: 0, width: width, height: max(CGFloat(rows.count) * height, 1))
    }

    @objc private func toggleAlarm(_ sender: NSButton) {
        guard let id = (sender.superview as? AlarmRowView)?.alarmID else { return }
        _ = model.toggle(id: id)
    }

    @objc private func editAlarm(_ sender: NSButton) {
        guard let id = (sender.superview as? AlarmRowView)?.alarmID,
              let alarm = model.alarm(id: id) else { return }
        editor.beginEdit(alarm, relativeTo: window)
    }

    @objc private func deleteAlarm(_ sender: NSButton) {
        guard let id = (sender.superview as? AlarmRowView)?.alarmID else { return }
        model.delete(id: id)
        reloadAlarms()
    }
}

final class TopDownView: NSView {
    override var isFlipped: Bool { true }
}

final class AlarmRowView: NSView {
    let alarmID: UUID
    let toggleButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let editButton = NSButton(title: "编辑", target: nil, action: nil)
    let deleteButton = NSButton(title: "删除", target: nil, action: nil)
    private let titleLabel: NSTextField

    init(alarm: Alarm) {
        alarmID = alarm.id
        titleLabel = NSTextField(labelWithString: AlarmRowView.describe(alarm))
        super.init(frame: NSRect(x: 0, y: 0, width: 480, height: 44))
        toggleButton.state = alarm.enabled ? .on : .off
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = NSFont.systemFont(ofSize: 13)
        for view in [toggleButton, titleLabel, editButton, deleteButton] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            toggleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: toggleButton.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -8),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
            editButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func describe(_ alarm: Alarm) -> String {
        let time = BeijingTime.hourMinute(hour: alarm.hour, minute: alarm.minute)
        switch alarm.schedule {
        case .daily:
            return "\(time) · 每天 · \(alarm.title)"
        case .once(let date):
            return "\(BeijingTime.monthDay(date)) \(time) · 仅一次 · \(alarm.title)"
        }
    }
}

final class AlarmEditorController: NSWindowController {
    var onSaved: (() -> Void)?
    private let model: AppModel
    private var editingID: UUID?
    private let titleField = NSTextField(string: "")
    private let hourPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let minutePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let schedulePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let yearPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let monthPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let dayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let enabledCheck = NSButton(checkboxWithTitle: "启用", target: nil, action: nil)
    private let dateRow = NSStackView()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "闹钟（北京时间）"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func beginAdd(relativeTo parent: NSWindow?) {
        editingID = nil
        let parts = BeijingTime.parts(Date())
        fill(title: "", hour: parts.hour, minute: parts.minute, enabled: true, schedule: .daily, date: parts.civilDate)
        present(relativeTo: parent)
    }

    func beginEdit(_ alarm: Alarm, relativeTo parent: NSWindow?) {
        editingID = alarm.id
        let date: CivilDate
        if case .once(let civil) = alarm.schedule {
            date = civil
        } else {
            date = BeijingTime.parts(Date()).civilDate
        }
        fill(title: alarm.title, hour: alarm.hour, minute: alarm.minute, enabled: alarm.enabled, schedule: alarm.schedule, date: date)
        present(relativeTo: parent)
    }

    private func present(relativeTo parent: NSWindow?) {
        errorLabel.stringValue = ""
        guard let window, let parent else {
            window?.center()
            window?.makeKeyAndOrderFront(nil)
            return
        }
        parent.beginSheet(window)
    }

    private func build() {
        guard let content = window?.contentView else { return }
        for hour in 0...23 {
            hourPopup.addItem(withTitle: String(format: "%02d", hour))
        }
        for minute in 0...59 {
            minutePopup.addItem(withTitle: String(format: "%02d", minute))
        }
        schedulePopup.addItems(withTitles: ["每天", "仅一次"])
        schedulePopup.target = self
        schedulePopup.action = #selector(scheduleChanged)
        for month in 1...12 {
            monthPopup.addItem(withTitle: "\(month) 月")
        }
        for day in 1...31 {
            dayPopup.addItem(withTitle: "\(day) 日")
        }
        titleField.placeholderString = "闹钟"
        errorLabel.textColor = .systemRed
        errorLabel.font = NSFont.systemFont(ofSize: 12)
        errorLabel.preferredMaxLayoutWidth = 400
        errorLabel.maximumNumberOfLines = 3

        let note = NSTextField(wrappingLabelWithString: "这里的日期和钟点都是北京时间（Asia/Shanghai），与系统时区无关。若时间已过，保存后会按补响或错过规则处理。")
        note.preferredMaxLayoutWidth = 400
        note.maximumNumberOfLines = 3
        note.textColor = .secondaryLabelColor
        note.font = NSFont.systemFont(ofSize: 12)

        let timeRow = NSStackView(views: [
            NSTextField(labelWithString: "时"),
            hourPopup,
            NSTextField(labelWithString: "分"),
            minutePopup,
            NSTextField(labelWithString: "北京时间")
        ])
        timeRow.orientation = .horizontal
        timeRow.spacing = 6
        timeRow.alignment = .centerY

        dateRow.orientation = .horizontal
        dateRow.spacing = 6
        dateRow.alignment = .centerY
        dateRow.addArrangedSubview(NSTextField(labelWithString: "日期"))
        dateRow.addArrangedSubview(yearPopup)
        dateRow.addArrangedSubview(monthPopup)
        dateRow.addArrangedSubview(dayPopup)

        let cancel = NSButton(title: "取消", target: self, action: #selector(cancel))
        let save = NSButton(title: "保存", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [cancel, save])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let stack = NSStackView(views: [
            note,
            NSTextField(labelWithString: "标题"),
            titleField,
            timeRow,
            NSTextField(labelWithString: "重复"),
            schedulePopup,
            dateRow,
            enabledCheck,
            errorLabel,
            buttons
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            titleField.widthAnchor.constraint(equalToConstant: 390)
        ])
    }

    private func fill(title: String, hour: Int, minute: Int, enabled: Bool, schedule: AlarmSchedule, date: CivilDate) {
        titleField.stringValue = title == "闹钟" ? "" : title
        hourPopup.selectItem(at: min(max(hour, 0), 23))
        minutePopup.selectItem(at: min(max(minute, 0), 59))
        enabledCheck.state = enabled ? .on : .off
        let nowYear = BeijingTime.parts(Date()).year
        var years = Array(nowYear...(nowYear + 2))
        if !years.contains(date.year) {
            years.append(date.year)
            years.sort()
        }
        yearPopup.removeAllItems()
        for year in years {
            yearPopup.addItem(withTitle: "\(year) 年")
            yearPopup.lastItem?.tag = year
        }
        if let index = years.firstIndex(of: date.year) {
            yearPopup.selectItem(at: index)
        }
        monthPopup.selectItem(at: min(max(date.month, 1), 12) - 1)
        dayPopup.selectItem(at: min(max(date.day, 1), 31) - 1)
        switch schedule {
        case .daily:
            schedulePopup.selectItem(at: 0)
        case .once:
            schedulePopup.selectItem(at: 1)
        }
        updateDateVisibility()
    }

    @objc private func scheduleChanged() {
        updateDateVisibility()
    }

    private func updateDateVisibility() {
        dateRow.isHidden = schedulePopup.indexOfSelectedItem == 0
    }

    @objc private func cancel() {
        closeSheet()
    }

    @objc private func save() {
        let hour = hourPopup.indexOfSelectedItem
        let minute = minutePopup.indexOfSelectedItem
        let schedule: AlarmSchedule
        if schedulePopup.indexOfSelectedItem == 1 {
            let year = yearPopup.selectedItem?.tag ?? BeijingTime.parts(Date()).year
            let month = monthPopup.indexOfSelectedItem + 1
            let day = dayPopup.indexOfSelectedItem + 1
            schedule = .once(CivilDate(year: year, month: month, day: day))
        } else {
            schedule = .daily
        }
        let made = Alarm.make(
            id: editingID ?? UUID(),
            title: titleField.stringValue,
            hour: hour,
            minute: minute,
            enabled: enabledCheck.state == .on,
            schedule: schedule
        )
        switch made {
        case .failure(let error):
            errorLabel.stringValue = message(for: error)
        case .success(let alarm):
            let result: Result<Void, AlarmBookError>
            if editingID == nil {
                result = model.add(alarm)
            } else {
                result = model.update(alarm)
            }
            switch result {
            case .success:
                closeSheet()
                onSaved?()
            case .failure(let error):
                errorLabel.stringValue = message(for: error)
            }
        }
    }

    private func closeSheet() {
        if let parent = window?.sheetParent {
            parent.endSheet(window!)
        } else {
            window?.orderOut(nil)
        }
    }

    private func message(for error: AlarmValidationError) -> String {
        switch error {
        case .invalidTime:
            return "时和分必须是 0–23 点、0–59 分。"
        case .invalidDate:
            return "这个公历日期不存在。请改用有效的北京日期。"
        }
    }

    private func message(for error: AlarmBookError) -> String {
        switch error {
        case .tooMany:
            return "最多只能保存 \(AlarmBook.maximumCount) 个闹钟。"
        case .missing:
            return "找不到这个闹钟，可能已经删除。"
        case .duplicateID:
            return "内部编号重复，请再保存一次。"
        }
    }
}
