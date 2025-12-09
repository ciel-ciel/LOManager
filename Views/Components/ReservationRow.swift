// /Users/ciel/Documents/LOManager/LOManager/Views/Components/ReservationRow.swift

import SwiftUI
import SwiftData

struct ReservationRow: View {
    let reservation: ReservationEntity

    // 卓マスタ（卓名表示用）
    @Query(sort: [SortDescriptor(\TableEntity.sortIndex, order: .forward)])
    private var tables: [TableEntity]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // 卓名
                Text(tableName ?? "卓不明")
                    .font(.headline)

                // 時間帯（開始〜終了・延長込み）
                Text(timeRangeText)
                    .font(.subheadline)

                // 次の LO まで何分 / 何分経過 など
                Text(loStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // メモ（あれば）
                if !reservation.note.isEmpty {
                    Text(reservation.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        // ★ LO 状況に応じて背景色を変更
        .listRowBackground(loBackgroundColor)
    }

    // MARK: - 卓名

    private var tableName: String? {
        tables.first(where: { $0.id == reservation.tableId })?.name
    }

    // MARK: - 時間帯テキスト（開始〜終了）

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"

        let start = formatter.string(from: reservation.startAt)

        let baseEnd = reservation.endAt
        let finalEnd = baseEnd.addingTimeInterval(TimeInterval(reservation.extendMinutes * 60))
        let end = formatter.string(from: finalEnd)

        return "\(start) 〜 \(end)"
    }

    // MARK: - LO 背景色（LO 状況ベース）

    /// LO 状況に応じた背景色
    /// - 土鍋 LO 済: 紫
    /// - 食事 LO 済: 赤
    /// - 飲み物 LO 済: 青
    /// - 退店: グレー
    /// - 何も LO 済でない: 透明
    private var loBackgroundColor: Color {
        if reservation.isCheckedOut {
            return Color.gray.opacity(0.2)
        } else if reservation.didDrinkLO {
            // 一番後ろの LO（飲み物）が済んでいれば青
            return Color.blue.opacity(0.2)
        } else if reservation.didFoodLO {
            return Color.red.opacity(0.2)
        } else if reservation.didDonabeLO {
            return Color.purple.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    // MARK: - LO 関連テキスト（時間ベース）

    /// 「次の LO まで何分 / 何分経過したか」のテキストを生成
    private var loStatusText: String {
        let now = Date()

        // 延長込みの最終退席目安
        let endBase = reservation.endAt.addingTimeInterval(TimeInterval(reservation.extendMinutes * 60))

        // LO 3 種（60 / 30 / 15 分前）
        let t60 = endBase.addingTimeInterval(-60 * 60)
        let t30 = endBase.addingTimeInterval(-30 * 60)
        let t15 = endBase.addingTimeInterval(-15 * 60)

        func minutes(_ interval: TimeInterval) -> Int {
            Int(interval / 60)
        }

        if now < t60 {
            // まだ 60 分前より前 → 土鍋 LO までの残り時間
            let remain = minutes(t60.timeIntervalSince(now))
            return "土鍋LOまであと \(remain) 分"
        } else if now < t30 {
            // 60〜30 分前 → 食事 LO まで
            let remain = minutes(t30.timeIntervalSince(now))
            return "食事LOまであと \(remain) 分"
        } else if now < t15 {
            // 30〜15 分前 → 飲み物 LO まで
            let remain = minutes(t15.timeIntervalSince(now))
            return "飲み物LOまであと \(remain) 分"
        } else if now < endBase {
            // 15 分前〜終了まで → 飲み物 LO からの経過時間
            let passed = minutes(now.timeIntervalSince(t15))
            return "飲み物LOから \(passed) 分経過"
        } else {
            // 終了時刻を過ぎた → 退席目安からの経過時間
            let passed = minutes(now.timeIntervalSince(endBase))
            return "退席目安時間から \(passed) 分経過"
        }
    }
}
