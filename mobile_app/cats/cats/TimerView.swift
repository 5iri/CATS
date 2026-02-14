import SwiftUI

struct TimerView: View {
    let task: ScheduledTask
    let onDismiss: () -> Void

    @State private var timeRemaining: Int
    @State private var timer: Timer?
    @State private var isPaused = false

    init(task: ScheduledTask, onDismiss: @escaping () -> Void) {
        self.task = task
        self.onDismiss = onDismiss
        _timeRemaining = State(initialValue: task.totalSeconds)
    }

    var progress: Double {
        guard task.totalSeconds > 0 else { return 0 }
        return Double(timeRemaining) / Double(task.totalSeconds)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                VStack(spacing: 10) {
                    Text(task.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Text(task.workType.rawValue)
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 300, height: 300)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            task.workType == .deep ? Color.orange : Color.green,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: progress)

                    VStack(spacing: 10) {
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("remaining")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                HStack(spacing: 40) {
                    Button(action: togglePause) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 40)).foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color(white: 0.15)).clipShape(Circle())
                    }
                    Button(action: { stopTimer(); onDismiss() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 40)).foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.red.opacity(0.8)).clipShape(Circle())
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onTapGesture { stopTimer(); onDismiss() }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 { timeRemaining -= 1 }
            else { stopTimer(); onDismiss() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func togglePause() {
        isPaused.toggle()
        isPaused ? stopTimer() : startTimer()
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%02d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
