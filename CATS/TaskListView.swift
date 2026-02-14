//
//  TaskListView.swift
//  CATS
//

import Pow
import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile
    @ObservedObject var vm: DynamicIslandViewModel

    @State private var completedTaskTrigger: Int = 0

    private var smartTasks: [CATSTask] {
        taskStore.smartScheduledTasks(profile: profile)
    }

    /// Compute sequential start times: each task starts after the previous one ends
    private var scheduledStartTimes: [UUID: Date] {
        var times: [UUID: Date] = [:]
        var cursor = taskStore.currentTime // start from now

        // In-progress tasks start "now"
        for task in taskStore.inProgressTasks {
            times[task.id] = cursor
            cursor = cursor.addingTimeInterval(Double(task.estimatedMinutes) * 60)
        }

        // Pending tasks in smart order, each after the previous
        let scheduled = smartTasks.filter { $0.status == .pending }
        for task in scheduled {
            times[task.id] = cursor
            cursor = cursor.addingTimeInterval(Double(task.estimatedMinutes) * 60)
        }

        return times
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()
                .background(Color.white.opacity(0.1))

            if taskStore.activeTasks.isEmpty && taskStore.completedTasks.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 6) {
                        // Cognitive bandwidth meter
                        bandwidthBar

                        // Recovery cycle alert (if fatigue detected)
                        if profile.recoveryCycle.needsBreak {
                            recoveryCycleCard
                        }

                        // Recommended next task
                        if let recommended = smartTasks.first, !profile.recoveryCycle.needsBreak {
                            recommendedTaskBanner(recommended)
                        }

                        // In Progress
                        if !taskStore.inProgressTasks.isEmpty {
                            sectionHeader("In Progress", icon: "bolt.fill", color: .blue)
                            ForEach(taskStore.inProgressTasks) { task in
                                smartTaskRow(task)
                            }
                        }

                        // Smart Schedule (pending tasks ordered by cognitive algorithm)
                        let scheduled = smartTasks.filter { $0.status == .pending }
                        if !scheduled.isEmpty {
                            sectionHeader("Smart Schedule", icon: "brain.head.profile", color: .purple)
                            ForEach(scheduled) { task in
                                smartTaskRow(task)
                            }
                        }

                        // Completed
                        if !taskStore.completedTasks.isEmpty {
                            HStack {
                                sectionHeader(
                                    "Completed (\(taskStore.completedTasks.count))",
                                    icon: "checkmark.circle.fill",
                                    color: .green
                                )
                                Spacer()
                                Button(action: {
                                    taskStore.clearCompleted()
                                }) {
                                    Text("Clear All")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(.red.opacity(0.8))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(taskStore.completedTasks.prefix(5)) { task in
                                smartTaskRow(task)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: taskStore.tasks)
                }
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(profile.energyMood)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text("CATS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                HStack(spacing: 4) {
                    Text("\(taskStore.activeTasks.count) tasks")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: taskStore.activeTasks.count)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("Energy: \(Int(profile.currentEnergy))%")
                        .font(.system(size: 9))
                        .foregroundStyle(energyColor)
                }
            }

            Spacer()

            // XP badge with confetti
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
                    .changeEffect(
                        .spray(origin: .center) {
                            Group {
                                Text("✨")
                                Text("⭐")
                                Text("💫")
                            }
                            .font(.system(size: 10))
                        },
                        value: completedTaskTrigger
                    )
                Text("\(profile.totalXP)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: profile.totalXP)
            }
            .changeEffect(.shine, value: completedTaskTrigger)
            .changeEffect(.jump(height: 5), value: completedTaskTrigger)

            // Level badge
            VStack(alignment: .trailing, spacing: 1) {
                Text(profile.currentLevel.cat)
                    .font(.system(size: 11))
                Text(profile.currentLevel.name)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Cognitive Bandwidth Bar

    private var bandwidthBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                // Energy gauge
                HStack(spacing: 3) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 9))
                        .foregroundStyle(energyColor)
                    Text("Bandwidth")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                // Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [energyColor.opacity(0.6), energyColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * profile.currentEnergy / 100)
                    }
                }
                .frame(height: 6)

                Text("\(Int(profile.currentEnergy))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(energyColor)

                Spacer()

                // Optimal load range
                let range = profile.optimalLoadRange
                HStack(spacing: 3) {
                    Text("Optimal:")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    Text("\(range.lowerBound)-\(range.upperBound)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.purple)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())

                // Peak indicator
                if profile.isPeakHour {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7))
                        Text("Peak")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // Fatigue / strain indicator
            if profile.cumulativeStrain > 0.4 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.orange)
                    Text("Cognitive strain: \(Int(profile.cumulativeStrain * 100))%")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.8))
                    if profile.isFatigueSequence {
                        Text("· Fatigue sequence detected")
                            .font(.system(size: 7))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Recovery Cycle Card

    private var recoveryCycleCard: some View {
        let cycle = profile.recoveryCycle
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.pink)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cycle.type.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.pink)
                    Text("\(cycle.minutes) min recommended")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Recovery timer visualization
                ZStack {
                    Circle()
                        .stroke(Color.pink.opacity(0.2), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: Double(cycle.minutes) / 30.0)
                        .stroke(Color.pink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(cycle.minutes)m")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.pink)
                }
                .frame(width: 28, height: 28)
            }

            Text(cycle.message)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(2)

            // Activity suggestions
            HStack(spacing: 4) {
                ForEach(cycle.activities.prefix(3), id: \.self) { activity in
                    Text(activity)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.pink.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.pink.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.pink.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Recommended Task Banner

    private func recommendedTaskBanner(_ task: CATSTask) -> some View {
        let reason = CognitiveEngine.shared.schedulingReason(for: task, profile: profile)
        let match = profile.bandwidthMatch(for: task.cognitiveLoad)

        return HStack(spacing: 8) {
            // Bandwidth match ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: match)
                    .stroke(matchColor(match), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(task.cognitiveLoad)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(matchColor(match))
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("DO NEXT")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .foregroundStyle(.green)
                    Text(task.title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                Text(reason)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Bandwidth match badge
            Text("\(Int(match * 100))%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(matchColor(match))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(matchColor(match).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Smart Task Row

    private func smartTaskRow(_ task: CATSTask) -> some View {
        TaskRowView(
            task: task,
            currentTime: taskStore.currentTime,
            scheduledStart: scheduledStartTimes[task.id],
            bandwidthMatch: profile.bandwidthMatch(for: task.cognitiveLoad),
            schedulingReason: CognitiveEngine.shared.schedulingReason(for: task, profile: profile),
            onComplete: {
                completedTaskTrigger += 1
                taskStore.completeTask(task.id, profile: profile)
            },
            onStart: { taskStore.startTask(task.id) },
            onDelete: { taskStore.removeTask(task.id) }
        )
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(CatFaces.sleepy.randomElement()!)
                .font(.system(size: 28))
            Text("No tasks yet")
                .font(.system(size: 13, weight: .medium, design: .rounded))
            Text("Click to open and add tasks via chat")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var energyColor: Color {
        switch profile.currentEnergy {
        case 60...100: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }

    private func matchColor(_ match: Double) -> Color {
        switch match {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}
