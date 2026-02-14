//
//  DeepWorkView.swift
//  CATS
//

import SwiftUI
import Pow

struct DeepWorkView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile
    @ObservedObject var vm: DynamicIslandViewModel
    @StateObject private var animState = AnimationState.shared

    @State private var selectedTaskID: UUID?
    @State private var showBreakSuggestion = false
    @State private var breakTimerActive = false
    @State private var breakTimeRemaining: Int = 0
    @State private var breakTimer: Timer?
    @State private var previousLevel: String = ""
    @State private var xpAnimationTrigger: Int = 0
    @State private var xpTicker: Int = 0
    @State private var xpTimer: Timer?
    @State private var showSessionComplete = false
    @State private var sessionXPEarned: Int = 0

    private let pomodoroDuration: TimeInterval = 25 * 60 // 25-min Pomodoro

    var body: some View {
        VStack(spacing: 8) {
            if showSessionComplete {
                sessionCompleteView
            } else if breakTimerActive {
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

            // Stats row with gamification + animations
            HStack(spacing: 14) {
                gamifiedStatBadge(
                    icon: "bolt.fill",
                    value: "\(Int(profile.currentEnergy))%",
                    label: "Energy",
                    color: energyColor,
                    glow: profile.currentEnergy > 80
                )
                .energyPulse(isLowEnergy: profile.currentEnergy < 30)
                
                gamifiedStatBadge(
                    icon: "flame.fill",
                    value: "\(profile.currentStreak)",
                    label: "Streak",
                    color: .orange,
                    glow: profile.currentStreak >= 3
                )
                .changeEffect(.jump(height: 3), value: profile.currentStreak)
                
                ZStack {
                    gamifiedStatBadge(
                        icon: "star.fill",
                        value: "\(profile.totalXP)",
                        label: "XP",
                        color: .yellow,
                        glow: false
                    )
                    .changeEffect(.shine, value: xpAnimationTrigger)
                    
                    FloatingXPView(
                        amount: animState.lastXPGain,
                        trigger: $animState.xpTrigger
                    )
                    .offset(y: -20)
                }
                
                gamifiedStatBadge(
                    icon: "clock.fill",
                    value: "\(profile.deepWorkMinutesToday)m",
                    label: "Today",
                    color: .blue,
                    glow: profile.deepWorkMinutesToday >= 60
                )
            }

            // Level progress with enhanced design
            enhancedLevelBar

            // Peak hour / energy advice
            if profile.isPeakHour {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                    Text("Peak Hour! Tackle your hardest task now for bonus XP")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .clipShape(Capsule())
            }

            // Task picker
            if !taskStore.activeTasks.isEmpty {
                Picker("Focus on:", selection: $selectedTaskID) {
                    Text("Select a task...").tag(nil as UUID?)
                    ForEach(taskStore.activeTasks) { task in
                        HStack {
                            Text("\(task.title)")
                            Text("(\(task.cognitiveLoad)/10 · \(task.estimatedMinutes)m)")
                                .foregroundStyle(.secondary)
                        }
                        .tag(task.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11))

                // XP Preview for selected task
                if let id = selectedTaskID,
                   let task = taskStore.tasks.first(where: { $0.id == id })
                {
                    let previewXP = task.cognitiveLoad * task.estimatedMinutes / 10
                    let peakBonus = profile.isPeakHour ? 1.5 : 1.0
                    let streakBonus = 1.0 + Double(min(profile.currentStreak, 7)) * 0.1

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                            Text("~\(Int(Double(previewXP) * peakBonus * streakBonus)) XP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.yellow)
                        }

                        if profile.isPeakHour {
                            Text("1.5x Peak")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        if profile.currentStreak > 0 {
                            Text("\(String(format: "%.1f", streakBonus))x Streak")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                Button(action: startSession) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Deep Work")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.blue.opacity(0.4), .purple.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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
            Text(formatRemainingTime(remainingTime))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            if let taskID = selectedTaskID,
               let task = taskStore.tasks.first(where: { $0.id == taskID })
            {
                Text("Focusing on: \(task.title)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Live XP ticker
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    Text("+\(xpTicker) XP")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .contentTransition(.numericText())
                }

                // Flow state indicator
                flowStateIndicator
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

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 10) {
            Text(CatFaces.excited.randomElement() ?? "ヾ(*ΦωΦ)ﾉ")
                .font(.system(size: 28))

            Text("Session Complete!")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            // XP earned
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                Text("+\(sessionXPEarned) XP")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.15))
                    .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1))
            )

            // Updated level
            HStack(spacing: 6) {
                Text(profile.currentLevel.cat)
                    .font(.system(size: 14))
                Text(profile.currentLevel.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }

            Button(action: { showSessionComplete = false }) {
                Text("Continue")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.3))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
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
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                    Text(activity)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.08))
                .clipShape(Capsule())
            }

            // Energy recovery preview
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text("Recovering energy...")
                    .font(.system(size: 9))
                    .foregroundStyle(.green.opacity(0.7))
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

    private var flowStateIndicator: some View {
        let minutes = profile.focusSessionElapsedMinutes
        let (label, color): (String, Color) = {
            if minutes < 10 { return ("Warming Up", .blue) }
            if minutes < 25 { return ("Focused", .green) }
            if minutes < 45 { return ("Flow State", .purple) }
            return ("Deep Flow", .pink)
        }()

        return HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var enhancedLevelBar: some View {
        VStack(spacing: 2) {
            HStack {
                Text(profile.currentLevel.cat)
                    .font(.system(size: 10))
                    .changeEffect(
                        .spray(origin: .center) {
                            Text("⭐").font(.system(size: 8))
                        },
                        value: animState.levelUpTrigger
                    )
                Text(profile.currentLevel.name)
                    .font(.system(size: 9, weight: .medium))
                    .changeEffect(.shine, value: animState.levelUpTrigger)
                Spacer()
                if let next = profile.nextLevel {
                    Text("\(profile.totalXP)/\(next.xpRequired) XP")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: profile.totalXP)
                }
            }

            GlowingProgressBar(
                progress: profile.levelProgress,
                gradient: [.blue, .purple],
                height: 6
            )
        }
        .onAppear {
            previousLevel = profile.currentLevel.name
        }
        .onChange(of: profile.currentLevel.name) { oldVal, newVal in
            if oldVal != newVal && !oldVal.isEmpty {
                animState.triggerLevelUp(levelName: newVal)
            }
        }
        .onChange(of: profile.totalXP) { oldVal, newVal in
            if newVal > oldVal {
                animState.triggerXPAnimation(amount: newVal - oldVal)
                xpAnimationTrigger += 1
            }
        }
        .overlay {
            LevelUpBannerView(
                levelName: animState.newLevelName,
                isShowing: animState.showLevelUpBanner
            )
            .offset(y: -50)
        }
    }

    private func gamifiedStatBadge(icon: String, value: String, label: String, color: Color, glow: Bool) -> some View {
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
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(glow ? color.opacity(0.1) : Color.clear)
        )
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

    private var remainingTime: TimeInterval {
        max(0, pomodoroDuration - profile.focusSessionElapsed)
    }

    // MARK: - Actions

    private func startSession() {
        if let taskID = selectedTaskID,
           let _ = taskStore.tasks.first(where: { $0.id == taskID })
        {
            profile.startFocusSession()
            taskStore.startTask(taskID)
        }

        // Start XP ticker
        xpTicker = 0
        xpTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            DispatchQueue.main.async {
                let cogLoad = selectedTaskID.flatMap { id in
                    taskStore.tasks.first { $0.id == id }?.cognitiveLoad
                } ?? 5
                let baseXP = cogLoad / 10 + 1
                let peakBonus = profile.isPeakHour ? 1.5 : 1.0
                withAnimation {
                    xpTicker += Int(Double(baseXP) * peakBonus)
                }
            }
        }
    }

    private func endSession() {
        xpTimer?.invalidate()
        xpTimer = nil

        let cogLoad = selectedTaskID.flatMap { id in
            taskStore.tasks.first { $0.id == id }?.cognitiveLoad
        } ?? 5

        let minutes = profile.focusSessionElapsedMinutes
        let baseXP = cogLoad * minutes / 10
        let peakBonus = profile.isPeakHour ? 1.5 : 1.0
        let streakBonus = 1.0 + Double(min(profile.currentStreak, 7)) * 0.1
        sessionXPEarned = Int(Double(baseXP) * peakBonus * streakBonus)

        profile.endFocusSession(cognitiveLoad: cogLoad)

        if minutes > 0 {
            showSessionComplete = true
        }
    }

    private func startBreak() {
        xpTimer?.invalidate()
        xpTimer = nil

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

    private func formatRemainingTime(_ interval: TimeInterval) -> String {
        if interval.isZero {
            return "Time's up!"
        }
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