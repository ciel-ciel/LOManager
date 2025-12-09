import Foundation

extension Date {
    /// 当日ベースで時分を差し替え
    func replacing(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: self)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? self
    }
}
