import AppKit
import BeijingTimeCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// NSApplication.delegate 是弱引用。1.0.0 只进了 NSApplicationMain，没有创建这个对象。
    private static var retainedDelegate: AppDelegate?

    private var model: AppModel!
    private var statusController: StatusItemController!
    private var settingsController: SettingsWindowController!
    private var alertController: AlarmAlertController!
    private var timer: Timer?
    private var lastSaveError: String?

    /// 不用 NSApplicationMain。那个入口只看 Info.plist 的 NSPrincipalClass 和主 nib。
    /// 本包没有 nib，所以 1.0.0 的委托方法不会运行，菜单栏项也不会被创建。
    static func main() {
        LifecycleLog.mainEntered()
        let delegate = AppDelegate()
        retainedDelegate = delegate
        let app = NSApplication.shared
        app.delegate = delegate
        LifecycleLog.delegateAssigned(mainThread: Thread.isMainThread)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LifecycleLog.didFinishLaunching(mainThread: Thread.isMainThread)
        model = AppModel()
        alertController = AlarmAlertController()
        settingsController = SettingsWindowController(model: model)
        statusController = StatusItemController(model: model, settings: settingsController)

        model.onChange = { [weak self] in
            self?.statusController.refresh()
            self?.settingsController.refreshIfVisible()
        }
        model.onDue = { [weak self] rings, missed in
            guard let self else { return }
            self.alertController.present(
                rings: rings,
                missed: missed,
                soundEnabled: self.model.state.soundEnabled
            )
            LocalNotifications.post(rings: rings, missed: missed)
        }
        model.onSaveError = { [weak self] message in
            self?.presentSaveError(message)
        }

        if let backup = model.recoveredBackupURL {
            presentRecovery(backup: backup)
        }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(systemWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(systemWake(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)

        timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshClock()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        model.tick()
        refreshClock()
        let snapshot = statusController.snapshot()
        LifecycleLog.statusItem(
            created: snapshot.created,
            visible: snapshot.visibleFlag,
            hasButton: snapshot.hasButton,
            titleCount: snapshot.titleCount
        )
        presentLauncher(trigger: .processStart)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LifecycleLog.reopen(hasVisibleWindows: flag)
        presentLauncher(trigger: .reopen)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        model?.save()
    }

    @objc private func systemWake(_ notification: Notification) {
        model.tick()
        refreshClock()
    }

    private func refreshClock() {
        model.tick()
        statusController.refresh()
        statusController.refreshPopoverClock()
        settingsController.refreshPreviewIfVisible()
    }

    private func presentLauncher(trigger: LaunchTrigger) {
        guard settingsController != nil else { return }
        settingsController.show()
        LifecycleLog.launcherOrderedFront(trigger: trigger)
    }

    private func presentSaveError(_ message: String) {
        guard message != lastSaveError else { return }
        lastSaveError = message
        let alert = NSAlert()
        alert.messageText = "没能保存"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func presentRecovery(backup: URL) {
        let alert = NSAlert()
        alert.messageText = "无法读取已保存的数据"
        alert.informativeText = "损坏的文件已改名为备份，并从空白状态重新开始。备份：\(backup.path)"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
