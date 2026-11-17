import AppKit
import BeijingTimeCore

/// 应用内闹钟窗口。提示音最多响 60 秒，可随时停止。错过的发生不循环响铃。
final class AlarmAlertController: NSObject, NSWindowDelegate {
    static let maximumRingSeconds: TimeInterval = 60

    private var panel: NSPanel?
    private var bodyLabel: NSTextField?
    private var actionButton: NSButton?
    private var sound: NSSound?
    private var stopTimer: Timer?

    func present(rings: [DueAlarm], missed: [DueAlarm], soundEnabled: Bool) {
        let shouldRing = !rings.isEmpty
        ensurePanel()
        bodyLabel?.stringValue = message(rings: rings, missed: missed)
        actionButton?.title = shouldRing ? "停止" : "知道了"
        panel?.title = shouldRing ? "闹钟" : "错过的闹钟"
        if shouldRing {
            startSound(enabled: soundEnabled)
        } else {
            stopSound()
        }
        show()
    }

    private func message(rings: [DueAlarm], missed: [DueAlarm]) -> String {
        var lines: [String] = []
        if !rings.isEmpty {
            if !missed.isEmpty { lines.append("正在响铃") }
            lines.append(contentsOf: rings.map(line))
            lines.append("提示音最长 \(Int(Self.maximumRingSeconds)) 秒，可随时停止。")
        }
        if !missed.isEmpty {
            if !rings.isEmpty { lines.append("") ; lines.append("已错过") }
            lines.append(contentsOf: missed.map(line))
            let minutes = Int(AlarmPolicy.standard.catchUp / 60)
            lines.append("已超过 \(minutes) 分钟补响时间，不再循环响铃。")
        }
        return lines.joined(separator: "\n")
    }

    private func line(_ item: DueAlarm) -> String {
        let time = BeijingTime.hourMinute(hour: item.occurrence.hour, minute: item.occurrence.minute)
        let day = BeijingTime.monthDay(item.occurrence.civilDate)
        return "\(item.alarm.title)\n原定北京时间 \(day) \(time)"
    }

    private func ensurePanel() {
        if panel != nil { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "闹钟"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let heading = NSTextField(labelWithString: "北京时间")
        heading.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: "")
        body.font = NSFont.systemFont(ofSize: 15)
        body.preferredMaxLayoutWidth = 360
        body.maximumNumberOfLines = 14
        bodyLabel = body

        let button = NSButton(title: "停止", target: self, action: #selector(stop(_:)))
        button.keyEquivalent = "\r"
        actionButton = button

        let stack = NSStackView(views: [heading, body, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(stack)
        if let content = panel.contentView {
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
                body.widthAnchor.constraint(equalToConstant: 360)
            ])
        }
        self.panel = panel
    }

    private func show() {
        guard let panel else { return }
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func startSound(enabled: Bool) {
        stopSound()
        guard enabled else { return }
        let sound = NSSound(named: NSSound.Name("Glass")) ?? NSSound(named: NSSound.Name("Ping"))
        guard let sound else { return }
        sound.loops = true
        sound.play()
        self.sound = sound
        stopTimer = Timer.scheduledTimer(withTimeInterval: Self.maximumRingSeconds, repeats: false) { [weak self] _ in
            self?.stopSound()
        }
    }

    private func stopSound() {
        stopTimer?.invalidate()
        stopTimer = nil
        sound?.stop()
        sound = nil
    }

    @objc private func stop(_ sender: Any?) {
        stopSound()
        panel?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        stopSound()
    }
}
