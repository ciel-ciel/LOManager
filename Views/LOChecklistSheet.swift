import SwiftUI
import SwiftData

struct LOChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var loDonabe: Bool
    @State private var loFood: Bool
    @State private var loDrink: Bool
    @State private var extendMinutes: Int

    @State private var donabeLOAt: Date?
    @State private var foodLOAt: Date?
    @State private var drinkLOAt: Date?

    // ★ 手動退店フラグ
    @State private var isCheckedOut: Bool

    let reservation: ReservationEntity
    var onSaved: (ReservationEntity) -> Void = { _ in }

    init(
        reservation: ReservationEntity,
        onSaved: @escaping (ReservationEntity) -> Void = { _ in }
    ) {
        self.reservation = reservation
        self.onSaved = onSaved

        _loDonabe      = State(initialValue: reservation.didDonabeLO)
        _loFood        = State(initialValue: reservation.didFoodLO)
        _loDrink       = State(initialValue: reservation.didDrinkLO)
        _extendMinutes = State(initialValue: reservation.extendMinutes)

        _donabeLOAt = State(initialValue: reservation.donabeLOAt)
        _foodLOAt   = State(initialValue: reservation.foodLOAt)
        _drinkLOAt  = State(initialValue: reservation.drinkLOAt)

        _isCheckedOut = State(initialValue: reservation.isCheckedOut)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("LOチェック") {
                    Toggle("土鍋 LO 済（60分前）", isOn: $loDonabe)
                    Toggle("食事 LO 済（30分前）", isOn: $loFood)
                    Toggle("飲み物 LO 済（15分前）", isOn: $loDrink)

                    if let base = loBase {
                        if let t = donabeLOAt {
                            Text("土鍋LO: \(timeText(t))（\(offsetText(actual: t, scheduled: base.donabe))）")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let t = foodLOAt {
                            Text("食事LO: \(timeText(t))（\(offsetText(actual: t, scheduled: base.food))）")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let t = drinkLOAt {
                            Text("飲みLO: \(timeText(t))（\(offsetText(actual: t, scheduled: base.drink))）")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("延長") {
                    Stepper("延長 \(extendMinutes) 分",
                            value: $extendMinutes,
                            in: 0...180,
                            step: 5)

                    Text("退席目安: \(extendedEndTimeText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // ★ 退店は必ず手動
                Section("退店") {
                    Toggle("退店済みにする", isOn: $isCheckedOut)

                    Text("※ 時間が過ぎても自動で退店にはなりません。ここで手動で切り替えます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("メモ") {
                    Text(reservation.note.isEmpty ? "メモなし" : reservation.note)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("LOチェック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private var extendedEndTimeText: String {
        let base = reservation.endAt.addingTimeInterval(TimeInterval(extendMinutes * 60))
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f.string(from: base)
    }

    private var loBase: (donabe: Date, food: Date, drink: Date, endBase: Date)? {
        LOScheduling.loBaseTimes(
            endAt: reservation.endAt,
            extendMinutes: extendMinutes
        )
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func offsetText(actual: Date, scheduled: Date) -> String {
        let diffMin = Int(scheduled.timeIntervalSince(actual) / 60)

        if diffMin == 0 { return "予定ぴったり" }
        if diffMin > 0 { return "予定より \(diffMin) 分前" }
        return "予定より \(-diffMin) 分遅れ"
    }

    private func save() {
        let now = Date()

        if loDonabe {
            if donabeLOAt == nil { donabeLOAt = now }
        } else {
            donabeLOAt = nil
        }

        if loFood {
            if foodLOAt == nil { foodLOAt = now }
        } else {
            foodLOAt = nil
        }

        if loDrink {
            if drinkLOAt == nil { drinkLOAt = now }
        } else {
            drinkLOAt = nil
        }

        reservation.didDonabeLO = loDonabe
        reservation.didFoodLO   = loFood
        reservation.didDrinkLO  = loDrink
        reservation.extendMinutes = extendMinutes

        reservation.donabeLOAt = donabeLOAt
        reservation.foodLOAt   = foodLOAt
        reservation.drinkLOAt  = drinkLOAt

        // ★ 自動では絶対に変更しない
        reservation.isCheckedOut = isCheckedOut

        do { try context.save() }
        catch { print("LO 状態の保存に失敗: \(error)") }

        onSaved(reservation)
        dismiss()
    }
}

