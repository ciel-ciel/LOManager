import SwiftUI
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
#endif

/// 横軸=時間, 縦軸=卓 のタイムラインビュー（レストランボード風）
struct TimelineView: View {
    @Environment(\.modelContext) private var context

    private let initialDate: Date
    @State private var selectedDate: Date

    @Query(sort: [SortDescriptor(\TableEntity.sortIndex, order: .forward)])
    private var tables: [TableEntity]

    @Query(sort: [SortDescriptor(\ReservationEntity.startAt, order: .forward)])
    private var allReservations: [ReservationEntity]

    @State private var showingAddSheet = false
    @State private var selectedTableForAdd: TableEntity?
    @State private var selectedReservationForLO: ReservationEntity?

    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // ドラッグ中のバー見た目用
    @State private var draggingReservationId: UUID?
    @State private var dragOffsetX: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0

    // 誤操作防止：長押ししてからでないと席移動できない
    @State private var moveArmedReservationId: UUID?

    private let openHour = 17
    private let closeHour = 23
    private let hourWidth: CGFloat = 120

    // バーの太さ
    private let rowHeight: CGFloat = 56

    // 左の卓カラム幅
    private let leftColumnWidth: CGFloat = 80

    private enum NextLOKind {
        case donabe, food, drink
    }

    init() {
        let today = Date()
        self.initialDate = today
        _selectedDate = State(initialValue: today)
    }

    init(date: Date) {
        self.initialDate = date
        _selectedDate = State(initialValue: date)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemGray5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                DatePicker(
                    "日付",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)

                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)

                // 縦スクロールだけ外側に持たせる
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        // 左カラムは固定表示
                        leftColumn
                            .padding(.horizontal, 4)

                        // 右だけ横スクロール
                        ScrollView(.horizontal) {
                            rightTimeline
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.vertical, 2)

                    if tables.isEmpty {
                        Text("卓が登録されていません")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("タイムライン")
        .onReceive(timer) { value in
            now = value
        }
        .sheet(isPresented: $showingAddSheet) {
            if let table = selectedTableForAdd {
                AddReservationSheet(
                    date: selectedDate,
                    defaultStartAt: defaultStartTime(for: selectedDate),
                    selectedTableId: table.id
                )
            }
        }
        .sheet(item: $selectedReservationForLO) { r in
            LOChecklistSheet(reservation: r)
        }
    }

