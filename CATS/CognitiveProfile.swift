//
//  CognitiveProfile.swift
//  CATS
//

import Combine
import Foundation

class CognitiveProfile: ObservableObject {
    static let shared = CognitiveProfile()

    @PublishedPersist(key: "cats_cognitiveEnergy", defaultValue: 100.0)
    var currentEnergy: Double // 0-100

    @PublishedPersist(key: "cats_peakHours", defaultValue: [9, 10, 11, 14, 15])
    var peakHours: [Int]

    @PublishedPersist(key: "cats_fatigueAccumulator", defaultValue: 0.0)
    var fatigueAccumulator: Double // 0-100

    @PublishedPersist(key: "cats_deepWorkMinutesToday", defaultValue: 0)
    var deepWorkMinutesToday: Int

    @PublishedPersist(key: "cats_totalXP", defaultValue: 0)
    var totalXP: Int

    @PublishedPersist(key: "cats_currentStreak", defaultValue: 0)
    var currentStreak: Int

    @PublishedPersist(key: "cats_lastActiveDate", defaultValue: "")
    var lastActiveDateString: String

    @PublishedPersist(key: "cats_focusSessionStartTime", defaultValue: 0.0)
    var focusSessionStartTimestamp: Double // 0 means no session

    @PublishedPersist(key: "cats_focusTaskID", defaultValue: "")
    var focusTaskIDString: String // UUID string of task being focused on

    @PublishedPersist(key: "cats_totalFocusMinutesInSession", defaultValue: 0)
    var totalFocusMinutesInSession: Int

    var focusTaskID: UUID? {
        get { UUID(uuidString: focusTaskIDString) }
        set { focusTaskIDString = newValue?.uuidString ?? "" }
    }

    private var cancellables = Set<AnyCancellable>()
    private var energyRegenTimer: Timer?

    private init() {
        checkDayReset()
        startEnergyRegeneration()
    }

    // MARK: - Level System

    var currentLevel: (name: String, cat: String, xpRequired: Int) {
        CatFaces.levelFor(xp: totalXP)
    }

    var nextLevel: (name: String, cat: String, xpRequired: Int)? {
        CatFaces.nextLevelFor(xp: totalXP)
    }

    var levelProgress: Double {
        let current = currentLevel.xpRequired
        guard let next = nextLevel else { return 1.0 }
        let range = next.xpRequired - current
        guard range > 0 else { return 1.0 }
        return Double(totalXP - current) / Double(range)
    }

    // MARK: - Energy Management

