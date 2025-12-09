import Foundation

/// LO 関連の時間計算をまとめたヘルパー
struct LOScheduling {

    /// デフォルトの滞在時間（2時間制）
    static func defaultEnd(from startAt: Date) -> Date {
        startAt.addingTimeInterval(2 * 60 * 60)
    }

    /// LO フェーズを計算
    static func loPhase(
        endAt: Date,
        extendMinutes: Int,
        now: Date = Date()
    ) -> LOPhase {
        // 延長込みの最終退席目安
        let endBase = endAt.addingTimeInterval(TimeInterval(extendMinutes * 60))

        // LO 3 種（60 / 30 / 15 分前）
        let t60 = endBase.addingTimeInterval(-60 * 60)
        let t30 = endBase.addingTimeInterval(-30 * 60)
        let t15 = endBase.addingTimeInterval(-15 * 60)

        if now < t60 {
            return .normal
        } else if now < t30 {
            return .warn60
        } else if now < t15 {
            return .warn30
        } else if now < endBase {
            return .warn15
        } else {
            return .passed
        }
    }

    /// ★ 各 LO の予定時刻と退席目安時刻
    static func loBaseTimes(
        endAt: Date,
        extendMinutes: Int
    ) -> (donabe: Date, food: Date, drink: Date, endBase: Date) {
        let endBase = endAt.addingTimeInterval(TimeInterval(extendMinutes * 60))

        let donabe = endBase.addingTimeInterval(-60 * 60) // 60分前（土鍋 LO 予定）
        let food   = endBase.addingTimeInterval(-30 * 60) // 30分前（食事 LO 予定）
        let drink  = endBase.addingTimeInterval(-15 * 60) // 15分前（飲み物 LO 予定）

        return (donabe, food, drink, endBase)
    }
}

