import AppKit
import BeijingTimeCore

/// 菜单栏项由本对象强持有。公开 API 不能指定它相对系统时钟的位置。
/// 不设置 autosaveName，避免系统把「已隐藏」恢复回来后，再次启动仍然没有图标。
/// 也不写入 Preferred Position，不使用私有优先级 API。
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let settings: SettingsWindowController
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let popoverController: PopoverViewController

    init(model: AppModel, settings: SettingsWindowController) {
        self.model = model
        self.settings = settings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popoverController = PopoverViewController()
        super.init()
        popover.contentViewController = popoverController
        popover.behavior = .transient
        popover.delegate = self
        popoverController.onSettings = { [weak self] in
            self?.closePopover()
            self?.settings.show()
        }
        popoverController.onAdd = { [weak self] in
            self?.closePopover()
            self?.settings.show()
            self?.settings.beginAdd()
        }
        popoverController.onQuit = {
            NSApp.terminate(nil)
        }
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.setAccessibilityLabel("京时，北京时间")
        }
        statusItem.isVisible = true
        refresh()
    }

    func snapshot() -> StatusItemSnapshot {
        let button = statusItem.button
        let plain = button?.title ?? ""
        let attributed = button?.attributedTitle.string ?? ""
        return StatusItemSnapshot(
            created: true,
            visibleFlag: statusItem.isVisible,
            hasButton: button != nil,
            titleCount: max(plain.count, attributed.count)
        )
    }

    func refresh() {
        guard let button = statusItem.button else { return }
        let now = Date()
        let second = BeijingTime.parts(now).second
        let options = model.state.clock
        let visible = !options.flashSeparators || second % 2 == 0
        let formatted = ClockFormatter.menuBarString(at: now, options: options, separatorsVisible: visible)
        let text = AppLaunchPolicy.menuBarTitle(formatted: formatted)
        if let custom = options.customFontSize {
            let font = fittedFont(custom)
            button.attributedTitle = NSAttributedString(string: text, attributes: [.font: font])
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.font = nil
            button.title = text
        }
    }

    func refreshPopoverClock() {
        guard popover.isShown else { return }
        popoverController.update(state: model.state, now: Date())
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popoverController.update(state: model.state, now: Date())
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
    }

    private func closePopover() {
        popover.performClose(nil)
        statusItem.button?.highlight(false)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    private func fittedFont(_ custom: Double) -> NSFont {
        let clamped = MenuBarMetrics.clampedFontSize(custom)
        let thickness = Double(NSStatusBar.system.thickness)
        let maxByBar = max(MenuBarMetrics.customFontSizeBounds.lowerBound, thickness - 8)
        let size = min(clamped, maxByBar)
        return NSFont.menuBarFont(ofSize: CGFloat(size))
    }
}

final class PopoverViewController: NSViewController {
    var onSettings: (() -> Void)?
    var onAdd: (() -> Void)?
    var onQuit: (() -> Void)?

    private let timeLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let upcomingStack = NSStackView()
    private var upcomingSignature = ""

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 520))
        view = root
        preferredContentSize = NSSize(width: 360, height: 520)

        let title = NSTextField(labelWithString: "北京时间")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let zone = NSTextField(labelWithString: "Asia/Shanghai")
        zone.font = NSFont.systemFont(ofSize: 11)
        zone.textColor = .secondaryLabelColor

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 40, weight: .medium)
        timeLabel.alignment = .center
        dateLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        dateLabel.alignment = .center

        let heading = NSTextField(labelWithString: "即将到来")
        heading.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        heading.textColor = .secondaryLabelColor

        upcomingStack.orientation = .vertical
        upcomingStack.alignment = .leading
        upcomingStack.spacing = 6

        let settings = NSButton(title: "设置…", target: self, action: #selector(openSettings))
        let add = NSButton(title: "新增闹钟", target: self, action: #selector(addAlarm))
        let quit = NSButton(title: "退出", target: self, action: #selector(quit))
        let buttons = NSStackView(views: [settings, add, quit])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let note = NSTextField(wrappingLabelWithString: "位置由 macOS 决定，不能保证在系统时间右边。可按住 Command 拖动（以系统允许为准）。需要本应用保持运行，且 Mac 处于唤醒状态，才会刷新和响铃。")
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = 328

        let stack = NSStackView(views: [title, zone, timeLabel, dateLabel, heading, upcomingStack, buttons, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
            timeLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            dateLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32)
        ])
    }

    func update(state: PersistedState, now: Date) {
        timeLabel.stringValue = ClockFormatter.popoverTime(at: now)
        dateLabel.stringValue = ClockFormatter.popoverDate(at: now)
        timeLabel.setAccessibilityLabel("北京时间 \(timeLabel.stringValue)")
        let keys = Set(state.handled.map(\.key))
        let upcoming = AlarmScheduling.upcoming(alarms: state.alarms, now: now, handledKeys: keys)
        let signature = upcoming.items.map(\.summary).joined(separator: "\n") + "#\(upcoming.hidden)"
        guard signature != upcomingSignature else { return }
        upcomingSignature = signature
        upcomingStack.arrangedSubviews.forEach { view in
            upcomingStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        if upcoming.items.isEmpty {
            let empty = NSTextField(labelWithString: "还没有即将到来的闹钟。")
            empty.textColor = .secondaryLabelColor
            upcomingStack.addArrangedSubview(empty)
        } else {
            for item in upcoming.items {
                let label = NSTextField(wrappingLabelWithString: item.summary)
                label.preferredMaxLayoutWidth = 328
                label.font = NSFont.systemFont(ofSize: 13)
                upcomingStack.addArrangedSubview(label)
            }
            if upcoming.hidden > 0 {
                let more = NSTextField(labelWithString: "还有 \(upcoming.hidden) 个，可在设置中查看。")
                more.textColor = .secondaryLabelColor
                more.font = NSFont.systemFont(ofSize: 12)
                upcomingStack.addArrangedSubview(more)
            }
        }
    }

    @objc private func openSettings() { onSettings?() }
    @objc private func addAlarm() { onAdd?() }
    @objc private func quit() { onQuit?() }
}
