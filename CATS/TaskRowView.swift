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

    @State private var showXPPreview = false

    var body: some View {
        HStack(spacing: 10) {
            // Cognitive load ring
            cognitiveLoadRing

            // Task info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
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

                    // Difficulty badge
                    Text(difficultyBadge)
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(loadColor.opacity(0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(loadColor.opacity(0.12))
                        .clipShape(Capsule())
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

                    // XP estimate
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 6))
                        Text("~\(xpEstimate)")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundStyle(.yellow.opacity(0.8))
                }
            }

            Spacer()

            // Countdown / Status
            VStack(alignment: .trailing, spacing: 3) {
                Text(task.timeRemainingFormatted)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(deadlineColor)
                    .changeEffect(
                        .shake(rate: .fast),
                        value: task.isOverdue ? 1 : 0,
                        isEnabled: task.isOverdue
                    )

                // Progress bar with glow for urgent
                if task.status != .completed {
                    progressBar
                }
            }

            // Action buttons
            if task.status != .completed {
                actionButtons
            } else {
                completedBadge
                    .changeEffect(
                        .spray(origin: .center) {
                            Text("✓").foregroundStyle(.green)
                        },
                        value: completionTrigger
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(task.isOverdue ? Color.red.opacity(0.1) :
                    task.status == .inProgress ? Color.blue.opacity(0.06) :
                    Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    task.isUrgent ? Color.red.opacity(0.4) :
                        task.status == .inProgress ? Color.blue.opacity(0.2) :
                        Color.clear,
                    lineWidth: 1
                )
        )
        .breathingGlow(isUrgent: task.isUrgent)
        .scaleEffect(isCompleting ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isCompleting)
    }

    // MARK: - Cognitive Load Ring

    private var cognitiveLoadRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)
                .frame(width: 30, height: 30)

            // Load ring
            Circle()
                .trim(from: 0, to: Double(task.cognitiveLoad) / 10.0)
                .stroke(
                    AngularGradient(
                        colors: [loadColor.opacity(0.5), loadColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-90))

            Text("\(task.cognitiveLoad)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(loadColor)
        }
    }

    // MARK: - Difficulty Badge

    private var difficultyBadge: String {
        switch task.cognitiveLoad {
        case 1...2: return "Chill"
        case 3: return "Easy"
        case 4...5: return "Steady"
        case 6: return "Focused"
        case 7: return "Tough"
        case 8: return "Intense"
        case 9: return "Beast"
        case 10: return "Galaxy Brain"
        default: return "Unknown"
        }
    }

    private var xpEstimate: Int {
        task.cognitiveLoad * task.estimatedMinutes / 10
    }

    private var completedBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
            Text("Done!")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.green)
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
                    .fill(
                        LinearGradient(
                            colors: [deadlineColor.opacity(0.6), deadlineColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(width: 50, height: 3)
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            if task.status == .pending {
                Button(action: onStart) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Start working on this task")
            }

            Button(action: {
                isCompleting = true
                completionTrigger += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isCompleting = false
                    onComplete()
                }
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Mark as complete")
            .changeEffect(.jump(height: 5), value: completionTrigger)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Remove task")
        }
    }
}
