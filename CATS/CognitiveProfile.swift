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

    @PublishedPersist(key: "cats_totalFocusMinutesInSession", defaultValue: 0)
    var totalFocusMinutesInSession: Int

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

    func startFocusSession() {
        focusSessionStartTimestamp = Date().timeIntervalSince1970
        totalFocusMinutesInSession = 0
    }

    func endFocusSession(cognitiveLoad: Int) {
        let minutes = focusSessionElapsedMinutes
        guard minutes > 0 else {
            focusSessionStartTimestamp = 0
            return
        }
        consumeEnergy(cognitiveLoad: cognitiveLoad, minutes: minutes)
        awardXP(cognitiveLoad: cognitiveLoad, minutes: minutes)
        totalFocusMinutesInSession += minutes
        focusSessionStartTimestamp = 0
        updateStreak()
    }

    // MARK: - Recovery Detection

    var needsMicroBreak: Bool {
        focusSessionElapsedMinutes >= 25 && isFocusSessionActive
    }

    var needsFullBreak: Bool {
        totalFocusMinutesInSession >= 90 || fatigueAccumulator >= 75
    }

    var suggestedBreakMinutes: Int {
        if needsFullBreak { return 20 }
        if needsMicroBreak { return 5 }
        return 0
    }

    var breakActivities: [String] {
        if needsFullBreak {
            return [
                "Close your eyes for 2 minutes",
                "Take a short walk",
                "Stretch your body",
                "Hydrate - drink water",
                "Listen to a calming song",
            ]
        }
        return [
            "Look away from screen for 20s",
            "Take 3 deep breaths",
            "Stretch your neck",
            "Drink some water",
        ]
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
