import Foundation

enum WorkType: String, CaseIterable {
    case light = "Light Work"
    case deep  = "Deep Work"
}

// Renamed from Task → ScheduledTask to avoid collision with Swift.Task (concurrency)
struct ScheduledTask: Identifiable {
    let id = UUID()
    var title: String
    var workType: WorkType
    var loadPoints: Int
    var date: Date
    var duration: String
    var totalSeconds: Int
    var isCompleted: Bool = false
}
