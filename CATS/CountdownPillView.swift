//
//  CountdownPillView.swift
//  CATS
//

import SwiftUI
import Pow

struct CountdownPillView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile

    @State private var currentCat: String = CatFaces.page.home
    @State private var catTimer: Timer?
    @State private var urgencyPulse: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            // Cat face on the left with bounce transition
            Text(currentCat)
                .font(.system(size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .transition(.catBounce)
                .id(currentCat)

            if let task = taskStore.nextDeadlineTask {
                // Divider dot with pulse for urgent
                Circle()
                    .fill(urgencyColor(task))
                    .frame(width: 4, height: 4)
                    .changeEffect(
                        .pulse(shape: Circle().inset(by: -2), count: 2),
                        value: urgencyPulse,
                        isEnabled: task.isUrgent
                    )

                // Task name (truncated)
                Text(task.title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 80)

                // Countdown with shake when overdue
                Text(task.timeRemainingFormatted)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(urgencyColor(task))
                    .changeEffect(
                        .shake(rate: .fast),
                        value: task.isOverdue ? 1 : 0,
                        isEnabled: task.isOverdue
                    )
            } else {
                Text("No tasks")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onAppear {
            startCatRotation()
        }
        .onDisappear {
            catTimer?.invalidate()
        }
    }

    private func urgencyColor(_ task: CATSTask) -> Color {
        if task.isOverdue { return .red }
        if task.timeRemaining < 3600 { return .red }
        if task.timeRemaining < 3600 * 3 { return .orange }
        if task.timeRemaining < 3600 * 12 { return .yellow }
        return .green
    }

    private func startCatRotation() {
        catTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    if let task = taskStore.nextDeadlineTask, task.isUrgent {
                        currentCat = CatFaces.stressed.randomElement()!
                        urgencyPulse += 1
                    } else {
                        currentCat = CatFaces.forMood(energy: profile.currentEnergy)
                    }
                }
            }
        }
    }
}
