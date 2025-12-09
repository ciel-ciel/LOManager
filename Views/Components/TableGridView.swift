import SwiftUI
import SwiftData

struct TableGridView: View {
    let tables: [TableEntity]
    let reservationsByTable: [UUID: [ReservationEntity]]

    var onAddTap: (TableEntity) -> Void
    var onRowTap: (ReservationEntity) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(tables, id: \.id) { table in
                    TableCellView(
                        table: table,
                        reservations: (reservationsByTable[table.id] ?? []),
                        onAddTap: { onAddTap(table) },
                        onRowTap: onRowTap
                    )
                }
            }
        }
    }
}
