//
//  TaskStore.swift
//  CATS
//

import Combine
import Foundation

class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published var tasks: [CATSTask] = [] {
        didSet { saveToDisk() }
    }

    @Published var currentTime: Date = Date()

    private var timer: Timer?
    private let storageURL: URL

    private init() {
        storageURL = documentsDirectory.appendingPathComponent("tasks.json")
        loadFromDisk()
        startCountdownTimer()
    }

    // MARK: - CRUD

    func addTask(_ task: CATSTask) {
        tasks.append(task)
        tasks.sort { $0.deadline < $1.deadline }
    }

    func updateTask(_ task: CATSTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        }
    }

    func removeTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    func completeTask(_ id: UUID) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].status = .completed
            tasks[idx].completedAt = Date()
        }
    }

    func startTask(_ id: UUID) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].status = .inProgress
        }
    }

    // MARK: - Computed

    var activeTasks: [CATSTask] {
        tasks.filter { $0.status != .completed }
            .sorted { $0.priorityScore > $1.priorityScore }
    }

    var completedTasks: [CATSTask] {
        tasks.filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
    }

    var nextDeadlineTask: CATSTask? {
        activeTasks.filter { $0.status != .completed }
            .sorted { $0.deadline < $1.deadline }
            .first
    }

    var urgentTasks: [CATSTask] {
        activeTasks.filter { $0.isUrgent }
    }

    var inProgressTasks: [CATSTask] {
        tasks.filter { $0.status == .inProgress }
    }

    var pendingTasks: [CATSTask] {
        tasks.filter { $0.status == .pending }
            .sorted { $0.deadline < $1.deadline }
    }

    var todayTasks: [CATSTask] {
        let calendar = Calendar.current
        return activeTasks.filter {
            calendar.isDateInToday($0.deadline)
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let loaded = try? decoder.decode([CATSTask].self, from: data) else { return }
        tasks = loaded
    }

    // MARK: - Timer

    private func startCountdownTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentTime = Date()
            }
        }
    }
}
