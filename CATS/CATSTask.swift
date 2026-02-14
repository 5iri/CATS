//
//  CATSTask.swift
//  CATS
//

import Foundation

enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case inProgress
    case completed
    case onBreak
}

enum TaskCategory: String, Codable, CaseIterable {
    case deepWork = "Deep Work"
    case lightWork = "Light Work"
    case review = "Review"
    case creative = "Creative"

    var icon: String {
        switch self {
        case .deepWork: return "brain.head.profile"
        case .lightWork: return "book"
        case .review: return "eye"
        case .creative: return "paintbrush"
        }
    }
}

struct CATSTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var deadline: Date
    var cognitiveLoad: Int // 1-10
    var estimatedMinutes: Int
    var status: TaskStatus
    var calendarEventID: String?
    var category: TaskCategory
    var completedAt: Date?
    var createdAt: Date

    /// Valid task durations
    static let validDurations = [15, 30, 60]

    /// Snap any minute value to the nearest valid duration (15, 30, or 60)
    static func snapDuration(_ minutes: Int) -> Int {
        if minutes <= 20 { return 15 }
        if minutes <= 45 { return 30 }
        return 60
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        deadline: Date,
        cognitiveLoad: Int = 5,
        estimatedMinutes: Int = 60,
        status: TaskStatus = .pending,
        calendarEventID: String? = nil,
        category: TaskCategory = .deepWork,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.deadline = deadline
        self.cognitiveLoad = max(1, min(10, cognitiveLoad))
        self.estimatedMinutes = Self.snapDuration(estimatedMinutes)
        self.status = status
        self.calendarEventID = calendarEventID
        self.category = category
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    var isOverdue: Bool {
        deadline < Date() && status != .completed
    }

    var isUrgent: Bool {
        deadline.timeIntervalSinceNow < 3600 && status != .completed
    }

    var timeRemaining: TimeInterval {
        max(0, deadline.timeIntervalSinceNow)
    }

    var timeRemainingFormatted: String {
        let remaining = timeRemaining
        if remaining <= 0 && status != .completed { return "Overdue!" }
        if status == .completed { return "Done" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var durationLabel: String {
        "\(estimatedMinutes)m"
    }

    var cognitiveLoadColor: String {
        switch cognitiveLoad {
        case 1...3: return "green"
        case 4...6: return "yellow"
        case 7...8: return "orange"
        case 9...10: return "red"
        default: return "gray"
        }
    }

    var priorityScore: Double {
        let urgency = max(0, 1.0 - (timeRemaining / (24 * 3600)))
        let load = Double(cognitiveLoad) / 10.0
        return (urgency * 0.6 + load * 0.4) * 100
    }
}
