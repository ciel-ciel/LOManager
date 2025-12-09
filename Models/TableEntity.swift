// /Users/ciel/Documents/LOManager/LOManager/Models/TableEntity.swift

import Foundation
import SwiftData

@Model
final class TableEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Int

    init(id: UUID = UUID(), name: String, sortIndex: Int) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
    }
}
