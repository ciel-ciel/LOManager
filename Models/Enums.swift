import Foundation

enum LOPhase: String, Codable {
    case normal      // 余裕あり
    case warn60      // 60分前（例: 土鍋）
    case warn30      // 30分前（例: 食事）
    case warn15      // 15分前（例: 飲み物）
    case passed      // LO過ぎ
}
