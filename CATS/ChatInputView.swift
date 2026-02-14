//
//  ChatInputView.swift
//  CATS
//

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let cat: String?
    let timestamp: Date = Date()

    // Gamification metadata
    var xpEarned: Int?
    var difficultyBadge: String?
    var cognitiveLoad: Int?
    var isAIPowered: Bool = false
}

struct ChatInputView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile
    @ObservedObject var calendarManager: CalendarManager

    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isThinking = false
    @State private var lastXPGain: Int = 0
    @State private var showXPPopup = false
    @State private var errorMessage: String?

    private var llm: OpenRouterService { OpenRouterService.shared }

    var body: some View {
        VStack(spacing: 0) {
            // AI Status Bar
            aiStatusBar

            // Messages area
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 6) {
                        if messages.isEmpty {
                            welcomeMessage
                        }
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                        if isThinking {
                            typingIndicator
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isThinking) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error bar
            if let err = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.system(size: 8, design: .rounded))
                        .foregroundStyle(.red.opacity(0.8))
                    Spacer()
                    Button("Dismiss") {
                        errorMessage = nil
                    }
                    .font(.system(size: 8))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.1))
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Input area
            HStack(spacing: 8) {
                // Calendar import button
                Button(action: { importFromCalendar() }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Import deadlines from Apple Calendar")

                // AI Schedule button
                if !taskStore.activeTasks.isEmpty {
                    Button(action: { getScheduleAdvice() }) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .help("AI scheduling advice")
                }

                TextField("Chat or add a task...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isThinking)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .topTrailing) {
            if showXPPopup {
                xpPopupView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - AI Status Bar

    private var aiStatusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(llm.isConfigured ? Color.green : Color.orange)
                .frame(width: 5, height: 5)

            if llm.isConfigured {
                Text("AI Enhanced")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green.opacity(0.8))

                Text("·")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 8))

                Text(currentModelName)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("Offline Mode")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.8))
            }

            Spacer()

            // Mental bandwidth meter
            HStack(spacing: 3) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 8))
                    .foregroundStyle(bandwidthColor)
                Text("\(bandwidthLabel)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(bandwidthColor)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bandwidthColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.03))
    }

    private var currentModelName: String {
        let m = llm.effectiveModel
        return OpenRouterService.availableModels
            .first { $0.id == m }?.name ?? m
    }

    private var bandwidthColor: Color {
        switch profile.currentEnergy {
        case 70...100: return .green
        case 40..<70: return .yellow
        default: return .red
        }
    }

    private var bandwidthLabel: String {
        switch profile.currentEnergy {
        case 80...100: return "Peak"
        case 60..<80: return "Good"
        case 40..<60: return "Moderate"
        case 20..<40: return "Low"
        default: return "Critical"
        }
    }

    // MARK: - Welcome

    private var welcomeMessage: some View {
        VStack(spacing: 10) {
            Text(CatFaces.page.welcome)
                .font(.system(size: 28))

            Text("What do you need to work on?")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            if llm.isConfigured {
                Text("AI-powered cognitive load analysis active")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.green.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 4) {
                suggestionChip("I need to finish Graph Theory today", icon: "brain.head.profile")
                suggestionChip("Study Dynamic Programming by Friday", icon: "bolt.fill")
                suggestionChip("Review notes for tomorrow's quiz", icon: "book")
            }

            // Quick stats
            HStack(spacing: 12) {
                quickStat(icon: "bolt.fill", value: "\(Int(profile.currentEnergy))%", label: "Energy", color: bandwidthColor)
                quickStat(icon: "flame.fill", value: "\(profile.currentStreak)", label: "Streak", color: .orange)
                quickStat(icon: "star.fill", value: "\(profile.totalXP)", label: "XP", color: .yellow)
                quickStat(icon: "list.bullet", value: "\(taskStore.activeTasks.count)", label: "Tasks", color: .blue)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func quickStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
        }
    }

    private func suggestionChip(_ text: String, icon: String) -> some View {
        Button(action: {
            inputText = text
            sendMessage()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(.blue.opacity(0.6))
                Text(text)
                    .font(.system(size: 10, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer() }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 3) {
                if let cat = msg.cat {
                    Text(cat)
                        .font(.system(size: 14))
                }

                Text(msg.text)
                    .font(.system(size: 11, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        msg.isUser
                            ? Color.blue.opacity(0.3)
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Gamification badges below AI messages
                if !msg.isUser {
                    HStack(spacing: 6) {
                        if msg.isAIPowered {
                            Label("AI", systemImage: "sparkles")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        if let badge = msg.difficultyBadge {
                            Text(badge)
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundStyle(badgeColor(msg.cognitiveLoad ?? 5))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(badgeColor(msg.cognitiveLoad ?? 5).opacity(0.15))
                                .clipShape(Capsule())
                        }

                        if let xp = msg.xpEarned, xp > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 6))
                                Text("+\(xp) XP")
                                    .font(.system(size: 7, weight: .bold))
                            }
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        if let load = msg.cognitiveLoad {
                            cognitiveLoadMini(load)
                        }
                    }
                }
            }

            if !msg.isUser { Spacer() }
        }
    }

    private func cognitiveLoadMini(_ load: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < (load + 1) / 2 ? loadBarColor(load) : Color.white.opacity(0.1))
                    .frame(width: 4, height: 8)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }

    private func loadBarColor(_ load: Int) -> Color {
        switch load {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
        }
    }

    private func badgeColor(_ load: Int) -> Color {
        switch load {
        case 1...3: return .green
        case 4...6: return .blue
        case 7...8: return .orange
        case 9...10: return .red
        default: return .gray
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                Text(CatFaces.focused.randomElement() ?? "(ΦωΦ)")
                    .font(.system(size: 12))
                ThinkingDots()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
    }

    // MARK: - XP Popup

    private var xpPopupView: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
            Text("+\(lastXPGain) XP preview")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
                .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1))
        )
        .padding(.top, 8)
        .padding(.trailing, 8)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(text: text, isUser: true, cat: nil))
        inputText = ""
        errorMessage = nil

        if llm.isConfigured {
            sendWithLLM(text)
        } else {
            sendWithFallback(text)
        }
    }

    private func sendWithLLM(_ text: String) {
        isThinking = true

        Task {
            do {
                let response = try await llm.sendChat(
                    text,
                    energy: profile.currentEnergy,
                    peakHour: profile.isPeakHour,
                    existingTasks: taskStore.activeTasks,
                    streak: profile.currentStreak,
                    level: profile.currentLevel.name
                )

                await MainActor.run {
                    isThinking = false

                    if response.intent == "task",
                       let title = response.title,
                       let cogLoad = response.cognitiveLoad
                    {
                        // It's a task — create it
                        let deadline = CognitiveEngine.shared.extractDeadline(
                            (response.deadlineDescription ?? "today").lowercased()
                        )
                        let category: TaskCategory
                        switch (response.category ?? "").lowercased() {
                        case "deepwork", "deep work": category = .deepWork
                        case "lightwork", "light work": category = .lightWork
                        case "review": category = .review
                        case "creative": category = .creative
                        default: category = CognitiveEngine.shared.inferCategory(cogLoad, text: text.lowercased())
                        }

                        let task = CATSTask(
                            title: title,
                            deadline: deadline,
                            cognitiveLoad: max(1, min(10, cogLoad)),
                            estimatedMinutes: response.estimatedMinutes ?? 60,
                            category: category
                        )
                        taskStore.addTask(task)

                        // Calendar sync
                        if calendarManager.isAuthorized {
                            if let eventID = calendarManager.writeDeadlineToCalendar(for: task) {
                                var updated = task
                                updated.calendarEventID = eventID
                                taskStore.updateTask(updated)
                            }
                        }

                        // Build task confirmation message
                        let cat = CatFaces.happy.randomElement()!
                        let loadDesc = loadDescription(cogLoad)
                        let fmt = DateFormatter()
                        fmt.dateFormat = "MMM d, h:mm a"

                        var lines: [String] = [response.reply]
                        lines.append("")
                        lines.append("Cognitive load: \(cogLoad)/10 (\(loadDesc))")
                        if let reasoning = response.loadReasoning {
                            lines.append("  \(reasoning)")
                        }
                        lines.append("Deadline: \(fmt.string(from: deadline))")
                        lines.append("Est. \(response.estimatedMinutes ?? 60) min of \(category.rawValue.lowercased())")

                        messages.append(ChatMessage(
                            text: lines.joined(separator: "\n"),
                            isUser: false,
                            cat: cat,
                            xpEarned: response.xpPreview,
                            difficultyBadge: response.difficultyBadge,
                            cognitiveLoad: cogLoad,
                            isAIPowered: true
                        ))

                        // XP popup
                        if let xp = response.xpPreview, xp > 0 {
                            lastXPGain = xp
                            withAnimation(.spring(duration: 0.4)) { showXPPopup = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation { showXPPopup = false }
                            }
                        }

                        // Low energy warning
                        if profile.currentEnergy < 40 && cogLoad >= 7 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                messages.append(ChatMessage(
                                    text: "Heads up — your mental bandwidth is low (\(Int(profile.currentEnergy))%). This is a heavy task. Consider recharging first or tackling lighter work.",
                                    isUser: false,
                                    cat: CatFaces.stressed.randomElement()
                                ))
                            }
                        }
                    } else {
                        // It's a conversation — just reply
                        let cat = CatFaces.happy.randomElement()!
                        messages.append(ChatMessage(
                            text: response.reply,
                            isUser: false,
                            cat: cat,
                            isAIPowered: true
                        ))
                    }
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    errorMessage = error.localizedDescription
                    // Fall back to keyword parser for task-like inputs
                    sendWithFallback(text)
                }
            }
        }
    }

    private func sendWithFallback(_ text: String) {
        let parsed = CognitiveEngine.shared.parseNaturalLanguage(text)
        let task = CATSTask(
            title: parsed.title,
            deadline: parsed.deadline,
            cognitiveLoad: parsed.cognitiveLoad,
            estimatedMinutes: parsed.estimatedMinutes,
            category: parsed.category
        )
        taskStore.addTask(task)

        if calendarManager.isAuthorized {
            if let eventID = calendarManager.writeDeadlineToCalendar(for: task) {
                var updated = task
                updated.calendarEventID = eventID
                taskStore.updateTask(updated)
            }
        }

        let cat = CatFaces.happy.randomElement()!
        let loadDesc = loadDescription(parsed.cognitiveLoad)
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        let xpEstimate = parsed.cognitiveLoad * parsed.estimatedMinutes / 10

        let response = """
            Added "\(parsed.title)"!
            Cognitive load: \(parsed.cognitiveLoad)/10 (\(loadDesc))
            Deadline: \(fmt.string(from: parsed.deadline))
            Est. \(parsed.estimatedMinutes) min of \(parsed.category.rawValue.lowercased())
            """

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            messages.append(ChatMessage(
                text: response,
                isUser: false,
                cat: cat,
                xpEarned: xpEstimate,
                cognitiveLoad: parsed.cognitiveLoad
            ))

            if profile.currentEnergy < 40 && parsed.cognitiveLoad >= 7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    messages.append(ChatMessage(
                        text: "Heads up — energy low (\(Int(profile.currentEnergy))%). Consider peak hours or a break first.",
                        isUser: false,
                        cat: CatFaces.stressed.randomElement()
                    ))
                }
            }
        }
    }

    private func getScheduleAdvice() {
        isThinking = true

        messages.append(ChatMessage(
            text: "What should I work on right now?",
            isUser: true,
            cat: nil
        ))

        Task {
            do {
                let advice = try await llm.getScheduleAdvice(
                    tasks: taskStore.activeTasks,
                    energy: profile.currentEnergy,
                    peakHour: profile.isPeakHour,
                    fatigue: profile.fatigueAccumulator,
                    deepWorkMinutes: profile.deepWorkMinutesToday
                )

                await MainActor.run {
                    isThinking = false
                    messages.append(ChatMessage(
                        text: advice,
                        isUser: false,
                        cat: CatFaces.focused.randomElement(),
                        isAIPowered: true
                    ))
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    messages.append(ChatMessage(
                        text: "Based on your energy (\(Int(profile.currentEnergy))%), I'd suggest \(profile.currentEnergy > 60 ? "tackling your hardest task" : "starting with something light").",
                        isUser: false,
                        cat: CatFaces.focused.randomElement()
                    ))
                }
            }
        }
    }

    private func importFromCalendar() {
        if !calendarManager.isAuthorized {
            calendarManager.requestAccess()
            messages.append(ChatMessage(
                text: "Requesting calendar access...",
                isUser: false,
                cat: CatFaces.focused.randomElement()!
            ))
        } else {
            calendarManager.importDeadlinesAsTasks(into: taskStore)
            let count = calendarManager.calendarEvents.count
            messages.append(ChatMessage(
                text: "Scanned \(count) upcoming calendar events and imported relevant deadlines!",
                isUser: false,
                cat: CatFaces.happy.randomElement()!
            ))
        }
    }

    private func loadDescription(_ load: Int) -> String {
        switch load {
        case 1...3: return "light"
        case 4...6: return "moderate"
        case 7...8: return "heavy"
        case 9...10: return "intense"
        default: return "moderate"
        }
    }
}

// MARK: - Thinking Dots Animation

struct ThinkingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(phase == i ? 0.8 : 0.3))
                    .frame(width: 4, height: 4)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
