// /Users/ciel/Documents/LOManager/LOManager/Services/NotificationService.swift

import Foundation
import UserNotifications

final class NotificationService {

    static let shared = NotificationService()

    private init() {}

    /// アプリ起動時などに呼んで、通知の許可をリクエスト
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("通知の許可リクエストに失敗: \(error)")
                return
            }
            print("通知の許可: \(granted ? "許可" : "拒否")")
        }
    }

    /// 単純なテスト通知（あとで消してもOK）
    func scheduleTestNotification(after seconds: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = "テスト通知"
        content.body = "これは LOManager からのテスト通知です。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("テスト通知のスケジュールに失敗: \(error)")
            }
        }
    }

    /// LO用のリマインド通知を予約（LOChecklistから呼べるようにしておく）
    func scheduleLOReminder(
        title: String,
        body: String,
        at date: Date,
        id: String = UUID().uuidString
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("LO通知のスケジュールに失敗: \(error)")
            }
        }
    }
}
