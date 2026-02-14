//
//  DeepWorkView.swift
//  CATS
//

import SwiftUI

struct DeepWorkView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile
    @ObservedObject var vm: DynamicIslandViewModel

    @State private var selectedTaskID: UUID?
    @State private var showBreakSuggestion = false
    @State private var breakTimerActive = false
    @State private var breakTimeRemaining: Int = 0
    @State private var breakTimer: Timer?

    var body: some View {
        VStack(spacing: 8) {
            if breakTimerActive {
                breakView
            } else if profile.isFocusSessionActive {
                activeSessionView
            } else {
                startSessionView
            }
        }
    }

    // MARK: - Start Session

    private var startSessionView: some View {
        VStack(spacing: 10) {
            // Cat + Status
            Text(CatFaces.page.deepReady)
                .font(.system(size: 20))

            Text("Ready for Deep Work?")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            // Stats row
            HStack(spacing: 16) {
                statBadge(
                    icon: "bolt.fill",
                    value: "\(Int(profile.currentEnergy))%",
                    label: "Energy",
                    color: energyColor
                )
                statBadge(
                    icon: "flame.fill",
                    value: "\(profile.currentStreak)",
                    label: "Streak",
                    color: .orange
                )
                statBadge(
                    icon: "star.fill",
                    value: "\(profile.totalXP)",
                    label: "XP",
                    color: .yellow
                )
                statBadge(
                    icon: "clock.fill",
                    value: "\(profile.deepWorkMinutesToday)m",
                    label: "Today",
                    color: .blue
                )
            }

            // Level progress
            levelProgressBar

            // Task picker
            if !taskStore.activeTasks.isEmpty {
                Picker("Focus on:", selection: $selectedTaskID) {
                    Text("Select a task...").tag(nil as UUID?)
                    ForEach(taskStore.activeTasks) { task in
                        Text("\(task.title) (\(task.cognitiveLoad)/10)")
                            .tag(task.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11))

                Button(action: startSession) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Deep Work")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedTaskID == nil)
            }
        }
        .padding(4)
    }

    // MARK: - Active Session

    private var activeSessionView: some View {
        VStack(spacing: 8) {
            // Cat mood based on focus time
            Text(sessionCat)
                .font(.system(size: 18))

            // Timer
            Text(formatElapsed(profile.focusSessionElapsed))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            if let taskID = selectedTaskID,
               let task = taskStore.tasks.first(where: { $0.id == taskID })
            {
                Text("Focusing on: \(task.title)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Break suggestion
            if profile.needsMicroBreak || profile.needsFullBreak {
                breakSuggestionBanner
            }

            HStack(spacing: 12) {
                Button(action: endSession) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Session")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.3))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if profile.needsMicroBreak || profile.needsFullBreak {
                    Button(action: startBreak) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Take Break")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(4)
    }

    // MARK: - Break View

    private var breakView: some View {
        VStack(spacing: 8) {
            Text(CatFaces.page.breakTime)
                .font(.system(size: 24))

            Text("Recovery Break")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text(formatBreakTime(breakTimeRemaining))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)

            // Break activity suggestion
            if let activity = profile.breakActivities.randomElement() {
                Text(activity)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
            }

            Button(action: endBreak) {
                Text("I'm Refreshed!")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.3))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(4)
    }

    // MARK: - Components

    private var breakSuggestionBanner: some View {
        let suggestion = CognitiveEngine.shared.shouldSuggestBreak(profile: profile)
        return HStack(spacing: 6) {
            Text(suggestion.cat)
                .font(.system(size: 12))
            Text(suggestion.message)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var levelProgressBar: some View {
        VStack(spacing: 2) {
            HStack {
                Text(profile.currentLevel.cat)
                    .font(.system(size: 10))
                Text(profile.currentLevel.name)
                    .font(.system(size: 9, weight: .medium))
                Spacer()
                if let next = profile.nextLevel {
                    Text("\(profile.totalXP)/\(next.xpRequired) XP")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * profile.levelProgress)
                }
            }
            .frame(height: 6)
        }
    }

    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
        }
    }

    private var sessionCat: String {
        let minutes = profile.focusSessionElapsedMinutes
        if minutes < 25 { return CatFaces.page.deepFocus }
        if minutes < 45 { return CatFaces.page.deepFlow }
        return CatFaces.page.deepTired
    }

    private var energyColor: Color {
        switch profile.currentEnergy {
        case 60...100: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }

    // MARK: - Actions

    private func startSession() {
        profile.startFocusSession()
        if let id = selectedTaskID {
            taskStore.startTask(id)
        }
    }

    private func endSession() {
        let cogLoad = selectedTaskID.flatMap { id in
            taskStore.tasks.first { $0.id == id }?.cognitiveLoad
        } ?? 5
        profile.endFocusSession(cognitiveLoad: cogLoad)
    }

    private func startBreak() {
        let cogLoad = selectedTaskID.flatMap { id in
            taskStore.tasks.first { $0.id == id }?.cognitiveLoad
        } ?? 5
        profile.endFocusSession(cognitiveLoad: cogLoad)

        breakTimeRemaining = profile.suggestedBreakMinutes * 60
        breakTimerActive = true
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if breakTimeRemaining > 0 {
                    breakTimeRemaining -= 1
                } else {
                    endBreak()
                }
            }
        }
    }

    private func endBreak() {
        breakTimer?.invalidate()
        breakTimerActive = false
        let minutes = (profile.suggestedBreakMinutes * 60 - breakTimeRemaining) / 60 + 1
        profile.recoverEnergy(breakMinutes: max(1, minutes))
        breakTimeRemaining = 0
    }

    // MARK: - Formatting

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatBreakTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
