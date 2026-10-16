import Foundation

struct Transfer: Identifiable {
    let id = UUID()
    let name: String
    let upload: Bool
    var completed: Int64 = 0
    var total: Int64 = 0
    var state = "等待中"
    var finished = false
    var destination: URL?
    var fraction: Double { total > 0 ? min(1, Double(completed) / Double(total)) : 0 }
}
