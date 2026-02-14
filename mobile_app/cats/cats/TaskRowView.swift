import SwiftUI

struct TaskRowView: View {
    let task: ScheduledTask
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onPlay: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var showConfetti = false

    var statusColor: Color { task.workType == .deep ? .orange : .green }

    var body: some View {
        ZStack {
            HStack(spacing: 15) {
                Circle().fill(statusColor).frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Image(systemName: task.workType == .light ? "book" : "brain")
                            .font(.system(size: 12)).foregroundColor(.gray)
                        Text(task.workType.rawValue)
                            .font(.system(size: 14)).foregroundColor(.gray)
                        Text("•").foregroundColor(.gray)
                        Text(formatDate(task.date))
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(task.duration)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Button(action: onPlay) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28)).foregroundColor(.blue)
                        }
                        Button(action: {
                            showConfetti = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onComplete()
                            }
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28)).foregroundColor(.green)
                        }
                        Button(action: { showingDeleteConfirmation = true }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28)).foregroundColor(.red)
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 15)
            .background(Color(white: 0.08))

            if showConfetti {
                ConfettiView().allowsHitTesting(false)
            }
        }
        .alert("Delete Task", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete this task?")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, hh:mm a"
        return f.string(from: date)
    }
}