    // MARK: - 左カラム

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー左セル
            Text("卓 / 時間")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: leftColumnWidth, alignment: .leading)
                .padding(.bottom, 2)

            ForEach(tables, id: \.id) { table in
                leftRow(for: table)
                    .frame(width: leftColumnWidth, height: rowHeight, alignment: .leading)
                    .padding(.trailing, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTableForAdd = table
                        showingAddSheet = true
                    }
            }
        }
    }

    private func leftRow(for table: TableEntity) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(table.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Image(systemName: "plus.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("タップでこの卓に追加")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 右タイムライン

    private var rightTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerHoursRow
                .padding(.bottom, 2)

            ForEach(tables, id: \.id) { table in
                timelineBarsRow(for: table)
                    .padding(.vertical, 0)
            }
        }
    }

    private var headerHoursRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(openHour..<closeHour, id: \.self) { hour in
                VStack(spacing: 1) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: hourWidth, height: 1)
                }
            }
        }
    }

    private func timelineBarsRow(for table: TableEntity) -> some View {
        let tableReservations = reservationsForSelectedDate.filter { $0.tableId == table.id }

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                .frame(height: rowHeight)

            HStack(spacing: 0) {
                ForEach(openHour..<closeHour, id: \.self) { _ in
                    Rectangle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        .frame(width: hourWidth, height: rowHeight)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isNowInRange {
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 2, height: rowHeight + 4)
                    .offset(x: timeToPosition(now))
                    .shadow(radius: 1)
            }

            ForEach(tableReservations, id: \.id) { r in
                reservationBar(for: r)
                    .onTapGesture {
                        selectedReservationForLO = r
                    }
            }
        }
        .frame(width: timelineWidth, height: rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTableForAdd = table
            showingAddSheet = true
        }
    }

    // MARK: - 予約バー本体

    private func reservationBar(for r: ReservationEntity) -> some View {
        let startX = timeToPosition(r.startAt)
        let endX = timeToPosition(
            r.endAt.addingTimeInterval(TimeInterval(r.extendMinutes * 60))
        )
        let width = max(endX - startX, 32)

        let baseColor = loColor(for: r)
        let next = nextLOInfo(for: r)
        let last = lastLOInfo(for: r)

        let nextColor = next != nil ? colorForNextLO(kind: next!.kind) : Color.clear
        let isDragging = (draggingReservationId == r.id)

        let scale: CGFloat = isDragging ? 1.05 : 1.0
        let shadowRadius: CGFloat = isDragging ? 6 : 4
        let shadowOpacity: Double = isDragging ? 0.35 : 0.25

        return HStack(alignment: .top, spacing: 4) {
            Circle()
                .fill(nextColor)
                .frame(width: 10, height: 10)
                .opacity(next == nil ? 0.0 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeRangeText(for: r))
                    .font(.caption2)
                    .bold()

                if let next {
                    Text("次LO: \(next.label)（\(next.minutesText)）")
                        .font(.caption2)
                }

                Text("直近LO: \(last.label)（\(last.minutesText)）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !r.note.isEmpty {
                    Text(r.note)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(width: width, height: rowHeight - 6, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    baseColor.opacity(0.95),
                    baseColor.opacity(0.7)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: baseColor.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 2)
        .scaleEffect(scale)
        .offset(
            x: startX + (isDragging ? dragOffsetX : 0),
            y: isDragging ? dragOffsetY : 0
        )
        .animation(.spring(response: 0.18, dampingFraction: 0.85), value: isDragging)

        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    moveArmedReservationId = r.id
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard moveArmedReservationId == r.id else { return }
                    draggingReservationId = r.id
                    dragOffsetX = value.translation.width
                    dragOffsetY = value.translation.height
                }
                .onEnded { value in
                    guard moveArmedReservationId == r.id else { return }

                    applyTimeShift(for: r, dragX: value.translation.width)
                    moveReservationVertically(for: r, dragY: value.translation.height)

                    draggingReservationId = nil
                    dragOffsetX = 0
                    dragOffsetY = 0
                    moveArmedReservationId = nil
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(moveArmedReservationId == r.id ? 0.9 : 0.0), lineWidth: 2)
        )
    }

    // MARK: - LO 関連

    private func loColor(for r: ReservationEntity) -> Color {
        if r.isCheckedOut { return .gray }
        if r.didDrinkLO { return .blue }
        if r.didFoodLO { return .red }
        if r.didDonabeLO { return .purple }
        return .green
    }

    private func nextLOInfo(for r: ReservationEntity)
        -> (kind: NextLOKind, label: String, minutesText: String)?
    {
        let base = LOScheduling.loBaseTimes(endAt: r.endAt, extendMinutes: r.extendMinutes)

        func minutesDescription(_ target: Date) -> String {
            let min = Int(target.timeIntervalSince(now) / 60)
            if min == 0 { return "すぐ" }
            if min > 0 { return "あと \(min) 分" }
            return "すでに \(-min) 分遅れ"
        }

        if !r.didDonabeLO {
            return (.donabe, "土鍋LO", minutesDescription(base.donabe))
        }
        if !r.didFoodLO {
            return (.food, "食事LO", minutesDescription(base.food))
        }
        if !r.didDrinkLO {
            return (.drink, "飲み物LO", minutesDescription(base.drink))
        }
        return nil
    }

    private func lastLOInfo(for r: ReservationEntity)
        -> (label: String, minutesText: String)
    {
        let records: [(String, Date?)] = [
            ("土鍋LO", r.donabeLOAt),
            ("食事LO", r.foodLOAt),
            ("飲み物LO", r.drinkLOAt)
        ]

        let done: [(String, Date)] = records.compactMap { label, date in
            if let d = date { return (label, d) }
            return nil
        }

        guard let latest = done.max(by: { $0.1 < $1.1 }) else {
            return ("未実施", "まだLOなし")
        }

        let diffMin = Int(now.timeIntervalSince(latest.1) / 60)
        let text = diffMin <= 0 ? "今さっき" : "\(diffMin) 分前"
        return (latest.0, text)
    }

    private func colorForNextLO(kind: NextLOKind) -> Color {
        switch kind {
        case .donabe: return .purple
        case .food:   return .red
        case .drink:  return .blue
        }
    }

    // MARK: - データ計算系

    private var reservationsForSelectedDate: [ReservationEntity] {
        let cal = Calendar.current
        return allReservations.filter {
            cal.isDate($0.startAt, inSameDayAs: selectedDate)
        }
    }

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium
        return f.string(from: selectedDate)
    }

    private func defaultStartTime(for date: Date) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        c.hour = 18
        c.minute = 0
        return Calendar.current.date(from: c) ?? date
    }

    private func timeRangeText(for r: ReservationEntity) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"

        let start = f.string(from: r.startAt)
        let endBase = r.endAt.addingTimeInterval(TimeInterval(r.extendMinutes * 60))
        let end = f.string(from: endBase)

        return "\(start)〜\(end)"
    }

    // MARK: - タイムライン座標

    private var timelineWidth: CGFloat {
        CGFloat(closeHour - openHour) * hourWidth
    }

    private func timeToPosition(_ date: Date) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let h = comps.hour, let m = comps.minute else { return 0 }

        let totalMin = (h - openHour) * 60 + m
        let hourFloat = CGFloat(totalMin) / 60.0
        return hourFloat * hourWidth
    }

    private var isNowInRange: Bool {
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= openHour && hour < closeHour
    }

    // MARK: - 時間変更（15分刻み）

    private func applyTimeShift(for r: ReservationEntity, dragX: CGFloat) {
        let rawMinutes = Double(dragX / hourWidth * 60)
        let step = 15.0
        let snappedMinutes = Int((rawMinutes / step).rounded() * step)

        guard snappedMinutes != 0 else { return }

        let cal = Calendar.current

        if let newStart = cal.date(byAdding: .minute, value: snappedMinutes, to: r.startAt),
           let newEnd = cal.date(byAdding: .minute, value: snappedMinutes, to: r.endAt)
        {
            r.startAt = newStart
            r.endAt = newEnd

            do {
                try context.save()
            } catch {
                print("時間変更の保存に失敗: \(error)")
            }
        }
    }

    // MARK: - 縦移動で卓を変更

    private func moveReservationVertically(for r: ReservationEntity, dragY: CGFloat) {
        guard !tables.isEmpty else { return }

        let rowPitch: CGFloat = rowHeight
        let rawRows = dragY / rowPitch
        let deltaIndex = Int(rawRows.rounded())

        guard deltaIndex != 0 else { return }

        guard let currentIndex = tables.firstIndex(where: { $0.id == r.tableId }) else {
            return
        }

        var newIndex = currentIndex + deltaIndex
        newIndex = max(0, min(newIndex, tables.count - 1))

        guard newIndex != currentIndex else { return }

        let newTable = tables[newIndex]
        r.tableId = newTable.id

        do {
            try context.save()
        } catch {
            print("卓変更の保存に失敗: \(error)")
        }
    }
}
