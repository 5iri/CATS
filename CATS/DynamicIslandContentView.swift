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
            if vm.taskStore.activeTasks.isEmpty {
                emptyTasksView
            } else {
                // Quick task summary
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.taskStore.activeTasks.prefix(4)) { task in
                            taskCard(task)
                        }
                    }
                }

                // Cognitive bandwidth meter
                bandwidthMeter

                // Smart suggestion
                if let suggestion = smartSuggestion {
                    HStack(spacing: 6) {
                        Text(suggestion.cat)
                            .font(.system(size: 12))
                        Text(suggestion.text)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if suggestion.isAI {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundStyle(.purple.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
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

        // Break suggestion
        let breakCheck = CognitiveEngine.shared.shouldSuggestBreak(profile: profile)
        if breakCheck.shouldBreak {
            return (breakCheck.cat, breakCheck.message, false)
        }

        // Peak hour suggestion
        if profile.isPeakHour,
           let highTask = vm.taskStore.activeTasks.first(where: { $0.cognitiveLoad >= 7 })
        {
            return (
                CatFaces.page.peakHour,
                "Peak hour! Great time for \"\(highTask.title)\" (load: \(highTask.cognitiveLoad)/10)",
                OpenRouterService.shared.isConfigured
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
