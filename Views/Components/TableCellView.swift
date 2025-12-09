import SwiftUI
import SwiftData

struct TableCellView: View {
    let table: TableEntity
    let reservations: [ReservationEntity]
    var onAddTap: () -> Void
    var onRowTap: (ReservationEntity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(table.name)
                    .font(.headline)
                Spacer()
                Button(action: { onAddTap() }) {
                    Image(systemName: "plus.circle")
                }
            }

            if reservations.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6,4]))
                    .frame(height: 56)
                    .overlay(Text("予約なし").foregroundStyle(.secondary))
            } else {
                ForEach(reservations, id: \.id) { r in
                    ReservationRow(reservation: r)
                        .onTapGesture { onRowTap(r) }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
