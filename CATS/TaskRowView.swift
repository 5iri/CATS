//
//  TaskRowView.swift
//  CATS
//

import SwiftUI
import Pow

struct TaskRowView: View {
    let task: CATSTask
    let currentTime: Date
    let onComplete: () -> Void
    let onStart: () -> Void
    let onDelete: () -> Void
    
    @State private var completionTrigger: Int = 0
    @State private var isCompleting: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Cognitive load indicator
            cognitiveLoadBadge

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .strikethrough(task.status == .completed)
                        .foregroundStyle(task.status == .completed ? .secondary : .primary)

                    if task.status == .inProgress {
                        Text("ACTIVE")
                            .font(.system(size: 7, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.3))
                            .clipShape(Capsule())
                            .changeEffect(.shine, value: task.status)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: task.category.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    Text(task.category.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(deadlineText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(deadlineColor)
                }
            }

            Spacer()

            // Countdown / Status
            VStack(alignment: .trailing, spacing: 2) {
                Text(task.timeRemainingFormatted)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(deadlineColor)
                    .changeEffect(
                        .shake(rate: .fast),
                        value: task.isOverdue ? 1 : 0,
                        isEnabled: task.isOverdue
                    )

                // Progress based on time passed
                if task.status != .completed {
                    progressBar
                }
            }

            // Action buttons
            if task.status != .completed {
                actionButtons
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
                    .changeEffect(
                        .spray(origin: .center) {
                            Text("✓").foregroundStyle(.green)
                        },
                        value: completionTrigger
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(task.isOverdue ? Color.red.opacity(0.1) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    task.isUrgent ? Color.red.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .breathingGlow(isUrgent: task.isUrgent)
        .scaleEffect(isCompleting ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isCompleting)
    }

    private var cognitiveLoadBadge: some View {
        ZStack {
            Circle()
                .fill(loadColor.opacity(0.2))
                .frame(width: 28, height: 28)
            Text("\(task.cognitiveLoad)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(loadColor)
        }
    }

    private var loadColor: Color {
        switch task.cognitiveLoad {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
        }
    }

    private var deadlineColor: Color {
        if task.isOverdue { return .red }
        if task.timeRemaining < 3600 { return .red }
        if task.timeRemaining < 3600 * 3 { return .orange }
        if task.timeRemaining < 3600 * 12 { return .yellow }
        return .green
    }

    private var deadlineText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: task.deadline)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let total = task.deadline.timeIntervalSince(task.createdAt)
            let elapsed = Date().timeIntervalSince(task.createdAt)
            let progress = min(1, max(0, elapsed / total))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 2)
                    .fill(deadlineColor)
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(width: 50, height: 3)
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            if task.status == .pending {
                Button(action: onStart) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                isCompleting = true
                completionTrigger += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isCompleting = false
                    onComplete()
                }
            }) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .changeEffect(.jump(height: 5), value: completionTrigger)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }
}
