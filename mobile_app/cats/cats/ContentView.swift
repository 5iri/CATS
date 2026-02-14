import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var app = AppState()

    @State private var tasks: [ScheduledTask] = []
    @State private var completedTasks: [ScheduledTask] = []
    @State private var showingAddTask = false
    @State private var showingCalendar = false
    @State private var showingSettings = false
    @State private var showingChat = false
    @State private var currentMotivationMessage = ""
    @State private var showingTimerView = false
    @State private var selectedTask: ScheduledTask?

    let motivationMessages = [
        "Peak hour! Perfect time to crush your tasks",
        "Energy levels optimal! Time to get things done",
        "You're in the zone! Make the most of it",
        "Focus mode activated! Let's go",
        "Prime productivity hours! Strike while the iron is hot",
        "Your brain is at peak performance right now",
        "Maximum efficiency unlocked! Time to work",
        "The stars are aligned for productivity",
        "Perfect conditions for deep work ahead",
        "Your future self will thank you for working now"
    ]

    var activeTasks: [ScheduledTask] { tasks.filter { !$0.isCompleted } }
    var totalLoad: Int { activeTasks.reduce(0) { $0 + $1.loadPoints } }

    var energyPercentage: Int {
        max(0, min(100, 100 - activeTasks.count * 5))
    }

    var energyEmoji: String {
        switch energyPercentage {
        case 80...100: return "(=^･ω･^=)"
        case 60..<80:  return "(=^･ω･^=)"
        case 40..<60:  return "(=；ェ；=)"
        case 20..<40:  return "(=´ω｀=)"
        default:       return "(=ω=)"
        }
    }

    var bandwidthStatus: String {
        let h = Calendar.current.component(.hour, from: Date())
        return (h >= 9 && h <= 12) || (h >= 14 && h <= 17) ? "Peak" : "Off-Peak"
    }

    var bandwidthEmoji: String {
        bandwidthStatus == "Peak" ? "(ΦωΦ)" : "(=①ω①=)"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            Color.black.ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }

            VStack(spacing: 0) {

                // ── HEADER ──
                HStack(spacing: 10) {
                    Button(action: { showingCalendar = true }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(white: 0.18))
                            .cornerRadius(7)
                    }

                    Text("CATS")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                        Text("\(app.settings.totalXP)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 52, height: 6)
                            Capsule()
                                .fill(Color.green)
                                .frame(width: 52 * CGFloat(energyPercentage) / 100, height: 6)
                        }
                        Text("\(energyPercentage)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .fixedSize()
                    }

                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 17))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                // ── TASK CARDS ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeTasks.prefix(5)) { task in
                            TaskCardView(task: task, onComplete: { completeTask(task) })
                        }
                        Button(action: { showingAddTask = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("Add Task")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 200, height: 80)
                            .background(Color(white: 0.1))
                            .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                // ── BANDWIDTH ──
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundColor(.green).font(.system(size: 13))
                    Text("Bandwidth:")
                        .font(.system(size: 13)).foregroundColor(.white)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.3)).frame(height: 5)
                            Capsule().fill(Color.green)
                                .frame(
                                    width: bandwidthStatus == "Peak"
                                        ? g.size.width : g.size.width * 0.5,
                                    height: 5
                                )
                        }
                    }
                    .frame(height: 5)
                    Text(bandwidthStatus)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.green).fixedSize()
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color(white: 0.05))

                // ── MOTIVATION ──
                HStack(spacing: 8) {
                    Text(bandwidthEmoji).font(.system(size: 16))
                    Text(currentMotivationMessage)
                        .font(.system(size: 13)).foregroundColor(.gray)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Spacer()
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue).font(.system(size: 20))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color(white: 0.08))

                // ── TASK LIST ──
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(activeTasks) { task in
                            TaskRowView(
                                task: task,
                                onComplete: { completeTask(task) },
                                onDelete:   { deleteTask(task) },
                                onPlay: {
                                    selectedTask = task
                                    showingTimerView = true
                                }
                            )
                        }
                        if !completedTasks.isEmpty {
                            CompletedSectionView(
                                tasks: completedTasks,
                                onClearAll: { completedTasks.removeAll() }
                            )
                        }
                    }
                    .padding(.bottom, 90)
                }

                // ── BOTTOM STATS ──
                HStack {
                    Spacer()
                    Text("Load: \(totalLoad)")
                        .font(.system(size: 12)).foregroundColor(.white)
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow).font(.system(size: 11))
                        Text("\(app.settings.totalXP) XP")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    }
                    .padding(.leading, 14)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color(white: 0.05))
            }

            // ── FLOATING PAW BUTTON ──
            Button(action: { showingChat = true }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.2), Color(white: 0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)

                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)

                    // Status dot
                    Circle()
                        .fill(
                            app.chat.apiKeyStatus == .valid ? Color.green :
                            app.chat.apiKeyStatus == .invalid ? Color.red :
                            Color.gray
                        )
                        .frame(width: 10, height: 10)
                        .offset(x: 20, y: -20)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 60)

            // ── TIMER OVERLAY ──
            if showingTimerView, let task = selectedTask {
                TimerView(task: task, onDismiss: {
                    showingTimerView = false
                    selectedTask = nil
                })
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(
                onAdd: { title, workType, hours, minutes, seconds, scheduledDate in
                    addTask(title: title, workType: workType,
                            hours: hours, minutes: minutes,
                            seconds: seconds, scheduledDate: scheduledDate)
                    showingAddTask = false
                },
                onCancel: { showingAddTask = false }
            )
        }
        .sheet(isPresented: $showingChat) {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()
                ChatView(
                    chatManager: app.chat,
                    activeTasks: activeTasks,
                    energyPercentage: energyPercentage,
                    onTaskCreate: { result in
                        createTaskFromChat(result)
                    }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarIntegrationView(calendarManager: app.calendar, tasks: tasks)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                settingsManager: app.settings,
                calendarManager: app.calendar,
                chatManager: app.chat
            )
        }
        .onAppear {
            app.calendar.requestAccess()
            updateMotivationMessage()
        }
    }

    // MARK: - Helpers

    private func updateMotivationMessage() {
        currentMotivationMessage = motivationMessages.randomElement() ?? motivationMessages[0]
    }

    private func createTaskFromChat(_ result: TaskCreationResult) {
        let total = result.hours * 3600 + result.minutes * 60 + result.seconds
        let dur   = formatDuration(hours: result.hours, minutes: result.minutes, seconds: result.seconds)

        let task = ScheduledTask(
            title:        result.title,
            workType:     result.workType,
            loadPoints:   max(1, result.cognitiveLoad),
            date:         Date(),
            duration:     dur.isEmpty ? "30m" : dur,
            totalSeconds: total == 0 ? 1800 : total
        )
        tasks.append(task)
        app.calendar.addTaskToCalendar(task: task)
        updateMotivationMessage()
    }

    private func addTask(title: String, workType: WorkType,
                         hours: Int, minutes: Int, seconds: Int,
                         scheduledDate: Date) {
        let total = hours * 3600 + minutes * 60 + seconds
        let dur   = formatDuration(hours: hours, minutes: minutes, seconds: seconds)
        let lp    = calculateLoadPoints(totalSeconds: total, workType: workType)

        let task = ScheduledTask(
            title:        title,
            workType:     workType,
            loadPoints:   lp,
            date:         scheduledDate,
            duration:     dur,
            totalSeconds: total
        )
        tasks.append(task)
        app.calendar.addTaskToCalendar(task: task)
        updateMotivationMessage()
    }

    private func calculateLoadPoints(totalSeconds: Int, workType: WorkType) -> Int {
        let h = Double(totalSeconds) / 3600.0
        return workType == .deep ? Int(h * 3) + 2 : Int(h * 3)
    }

    private func formatDuration(hours: Int, minutes: Int, seconds: Int) -> String {
        if hours > 0   { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    private func completeTask(_ task: ScheduledTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isCompleted = true
        completedTasks.append(tasks[i])
        tasks.remove(at: i)
        app.settings.totalXP += max(10, task.loadPoints * 10)
        app.settings.totalTasksCompleted += 1
        if task.workType == .deep { app.settings.deepWorkSessions += 1 }
        app.calendar.completeTaskInCalendar(task: task)
    }

    private func deleteTask(_ task: ScheduledTask) {
        tasks.removeAll { $0.id == task.id }
        completedTasks.removeAll { $0.id == task.id }
        app.calendar.removeTaskFromCalendar(task: task)
    }
}

// MARK: - Task Card

struct TaskCardView: View {
    let task: ScheduledTask
    let onComplete: () -> Void
    var statusColor: Color { task.workType == .deep ? .orange : .green }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white).lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 10)).foregroundColor(.gray)
                    Text(task.duration).font(.system(size: 12)).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow)
                    Text("~\(task.loadPoints * 10)").font(.system(size: 11)).foregroundColor(.yellow)
                }
            }
        }
        .padding(12)
        .frame(width: 200, height: 76)
        .background(Color(white: 0.1))
        .cornerRadius(14)
    }
}

#Preview { ContentView() }
