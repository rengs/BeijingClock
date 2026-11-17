import os
import BeijingTimeCore

/// 统一日志只记生命周期，不记路径、用户名、闹钟标题或时间字符串。
enum LifecycleLog {
    static let subsystem = "local.beijingclock.jingshi"
    private static let logger = Logger(subsystem: subsystem, category: "lifecycle")

    static func mainEntered() {
        logger.info("main-entered version=1.0.1")
    }

    static func delegateAssigned(mainThread: Bool) {
        logger.info("delegate-assigned mainThread=\(mainThread, privacy: .public)")
    }

    static func didFinishLaunching(mainThread: Bool) {
        logger.info("did-finish-launching mainThread=\(mainThread, privacy: .public)")
    }

    static func statusItem(created: Bool, visible: Bool, hasButton: Bool, titleCount: Int) {
        logger.info("status-item created=\(created, privacy: .public) visible=\(visible, privacy: .public) button=\(hasButton, privacy: .public) titleCount=\(titleCount, privacy: .public)")
    }

    static func launcherOrderedFront(trigger: LaunchTrigger) {
        logger.info("launcher-window trigger=\(trigger.rawValue, privacy: .public)")
    }

    static func reopen(hasVisibleWindows: Bool) {
        logger.info("reopen hasVisibleWindows=\(hasVisibleWindows, privacy: .public)")
    }
}
