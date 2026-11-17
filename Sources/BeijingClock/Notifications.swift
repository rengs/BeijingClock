import Foundation
import UserNotifications
import BeijingTimeCore

enum LocalNotifications {
    static func status(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    static func request(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in
            status(completion)
        }
    }

    /// 通知只做视觉提示。循环提示音由应用窗口播放，避免响两次。未授权时直接返回。
    static func post(rings: [DueAlarm], missed: [DueAlarm]) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            else {
                return
            }
            for item in rings.prefix(10) {
                add(
                    center,
                    title: "闹钟",
                    body: "\(item.alarm.title) · 北京时间 \(BeijingTime.hourMinute(hour: item.occurrence.hour, minute: item.occurrence.minute))"
                )
            }
            for item in missed.prefix(10) {
                add(
                    center,
                    title: "错过的闹钟",
                    body: "\(item.alarm.title) · 原定北京时间 \(BeijingTime.hourMinute(hour: item.occurrence.hour, minute: item.occurrence.minute))，已超过补响时间"
                )
            }
        }
    }

    private static func add(_ center: UNUserNotificationCenter, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }
}
