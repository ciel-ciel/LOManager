import SwiftUI
import SwiftData

@main
struct LOManagerApp: App {
    // SwiftData モデルコンテナ
    var sharedModelContainer: SwiftData.ModelContainer = {
        let schema = SwiftData.Schema([
            ReservationEntity.self,
            TableEntity.self
        ])

        // ★ 本番想定：永続ストレージを使う
        let config = SwiftData.ModelConfiguration(
            schema: schema
            // isStoredInMemoryOnly は指定しない（デフォルト = ディスク保存）
        )

        do {
            return try SwiftData.ModelContainer(for: schema, configurations: [config])
        } catch {
            // 本番でも原因が分かるようにしておく
            fatalError("ModelContainer 作成に失敗しました: \(error)")
        }
    }()

    init() {
        // 通知の許可ダイアログをアプリ起動時に出す
        NotificationService.shared.requestAuthorization()

        // 初回だけ卓を自動登録（すでに1件以上あれば何もしない）
        SeedService.seedTablesIfNeeded(context: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
