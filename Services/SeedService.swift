// /Users/ciel/Documents/LOManager/LOManager/Services/SeedService.swift

import Foundation
import SwiftData

enum SeedService {
    /// アプリ初回起動時に卓のマスターデータを登録する
    static func seedTablesIfNeeded(context modelContainer: SwiftData.ModelContainer) {
        let modelContext = ModelContext(modelContainer)

        // すでに1件でも卓があれば何もしない
        let descriptor = FetchDescriptor<TableEntity>()
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            return
        }

        // 卓の固定リスト
        let tableNames: [String] = [
            "イノイチ",
            "イコーナー",
            "ロイチ",
            "ロラス",
            "ドリ前",
            "VIP",
            "T1",
            "T2",
            "T3",
            "T4",
            "臨時1",
            "臨時2"
        ]

        for (index, name) in tableNames.enumerated() {
            let table = TableEntity(
                name: name,
                sortIndex: index
            )
            modelContext.insert(table)
        }

        do {
            try modelContext.save()
            print("初期卓データを登録しました")
        } catch {
            print("初期卓データの保存に失敗しました: \(error)")
        }
    }
}
