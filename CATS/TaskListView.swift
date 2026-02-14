//
//  TaskListView.swift
//  CATS
//

import SwiftUI
import Pow

struct TaskListView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile
    @ObservedObject var vm: DynamicIslandViewModel
    
    @State private var completedTaskTrigger: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header with cat + energy
            headerBar

            Divider()
                .background(Color.white.opacity(0.1))

            if taskStore.activeTasks.isEmpty && taskStore.completedTasks.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 6) {
                        // In Progress
                        if !taskStore.inProgressTasks.isEmpty {
                            sectionHeader("In Progress", icon: "bolt.fill", color: .blue)
                            ForEach(taskStore.inProgressTasks) { task in
                                taskRow(task)
                            }
                        }

                        // Upcoming
                        if !taskStore.pendingTasks.isEmpty {
                            sectionHeader("Upcoming", icon: "clock", color: .orange)
                            ForEach(taskStore.pendingTasks) { task in
                                taskRow(task)
                            }
                        }

                        // Completed (collapsed)
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
                                taskRow(task)
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

    private func taskRow(_ task: CATSTask) -> some View {
        TaskRowView(
            task: task,
            currentTime: taskStore.currentTime,
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

    private var energyColor: Color {
        switch profile.currentEnergy {
        case 60...100: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }
}
