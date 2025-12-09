import Foundation
import SwiftData

@Model
final class ReservationEntity {

    // 一意なID
    @Attribute(.unique) var id: UUID

    // 予約情報
    var note: String
    var startAt: Date
    var endAt: Date          // ★ 予約ごとの終了時刻（可変）
    var tableId: UUID

    // LO チェック状態
    var didDonabeLO: Bool      // 60分前（土鍋）
    var didFoodLO: Bool        // 30分前（食事）
    var didDrinkLO: Bool       // 15分前（飲み物）

    // 各 LO を実際に取った時刻（初めてチェックを ON にした瞬間）
    var donabeLOAt: Date?
    var foodLOAt: Date?
    var drinkLOAt: Date?

    // LO 延長（分）
    var extendMinutes: Int

    // 退店フラグ（退店後は true）
    var isCheckedOut: Bool

    /// - Parameters:
    ///   - note: メモ
    ///   - startAt: 入店時刻
    ///   - endAt: 終了時刻（指定しなければデフォルト2時間制）
    ///   - tableId: 卓ID
    ///   - extendMinutes: 延長分
    init(
        id: UUID = UUID(),
        note: String = "",
        startAt: Date,
        endAt: Date? = nil,
        tableId: UUID,
        didDonabeLO: Bool = false,
        didFoodLO: Bool = false,
        didDrinkLO: Bool = false,
        donabeLOAt: Date? = nil,
        foodLOAt: Date? = nil,
        drinkLOAt: Date? = nil,
        extendMinutes: Int = 0,
        isCheckedOut: Bool = false
    ) {
        self.id = id
        self.note = note
        self.startAt = startAt
        self.tableId = tableId
        self.didDonabeLO = didDonabeLO
        self.didFoodLO = didFoodLO
        self.didDrinkLO = didDrinkLO
        self.donabeLOAt = donabeLOAt
        self.foodLOAt = foodLOAt
        self.drinkLOAt = drinkLOAt
        self.extendMinutes = extendMinutes
        self.isCheckedOut = isCheckedOut

        // ★ デフォルトは2時間制（extendMinutesは別管理）
        if let endAt {
            self.endAt = endAt
        } else {
            self.endAt = LOScheduling.defaultEnd(from: startAt)
        }
    }
}
