import SwiftUI
import EventKit

struct ContentView: View {
    @State private var tasks: [Task] = []
    @State private var showingAddTask = false
    @State private var completedTasks: [Task] = []
    @State private var showingCalendar = false
    @State private var showingSettings = false
    @State private var currentMotivationMessage = ""
    @State private var showingTimerView = false
    @State private var selectedTask: Task?
    @State private var isChatExpanded = true
    
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var chatManager: ChatManager = {
        let sm = SettingsManager()
        return ChatManager(settingsManager: sm)
    }()
    
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
    
    var activeTasks: [Task] { tasks.filter { !$0.isCompleted } }
    var totalLoad: Int { activeTasks.reduce(0) { $0 + $1.loadPoints } }
    
    var energyPercentage: Int {
        let drain = activeTasks.count * 5
        return max(0, min(100, 100 - drain))
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
    
    var bandwidthEmoji: String { bandwidthStatus == "Peak" ? "(ΦωΦ)" : "(=①ω①=)" }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ── HEADER ──
                HStack(spacing: 12) {
                    Button(action: { showingCalendar = true }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(white: 0.15))
                            .cornerRadius(8)
                    }
                    
                    Text("CATS")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill").foregroundColor(.yellow).font(.system(size: 13))
                        Text("\(settingsManager.totalXP)").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill").foregroundColor(.green).font(.system(size: 13))
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 6).cornerRadius(3)
                                Rectangle().fill(Color.green).frame(width: g.size.width * CGFloat(energyPercentage) / 100, height: 6).cornerRadius(3)
                            }
                        }
                        .frame(width: 55, height: 6)
                        Text("\(energyPercentage)%").font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 18))
                    }
                    
                    Button(action: { isChatExpanded.toggle() }) {
                        Image(systemName: "message.fill")
                            .foregroundColor(isChatExpanded ? .blue : .gray)
                            .font(.system(size: 18))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // ── TASK CARDS ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeTasks.prefix(5)) { task in
                            TaskCardView(task: task, onComplete: { completeTask(task) })
                        }
                        Button(action: { showingAddTask = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 32)).foregroundColor(.gray)
                                Text("Add Task").font(.system(size: 13)).foregroundColor(.gray)
                            }
                            .frame(width: 200, height: 80)
                            .background(Color(white: 0.1))
                            .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // ── BANDWIDTH ──
                HStack(spacing: 10) {
                    Image(systemName: "waveform").foregroundColor(.green).font(.system(size: 14))
                    Text("Bandwidth:").font(.system(size: 13)).foregroundColor(.white)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 5).cornerRadius(3)
                            Rectangle().fill(Color.green).frame(width: bandwidthStatus == "Peak" ? g.size.width : g.size.width * 0.5, height: 5).cornerRadius(3)
                        }
                    }
                    .frame(height: 5)
                    Text(bandwidthStatus).font(.system(size: 13, weight: .semibold)).foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.05))
                
                // ── MOTIVATION ──
                HStack {
                    Text(bandwidthEmoji).font(.system(size: 18))
                    Text(currentMotivationMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 22))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.08))
                
                // ── TASK LIST ──
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(activeTasks) { task in
                            TaskRowView(
                                task: task,
                                onComplete: { completeTask(task) },
                                onDelete: { deleteTask(task) },
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
                }
                
                // ── CHAT SECTION ──
                if isChatExpanded {
                    VStack(spacing: 0) {
                        Divider().background(Color.blue.opacity(0.4))
                        ChatView(chatManager: chatManager) { result in
                            createTaskFromChat(result)
                        }
                        .frame(height: 280)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // ── BOTTOM STATS ──
                HStack {
                    Spacer()
                    Text("Load: \(totalLoad)")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundColor(.yellow).font(.system(size: 12))
                        Text("\(settingsManager.totalXP) XP").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    }
                    .padding(.leading, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(white: 0.05))
            }
            
            // Full-screen timer overlay
            if showingTimerView, let task = selectedTask {
                TimerView(task: task, onDismiss: {
                    showingTimerView = false
                    selectedTask = nil
                })
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isChatExpanded)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(onAdd: { title, workType, hours, minutes, seconds, scheduledDate in
                addTask(title: title, workType: workType, hours: hours, minutes: minutes, seconds: seconds, scheduledDate: scheduledDate)
                showingAddTask = false
            }, onCancel: { showingAddTask = false })
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarIntegrationView(calendarManager: calendarManager, tasks: tasks)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settingsManager: settingsManager, calendarManager: calendarManager)
        }
        .onAppear {
            calendarManager.requestAccess()
            updateMotivationMessage()
            // Sync XP from settings
        }
    }
    
    private func updateMotivationMessage() {
        currentMotivationMessage = motivationMessages.randomElement() ?? motivationMessages[0]
    }
    
    private func createTaskFromChat(_ result: TaskCreationResult) {
        let totalSeconds = result.hours * 3600 + result.minutes * 60 + result.seconds
        let duration = formatDuration(hours: result.hours, minutes: result.minutes, seconds: result.seconds)
        let loadPoints = result.workType == .deep ? Int(Double(totalSeconds) / 3600.0 * 3) + 2 : Int(Double(totalSeconds) / 3600.0 * 3)
        
        let task = Task(
            title: result.title,
            workType: result.workType,
            loadPoints: max(1, loadPoints),
            date: Date(),
            duration: duration,
            totalSeconds: totalSeconds
        )
        tasks.append(task)
        calendarManager.addTaskToCalendar(task: task)
        updateMotivationMessage()
    }
    
    private func addTask(title: String, workType: WorkType, hours: Int, minutes: Int, seconds: Int, scheduledDate: Date) {
        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        let duration = formatDuration(hours: hours, minutes: minutes, seconds: seconds)
        let loadPoints = calculateLoadPoints(totalSeconds: totalSeconds, workType: workType)
        
        let task = Task(
            title: title,
            workType: workType,
            loadPoints: loadPoints,
            date: scheduledDate,
            duration: duration,
            totalSeconds: totalSeconds
        )
        tasks.append(task)
        calendarManager.addTaskToCalendar(task: task)
        updateMotivationMessage()
    }
    
    private func calculateLoadPoints(totalSeconds: Int, workType: WorkType) -> Int {
        let hours = Double(totalSeconds) / 3600.0
        let base = Int(hours * 3)
        return workType == .deep ? base + 2 : base
    }
    
    private func formatDuration(hours: Int, minutes: Int, seconds: Int) -> String {
        if hours > 0 { return "\(hours)h \(minutes)m" }
        else if minutes > 0 { return "\(minutes)m \(seconds)s" }
        else { return "\(seconds)s" }
    }
    
    private func completeTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted = true
            completedTasks.append(tasks[index])
            tasks.remove(at: index)
            let xpGain = max(10, task.loadPoints * 10)
            settingsManager.totalXP += xpGain
            settingsManager.totalTasksCompleted += 1
            if task.workType == .deep { settingsManager.deepWorkSessions += 1 }
            calendarManager.completeTaskInCalendar(task: task)
        }
    }
    
    private func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        completedTasks.removeAll { $0.id == task.id }
        calendarManager.removeTaskFromCalendar(task: task)
    }
}

struct TaskCardView: View {
    let task: Task
    let onComplete: () -> Void
    
    var statusColor: Color { task.workType == .deep ? .orange : .green }
    
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 11)).foregroundColor(.gray)
                    Text(task.duration).font(.system(size: 13)).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow)
                    Text("~\(task.loadPoints * 10)").font(.system(size: 11)).foregroundColor(.yellow)
                }
            }
        }
        .padding(12)
        .frame(width: 200, height: 80)
        .background(Color(white: 0.1))
        .cornerRadius(14)
    }
}

#Preview {
    ContentView()
}
