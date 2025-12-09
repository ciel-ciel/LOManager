import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    @State private var selectedDate: Date = Date()
    @State private var now: Date = Date()                    // リロードで更新
    @State private var showingAddSheet = false
    @State private var selectedReservationForLO: ReservationEntity?
    @State private var selectedReservationForEdit: ReservationEntity?   // ★ 追加: 編集用

    @Query(sort: [SortDescriptor(\ReservationEntity.startAt, order: .forward)])
    private var allReservations: [ReservationEntity]

    @Query(sort: [SortDescriptor(\TableEntity.sortIndex, order: .forward)])
    private var tables: [TableEntity]

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "日付",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .padding()

                List {
                    ForEach(reservationsForSelectedDate, id: \.id) { r in
                        row(for: r)
                    }
                    .onDelete(perform: deleteReservations)
                }
            }
            .navigationTitle("予約一覧")
            .toolbar {
                // 左：リロードボタン
                ToolbarItem(placement: .topBarLeading) {
                    Button { now = Date() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                // 右：タイムライン画面へ
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        TimelineView(date: selectedDate)
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                // 右：予約追加ボタン（従来どおり）
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddReservationSheet(
                    date: selectedDate,
                    defaultStartAt: defaultStartTime(for: selectedDate),
                    selectedTableId: nil
                )
            }
            .sheet(item: $selectedReservationForLO) { r in
                LOChecklistSheet(reservation: r)
            }
           
        }
    }

    // MARK: - 行ビュー

    private func row(for r: ReservationEntity) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // 時間
                Text(timeText(for: r))
                    .font(.headline)

                // 卓名
                if let name = tableName(for: r.tableId) {
                    Text("卓：\(name)")
                }

                // メモ
                if !r.note.isEmpty {
                    Text(r.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // LO チェック状態バッジ（三つ）
                loCheckView(for: r)

                // LO フェーズ or 退店済みバッジ
                if r.isCheckedOut {
                    Text("退店済み")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.gray)
                        .clipShape(Capsule())
                } else {
                    let info = loPhaseDisplay(for: r)
                    Text(info.text)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(info.color.opacity(0.2))
                        .foregroundStyle(info.color)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // 右側に「編集」「LO確認」ボタン
            VStack(spacing: 4) {
                Button {
                    selectedReservationForEdit = r
                } label: {
                    Text("編集")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }

                Button {
                    selectedReservationForLO = r
                } label: {
                    Text("LO確認")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - LO チェック表示

    /// 「土 / 食 / 飲」 どこまで取れているかを表示
    private func loCheckView(for r: ReservationEntity) -> some View {
        HStack(spacing: 4) {
            loBadge(label: "土", isOn: r.didDonabeLO)
            loBadge(label: "食", isOn: r.didFoodLO)
            loBadge(label: "飲", isOn: r.didDrinkLO)
        }
    }

    /// 1 個分の小さいバッジ
    private func loBadge(label: String, isOn: Bool) -> some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isOn ? Color.green.opacity(0.8) : Color.gray.opacity(0.2))
            .foregroundColor(isOn ? .white : .gray)
            .clipShape(Capsule())
    }

    // MARK: - データ計算

    private var reservationsForSelectedDate: [ReservationEntity] {
        let cal = Calendar.current
        return allReservations.filter {
            cal.isDate($0.startAt, inSameDayAs: selectedDate)
        }
    }

    private func defaultStartTime(for date: Date) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        c.hour = 18
        c.minute = 0
        return Calendar.current.date(from: c) ?? date
    }

    private func timeText(for r: ReservationEntity) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return "\(f.string(from: r.startAt))〜\(f.string(from: r.endAt))"
    }

    private func tableName(for id: UUID) -> String? {
        tables.first(where: { $0.id == id })?.name
    }

    private func deleteReservations(at offsets: IndexSet) {
        for i in offsets {
            let r = reservationsForSelectedDate[i]
            context.delete(r)
        }
        try? context.save()
    }

    /// LO の表示テキストと色（時間ベース）
    private func loPhaseDisplay(for r: ReservationEntity) -> (text: String, color: Color) {
        let phase = LOScheduling.loPhase(
            endAt: r.endAt,
            extendMinutes: r.extendMinutes,
            now: now
        )

        switch phase {
        case .normal:  return ("余裕あり",         .green)
        case .warn60:  return ("60分前（土鍋）",   .blue)
        case .warn30:  return ("30分前（食事）",   .orange)
        case .warn15:  return ("15分前（飲み物）", .red)
        case .passed:  return ("終了",             .gray)
        }
    }
}
