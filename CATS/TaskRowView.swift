//
//  TaskRowView.swift
//  CATS
//

import SwiftUI
import Pow

struct TaskRowView: View {
    let task: CATSTask
    let currentTime: Date
    var scheduledStart: Date? = nil
    var bandwidthMatch: Double = 0.5
    var schedulingReason: String = ""
    let onComplete: () -> Void
    let onStart: () -> Void
    let onDelete: () -> Void

    @State private var completionTrigger: Int = 0
    @State private var isCompleting: Bool = false

    @State private var showXPPreview = false

    var body: some View {
        HStack(spacing: 10) {
            cognitiveLoadRing
            taskInfoSection
            Spacer()
            countdownSection
            actionSection
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(rowBackground)
        .overlay(rowBorder)
        .breathingGlow(isUrgent: task.isUrgent)
        .scaleEffect(isCompleting ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isCompleting)
    }

    // MARK: - Body Sub-Views

    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            taskTitleRow
            taskMetaRow
            if task.status != .completed && !schedulingReason.isEmpty {
                Text(schedulingReason)
                    .font(.system(size: 7, design: .rounded))
                    .foregroundStyle(.purple.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    private var taskTitleRow: some View {
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

            Text(difficultyBadge)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(loadColor.opacity(0.9))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(loadColor.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var taskMetaRow: some View {
        HStack(spacing: 6) {
            Image(systemName: task.category.icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            // Time slot: "2:30–3:00 PM" or fallback to deadline
            if let start = scheduledStart, task.status != .completed {
                timeSlotLabel(start: start)
            } else {
                Text(deadlineText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(deadlineColor)
            }

            // Duration pill
            durationPill

            if task.status != .completed {
                bandwidthPill
            }

            xpEstimateLabel
        }
    }

    private func timeSlotLabel(start: Date) -> some View {
        let end = start.addingTimeInterval(Double(task.estimatedMinutes) * 60)
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm"
        let fmtEnd = DateFormatter()
        fmtEnd.dateFormat = "h:mm a"

        return HStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
            Text("\(fmt.string(from: start))–\(fmtEnd.string(from: end))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(deadlineColor)
        }
    }

    private var durationPill: some View {
        Text(task.durationLabel)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(durationColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(durationColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var durationColor: Color {
        switch task.estimatedMinutes {
        case 15: return .green
        case 30: return .blue
        default: return .purple
        }
    }

    private var bandwidthPill: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(bandwidthMatchColor)
                .frame(width: 4, height: 4)
            Text("\(Int(bandwidthMatch * 100))%")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(bandwidthMatchColor)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(bandwidthMatchColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var xpEstimateLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 6))
            Text("~\(xpEstimate)")
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundStyle(.yellow.opacity(0.8))
    }

    private var countdownSection: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(task.timeRemainingFormatted)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(deadlineColor)
                .changeEffect(
                    .shake(rate: .fast),
                    value: task.isOverdue ? 1 : 0,
                    isEnabled: task.isOverdue
                )

            if task.status != .completed {
                progressBar
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
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

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(task.isOverdue ? Color.red.opacity(0.1) :
                task.status == .inProgress ? Color.blue.opacity(0.06) :
                Color.white.opacity(0.05))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                task.isUrgent ? Color.red.opacity(0.4) :
                    task.status == .inProgress ? Color.blue.opacity(0.2) :
                    Color.clear,
                lineWidth: 1
            )
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

    private var bandwidthMatchColor: Color {
        switch bandwidthMatch {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
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
