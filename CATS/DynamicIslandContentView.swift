//
//  DynamicIslandContentView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import SwiftUI

struct DynamicIslandContentView: View {
    @StateObject var vm: DynamicIslandViewModel

    var body: some View {
        ZStack {
            switch vm.contentType {
            case .tasks:
                tasksOverview
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            case .chat:
                ChatInputView(
                    taskStore: vm.taskStore,
                    profile: vm.profile,
                    calendarManager: vm.calendarManager
                )
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            case .deepWork:
                DeepWorkView(
                    taskStore: vm.taskStore,
                    profile: vm.profile,
                    vm: vm
                )
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            case .settings:
                DynamicIslandSettingsView(vm: vm)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(vm.animation, value: vm.contentType)
    }

    private var tasksOverview: some View {
        VStack(spacing: 8) {
            emptyTasksView
        }
    }

    private var emptyTasksView: some View {
        VStack(spacing: 8) {
            Text(CatFaces.page.emptyTasks)
                .font(.system(size: 22))
            Text("No tasks yet! Click Chat to add one.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)

            if OpenRouterService.shared.isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                        .foregroundStyle(.purple)
                    Text("AI-powered task analysis ready")
                        .font(.system(size: 9))
                        .foregroundStyle(.purple.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bandwidth Meter

    private var bandwidthMeter: some View {
        HStack(spacing: 8) {
            // Mental bandwidth
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 8))
                    .foregroundStyle(bandwidthColor)
                Text("Bandwidth:")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                // Mini bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(bandwidthColor)
                            .frame(width: geo.size.width * vm.profile.currentEnergy / 100)
                    }
                }
                .frame(width: 40, height: 4)

                Text(bandwidthLabel)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(bandwidthColor)
            }

            Spacer()

            // Total cognitive load
            let totalLoad = vm.taskStore.activeTasks.reduce(0) { $0 + $1.cognitiveLoad }
            HStack(spacing: 3) {
                Text("Total Load:")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text("\(totalLoad)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(totalLoad > 30 ? .red : totalLoad > 20 ? .orange : .green)
            }

            // Today's XP
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.yellow)
                Text("\(vm.profile.totalXP) XP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.yellow.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
    }

    private var bandwidthColor: Color {
        switch vm.profile.currentEnergy {
        case 70...100: return .green
        case 40..<70: return .yellow
        default: return .red
        }
    }

    private var bandwidthLabel: String {
        switch vm.profile.currentEnergy {
        case 80...100: return "Peak"
        case 60..<80: return "Good"
        case 40..<60: return "Mid"
        case 20..<40: return "Low"
        default: return "!"
        }
    }

    private func taskCard(_ task: CATSTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(loadColor(task.cognitiveLoad))
                    .frame(width: 6, height: 6)
                Text(task.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                // Duration pill
                Text(task.durationLabel)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(durationColor(task.estimatedMinutes))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(durationColor(task.estimatedMinutes).opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                Text(task.timeRemainingFormatted)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(urgencyColor(task))

                Spacer()

                // XP badge
                HStack(spacing: 1) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 5))
                    Text("~\(task.cognitiveLoad * task.estimatedMinutes / 10)")
                        .font(.system(size: 7, weight: .medium))
                }
                .foregroundStyle(.yellow.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    task.isUrgent ? Color.red.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private func durationColor(_ minutes: Int) -> Color {
        switch minutes {
        case 15: return .green
        case 30: return .blue
        default: return .purple
        }
    }

    private func loadColor(_ load: Int) -> Color {
        switch load {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
        }
    }

    private func urgencyColor(_ task: CATSTask) -> Color {
        if task.isOverdue { return .red }
        if task.timeRemaining < 3600 { return .red }
        if task.timeRemaining < 3600 * 3 { return .orange }
        return .secondary
    }

    private var smartSuggestion: (cat: String, text: String, isAI: Bool)? {
        let profile = vm.profile

        // Recovery cycle suggestion (highest priority)
        let cycle = profile.recoveryCycle
        if cycle.needsBreak {
            return (
                CatFaces.page.breakHint,
                "\(cycle.type.rawValue): \(cycle.message)",
                false
            )
        }

        // Smart task recommendation
        if let recommended = vm.taskStore.recommendedTask(profile: profile) {
            let reason = CognitiveEngine.shared.schedulingReason(for: recommended, profile: profile)
            let match = Int(profile.bandwidthMatch(for: recommended.cognitiveLoad) * 100)

            if profile.isPeakHour && recommended.cognitiveLoad >= 7 {
                return (
                    CatFaces.page.peakHour,
                    "Peak hour! Do \"\(recommended.title)\" (load \(recommended.cognitiveLoad)/10, \(match)% match)",
                    true
                )
            }

            return (
                CatFaces.focused.randomElement() ?? "(ΦωΦ)",
                "Next: \"\(recommended.title)\" — \(reason)",
                true
            )
        }

        // Low energy warning
        if profile.currentEnergy < 30 {
            return (
                CatFaces.page.lowEnergy,
                "Energy low at \(Int(profile.currentEnergy))%. Consider a break or light tasks.",
                false
            )
        }

        return nil
    }
}
