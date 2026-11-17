import Foundation
import XCTest
@testable import BeijingTimeCore

final class LaunchAcceptanceTests: XCTestCase {
    func testLauncherWindowOpensOnStartAndReopenEvenWhenStatusItemLooksFine() {
        let visible = StatusItemSnapshot(created: true, visibleFlag: true, hasButton: true, titleCount: 8)
        XCTAssertTrue(AppLaunchPolicy.shouldOpenLauncherWindow(trigger: .processStart, statusItem: visible))
        XCTAssertTrue(AppLaunchPolicy.shouldOpenLauncherWindow(trigger: .reopen, statusItem: visible))
        XCTAssertTrue(AppLaunchPolicy.shouldOpenLauncherWindow(trigger: .processStart, statusItem: nil))
        let hidden = StatusItemSnapshot(created: true, visibleFlag: false, hasButton: false, titleCount: 0)
        XCTAssertTrue(AppLaunchPolicy.shouldOpenLauncherWindow(trigger: .reopen, statusItem: hidden))
    }

    func testEmptyMenuBarTitleDoesNotCollapseTheStatusItem() {
        XCTAssertEqual(AppLaunchPolicy.menuBarTitle(formatted: ""), "京时")
        XCTAssertEqual(AppLaunchPolicy.menuBarTitle(formatted: "   "), "京时")
        XCTAssertEqual(AppLaunchPolicy.menuBarTitle(formatted: "周二 08:30"), "周二 08:30")
    }

    func testMarketingVersionIs101() {
        XCTAssertEqual(AppLaunchPolicy.marketingVersion, "1.0.1")
    }

    func testStartupSourceDoesNotUseBareNSApplicationMain() throws {
        let root = packageRoot()
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/BeijingClock/AppDelegate.swift"), encoding: .utf8)
        let status = try String(contentsOf: root.appendingPathComponent("Sources/BeijingClock/StatusItemController.swift"), encoding: .utf8)
        let plist = try String(contentsOf: root.appendingPathComponent("Packaging/Info.plist"), encoding: .utf8)
        let log = try String(contentsOf: root.appendingPathComponent("Sources/BeijingClock/LifecycleLog.swift"), encoding: .utf8)

        XCTAssertTrue(appDelegate.contains("static func main()"))
        XCTAssertTrue(appDelegate.contains("retainedDelegate"))
        XCTAssertTrue(appDelegate.contains("app.delegate = delegate"))
        XCTAssertTrue(appDelegate.contains("app.run()"))
        XCTAssertTrue(appDelegate.contains("applicationShouldHandleReopen"))
        XCTAssertTrue(appDelegate.contains("presentLauncher(trigger: .processStart)"))
        XCTAssertTrue(appDelegate.contains("presentLauncher(trigger: .reopen)"))
        XCTAssertFalse(appDelegate.contains("NSApplicationMain("))
        XCTAssertFalse(appDelegate.contains("setActivationPolicy("))

        XCTAssertTrue(status.contains("private let statusItem"))
        XCTAssertTrue(status.contains("statusItem.isVisible = true"))
        XCTAssertFalse(status.contains("autosaveName ="))
        XCTAssertTrue(status.contains("AppLaunchPolicy.menuBarTitle"))

        XCTAssertTrue(plist.contains("<string>1.0.1</string>"))
        XCTAssertTrue(plist.contains("<key>LSUIElement</key>"))
        XCTAssertTrue(plist.contains("<true/>"))
        XCTAssertTrue(plist.contains("<key>NSPrincipalClass</key>"))
        XCTAssertTrue(plist.contains("<string>NSApplication</string>"))
        XCTAssertFalse(plist.contains("<key>NSMainNibFile</key>"))

        XCTAssertTrue(log.contains("import BeijingTimeCore"))
        XCTAssertTrue(log.contains("local.beijingclock.jingshi"))
        XCTAssertTrue(log.contains("did-finish-launching"))
        XCTAssertTrue(log.contains("status-item"))
        XCTAssertFalse(log.contains("NSHomeDirectory"))
        XCTAssertFalse(log.contains("alarm.title"))
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
