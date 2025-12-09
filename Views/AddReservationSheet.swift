import SwiftUI
import SwiftData

struct AddReservationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let date: Date
    let defaultStartAt: Date
    let selectedTableId: UUID?
    var onSaved: (ReservationEntity) -> Void = { _ in }

    // 入力
    @State private var startAt: Date
    @State private var note: String = ""
    @State private var tableIndex: Int = 0

    // ★ 利用時間（分）: デフォルト 120分（2時間）
    @State private var stayMinutes: Int = 120

    @Query(sort: [SortDescriptor(\TableEntity.sortIndex, order: .forward)])
    private var tables: [TableEntity]

    init(
        date: Date,
        defaultStartAt: Date,
        selectedTableId: UUID?,
        onSaved: @escaping (ReservationEntity) -> Void = { _ in }
    ) {
        self.date = date
        self.defaultStartAt = defaultStartAt
        self.selectedTableId = selectedTableId
        self.onSaved = onSaved

        _startAt = State(initialValue: defaultStartAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 卓選択
                Section("卓") {
                    if tables.isEmpty {
                        Text("卓が登録されていません")
                    } else {
                        Picker("卓を選択", selection: $tableIndex) {
                            ForEach(Array(tables.enumerated()), id: \.offset) { index, table in
                                Text(table.name).tag(index)
                            }
                        }
                    }
                }

                // 時間
                Section("時間") {
                    DatePicker(
                        "入店時間",
                        selection: $startAt,
                        displayedComponents: [.hourAndMinute]
                    )

                    Text("終了時間: \(endTimeText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // ★ 利用時間
                Section("利用時間") {
                    Stepper(
                        "利用時間 \(stayMinutes) 分",
                        value: $stayMinutes,
                        in: 30...120,
                        step: 15
                    )
                    Text("※ 退店後チェック")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // メモ
                Section("メモ") {
                    TextField("メモ（任意）", text: $note, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("予約を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveReservation() }
                        .disabled(tables.isEmpty)
                }
            }
            .onAppear { setInitialTable() }
        }
    }

    // MARK: - 初期卓選択

    private func setInitialTable() {
        if let tid = selectedTableId,
           let idx = tables.firstIndex(where: { $0.id == tid }) {
            tableIndex = idx
        }
    }

    // MARK: - 終了時間表示（利用時間ベース）

    private var endTimeText: String {
        let end = Calendar.current.date(byAdding: .minute, value: stayMinutes, to: startAt)
            ?? LOScheduling.defaultEnd(from: startAt)

        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f.string(from: end)
    }

    // MARK: - 保存

    private func saveReservation() {
        guard tables.indices.contains(tableIndex) else { return }

        let table = tables[tableIndex]

        // ★ 利用時間から終了時刻を計算
        let endAt = Calendar.current.date(byAdding: .minute, value: stayMinutes, to: startAt)
            ?? LOScheduling.defaultEnd(from: startAt)

        let item = ReservationEntity(
            note: note,
            startAt: startAt,
            endAt: endAt,
            tableId: table.id
        )

        context.insert(item)

        do {
            try context.save()
            onSaved(item)
            dismiss()
        } catch {
            print("保存に失敗: \(error)")
        }
    }
}
