import Foundation

/// 启动时要不要打开普通窗口。菜单栏状态项是否看得见，不能代替这个窗口。
public enum LaunchTrigger: String, Equatable {
    /// 进程刚进入 applicationDidFinishLaunching。
    case processStart
    /// Finder 再次打开已在运行的应用（Apple Event rapp）。
    case reopen
}

public struct StatusItemSnapshot: Equatable {
    public var created: Bool
    public var visibleFlag: Bool
    public var hasButton: Bool
    public var titleCount: Int

    public init(created: Bool, visibleFlag: Bool, hasButton: Bool, titleCount: Int) {
        self.created = created
        self.visibleFlag = visibleFlag
        self.hasButton = hasButton
        self.titleCount = titleCount
    }
}

public enum AppLaunchPolicy {
    public static let marketingVersion = "1.0.1"

    /// 冷启动和 Finder 再次打开都打开窗口。
    /// `isVisible == true` 仍可能因为菜单栏没有空位而不在屏幕上，所以不能靠它省略窗口。
    public static func shouldOpenLauncherWindow(
        trigger: LaunchTrigger,
        statusItem: StatusItemSnapshot?
    ) -> Bool {
        switch trigger {
        case .processStart, .reopen:
            return true
        }
    }

    /// 菜单栏标题不能是空串，否则可变宽度的状态项宽度为 0，看起来像没创建。
    public static func menuBarTitle(formatted: String) -> String {
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "京时" : trimmed
    }
}