    var isPeakHour: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return peakHours.contains(hour)
    }

    var energyMood: String {
        CatFaces.forMood(energy: currentEnergy)
    }

    func consumeEnergy(cognitiveLoad: Int, minutes: Int) {
        let drain = Double(cognitiveLoad) * Double(minutes) * 0.15
        currentEnergy = max(0, currentEnergy - drain)
        fatigueAccumulator = min(100, fatigueAccumulator + drain * 0.8)
        deepWorkMinutesToday += minutes
    }

    func recoverEnergy(breakMinutes: Int) {
        let recovery = Double(breakMinutes) * 3.0
        currentEnergy = min(100, currentEnergy + recovery)
        fatigueAccumulator = max(0, fatigueAccumulator - recovery * 1.5)
    }

    func awardXP(cognitiveLoad: Int, minutes: Int) {
        let baseXP = cognitiveLoad * minutes / 10
        let peakBonus = isPeakHour ? 1.5 : 1.0
        let streakBonus = 1.0 + Double(min(currentStreak, 7)) * 0.1
        let xp = Int(Double(baseXP) * peakBonus * streakBonus)
        totalXP += max(1, xp)
    }
    
    /// Award XP for completing a task (not tied to focus session)
    func awardTaskCompletionXP(cognitiveLoad: Int, estimatedMinutes: Int) {
        let baseXP = max(5, cognitiveLoad * 3) // Minimum 5 XP per task
        let peakBonus = isPeakHour ? 1.5 : 1.0
        let streakBonus = 1.0 + Double(min(currentStreak, 7)) * 0.1
        let xp = Int(Double(baseXP) * peakBonus * streakBonus)
        totalXP += xp
        updateStreak()
    }

    // MARK: - Focus Session

    var isFocusSessionActive: Bool {
        focusSessionStartTimestamp > 0
    }

    var focusSessionElapsed: TimeInterval {
        guard isFocusSessionActive else { return 0 }
        return Date().timeIntervalSince1970 - focusSessionStartTimestamp
    }

    var focusSessionElapsedMinutes: Int {
        Int(focusSessionElapsed / 60)
    }

    func startFocusSession(taskID: UUID? = nil) {
        focusSessionStartTimestamp = Date().timeIntervalSince1970
        focusTaskID = taskID
        totalFocusMinutesInSession = 0
    }

    func endFocusSession(cognitiveLoad: Int) {
        let minutes = focusSessionElapsedMinutes
        guard minutes > 0 else {
            focusSessionStartTimestamp = 0
            focusTaskID = nil
            return
        }
        consumeEnergy(cognitiveLoad: cognitiveLoad, minutes: minutes)
        awardXP(cognitiveLoad: cognitiveLoad, minutes: minutes)
        totalFocusMinutesInSession += minutes
        focusSessionStartTimestamp = 0
        focusTaskID = nil
        updateStreak()
    }

    // MARK: - Recovery Cycle Detection

    @PublishedPersist(key: "cats_consecutiveHighLoadTasks", defaultValue: 0)
    var consecutiveHighLoadTasks: Int

    @PublishedPersist(key: "cats_totalCognitiveLoadToday", defaultValue: 0)
    var totalCognitiveLoadToday: Int

    @PublishedPersist(key: "cats_lastTaskCompletedTimestamp", defaultValue: 0.0)
    var lastTaskCompletedTimestamp: Double

    @PublishedPersist(key: "cats_recentTaskLoads", defaultValue: [Int]())
    var recentTaskLoads: [Int] // last ~10 task loads for pattern detection

    /// Record a completed task's cognitive load for fatigue sequence analysis
    func recordTaskLoad(_ cognitiveLoad: Int) {
        recentTaskLoads.append(cognitiveLoad)
        if recentTaskLoads.count > 10 { recentTaskLoads = Array(recentTaskLoads.suffix(10)) }
        totalCognitiveLoadToday += cognitiveLoad
        lastTaskCompletedTimestamp = Date().timeIntervalSince1970

        if cognitiveLoad >= 7 {
            consecutiveHighLoadTasks += 1
        } else {
            consecutiveHighLoadTasks = 0
        }
    }

    /// Detect if the user is in a fatigue sequence (multiple heavy tasks in a row)
    var isFatigueSequence: Bool {
        // 2+ consecutive high-load tasks, or 3+ medium-load tasks
        if consecutiveHighLoadTasks >= 2 { return true }
        let recentHeavy = recentTaskLoads.suffix(4).filter { $0 >= 6 }.count
        return recentHeavy >= 3
    }

    /// Calculate cumulative cognitive strain from recent tasks
    var cumulativeStrain: Double {
        let loads = recentTaskLoads.suffix(5)
        guard !loads.isEmpty else { return 0 }
        let weighted = loads.enumerated().map { idx, load in
            Double(load) * (1.0 + Double(idx) * 0.2) // more recent = heavier weight
        }
        return weighted.reduce(0, +) / 10.0 // normalize to ~0-1 range
    }

    /// Dynamic recovery recommendation based on fatigue pattern analysis
    var recoveryCycle: (needsBreak: Bool, type: RecoveryType, minutes: Int, message: String, activities: [String]) {
        // Critical fatigue: high strain + low energy + fatigue sequence
        if isFatigueSequence && currentEnergy < 30 {
            return (.init(true), .fullRecovery, 25, "Recovery cycle triggered — your brain needs a full reset. You've been crushing heavy tasks!", [
                "Take a 10-minute walk outside",
                "Close your eyes and do box breathing (4-4-4-4)",
                "Hydrate and eat a light snack",
                "Listen to ambient sounds for 5 minutes",
                "Do gentle stretching for your neck and shoulders",
            ])
        }

        // Fatigue sequence detected
        if isFatigueSequence {
            return (true, .activeRecovery, 15, "Fatigue sequence detected — \(consecutiveHighLoadTasks) heavy tasks in a row. Time for active recovery before your retention drops.", [
                "Switch to a completely different activity for 10 min",
                "Take a short walk",
                "Do some light stretching",
                "Hydrate — your brain needs water",
            ])
        }

        // High cumulative strain
        if cumulativeStrain > 0.7 && currentEnergy < 50 {
            return (true, .microRecovery, 8, "Your cognitive load has been building up. A quick reset will boost your next session's effectiveness.", [
                "Look away from screen — 20-20-20 rule",
                "Take 5 deep breaths",
                "Stretch your wrists and fingers",
                "Drink some water",
            ])
        }

        // Standard break detection (Pomodoro-style)
        if needsFullBreak {
            return (true, .fullRecovery, 20, "Time for a recovery break! You've been working hard.", [
                "Close your eyes for 2 minutes",
                "Take a short walk",
                "Stretch your body",
                "Hydrate - drink water",
                "Listen to a calming song",
            ])
        }

        if needsMicroBreak {
            return (true, .microRecovery, 5, "Quick break? Your brain will thank you.", [
                "Look away from screen for 20s",
                "Take 3 deep breaths",
                "Stretch your neck",
                "Drink some water",
            ])
        }

        return (false, .none, 0, "", [])
    }

    enum RecoveryType: String {
        case none
        case microRecovery = "Micro Recovery"
        case activeRecovery = "Active Recovery"
        case fullRecovery = "Full Recovery"
    }

    var needsMicroBreak: Bool {
        focusSessionElapsedMinutes >= 25 && isFocusSessionActive
    }

    var needsFullBreak: Bool {
        totalFocusMinutesInSession >= 90 || fatigueAccumulator >= 75
    }

    var suggestedBreakMinutes: Int {
        recoveryCycle.minutes
    }

    var breakActivities: [String] {
        recoveryCycle.activities
    }

    /// What cognitive load range is optimal right now given energy + fatigue
    var optimalLoadRange: ClosedRange<Int> {
        if currentEnergy >= 80 && !isFatigueSequence && isPeakHour { return 7...10 }
        if currentEnergy >= 60 && !isFatigueSequence { return 5...8 }
        if currentEnergy >= 40 { return 3...6 }
        if currentEnergy >= 20 { return 1...4 }
        return 1...3
    }

    /// How well a task's cognitive load matches current bandwidth (0.0 - 1.0)
    func bandwidthMatch(for cognitiveLoad: Int) -> Double {
        let range = optimalLoadRange
        if range.contains(cognitiveLoad) { return 1.0 }
        let distance = cognitiveLoad < range.lowerBound
            ? Double(range.lowerBound - cognitiveLoad)
            : Double(cognitiveLoad - range.upperBound)
        return max(0, 1.0 - distance * 0.2)
    }

    // MARK: - Private

    private func checkDayReset() {
        let today = dateString(Date())
        if lastActiveDateString != today {
            if lastActiveDateString != "" {
                let yesterday = dateString(Date().addingTimeInterval(-86400))
                if lastActiveDateString == yesterday && deepWorkMinutesToday >= 120 {
                    currentStreak += 1
                } else if lastActiveDateString != yesterday {
                    currentStreak = 0
                }
            }
            deepWorkMinutesToday = 0
            totalFocusMinutesInSession = 0
            currentEnergy = 100
            fatigueAccumulator = 0
            consecutiveHighLoadTasks = 0
            totalCognitiveLoadToday = 0
            recentTaskLoads = []
            lastActiveDateString = today
        }
    }

    private func updateStreak() {
        let today = dateString(Date())
        if lastActiveDateString != today {
            lastActiveDateString = today
        }
    }

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func startEnergyRegeneration() {
        energyRegenTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !self.isFocusSessionActive {
                DispatchQueue.main.async {
                    self.currentEnergy = min(100, self.currentEnergy + 1.0)
                    self.fatigueAccumulator = max(0, self.fatigueAccumulator - 0.5)
                }
            }
        }
    }
}
