//
//  ChatInputView.swift
//  CATS
//

import SwiftUI

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Codable {
    var id: UUID
    var text: String
    var isUser: Bool
    var cat: String?
    var timestamp: Date
    var xpEarned: Int?
    var difficultyBadge: String?
    var cognitiveLoad: Int?
    var isAIPowered: Bool

    init(
        text: String,
        isUser: Bool,
        cat: String?,
        xpEarned: Int? = nil,
        difficultyBadge: String? = nil,
        cognitiveLoad: Int? = nil,
        isAIPowered: Bool = false
    ) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.cat = cat
        self.timestamp = Date()
        self.xpEarned = xpEarned
        self.difficultyBadge = difficultyBadge
        self.cognitiveLoad = cognitiveLoad
        self.isAIPowered = isAIPowered
    }

    enum CodingKeys: String, CodingKey {
        case id, text, isUser, cat, timestamp
        case xpEarned, difficultyBadge, cognitiveLoad, isAIPowered
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        cat = try container.decodeIfPresent(String.self, forKey: .cat)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        xpEarned = try container.decodeIfPresent(Int.self, forKey: .xpEarned)
        difficultyBadge = try container.decodeIfPresent(String.self, forKey: .difficultyBadge)
        cognitiveLoad = try container.decodeIfPresent(Int.self, forKey: .cognitiveLoad)
        isAIPowered = try container.decodeIfPresent(Bool.self, forKey: .isAIPowered) ?? false
    }
}

// MARK: - Chat History Store (persistent)

class ChatHistoryStore: ObservableObject {
    static let shared = ChatHistoryStore()

    @Published var messages: [ChatMessage] = []

    private let storageKey = "cats_chat_history"
    private let maxMessages = 200

    private init() {
        loadMessages()
    }

    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        trimIfNeeded()
        saveMessages()
    }

    func clearHistory() {
        messages.removeAll()
        saveMessages()
    }

    /// Recent conversation formatted for LLM multi-turn context
    var recentHistoryForLLM: [(role: String, content: String)] {
        messages.suffix(10).map { msg in
            (msg.isUser ? "user" : "assistant", msg.text)
        }
    }

    private func trimIfNeeded() {
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
    }

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data)
        else { return }
        messages = decoded
    }

    private func saveMessages() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile
    @ObservedObject var calendarManager: CalendarManager

    @ObservedObject private var chatHistory = ChatHistoryStore.shared

    @State private var inputText: String = ""
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
                        if chatHistory.messages.isEmpty {
                            welcomeMessage
                        }
                        ForEach(chatHistory.messages) { msg in
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
                .onChange(of: chatHistory.messages.count) {
                    if let last = chatHistory.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isThinking) {
                    if let last = chatHistory.messages.last {
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

                // Clear chat history button
                if !chatHistory.messages.isEmpty {
                    Button(action: { chatHistory.clearHistory() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Clear chat history")
                }

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

        chatHistory.addMessage(ChatMessage(text: text, isUser: true, cat: nil))
        inputText = ""
        errorMessage = nil

        if llm.isConfigured {
            sendWithLLM(text)
        } else {
            sendWithFallback(text)
        }
    }

    // MARK: - LLM-Powered Send (CognitiveEngine is backbone, LLM enhances)

    private func sendWithLLM(_ text: String) {
        isThinking = true

        // Step 1: ALWAYS detect intent locally first — this is the source of truth
        let localIntent = detectLocalIntent(text)

        // Step 2: If it's a task, parse it locally RIGHT NOW (guaranteed to work)
        let localParsed = localIntent == "task"
            ? CognitiveEngine.shared.parseNaturalLanguage(text) : nil

        // Step 3: Ask LLM for enhancement (better reply, maybe better title)
        let history = chatHistory.recentHistoryForLLM

        // Build calendar context
        let calEvents: [String] = calendarManager.calendarEvents.prefix(5).map { event in
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d h:mm a"
            return "\(event.title ?? "Event") (\(fmt.string(from: event.startDate)))"
        }
        let range = profile.optimalLoadRange

        Task {
            // Try to get LLM response, but don't depend on it
            var llmResponse: LLMChatResponse?
            do {
                llmResponse = try await llm.sendChat(
                    text,
                    energy: profile.currentEnergy,
                    peakHour: profile.isPeakHour,
                    existingTasks: taskStore.activeTasks,
                    streak: profile.currentStreak,
                    level: profile.currentLevel.name,
                    conversationHistory: history,
                    calendarEvents: calEvents,
                    fatigueSequence: profile.isFatigueSequence,
                    optimalLoadRange: "\(range.lowerBound)-\(range.upperBound)"
                )
            } catch {
                // LLM failed — that's fine, we have local fallback
                await MainActor.run { errorMessage = nil }
            }

            await MainActor.run {
                isThinking = false

                if localIntent == "task", let parsed = localParsed {
                    // --- TASK PATH: Always create the task via CognitiveEngine ---
                    // LLM can enhance title, cognitive load, and reply — but task ALWAYS gets created

                    let title = llmResponse?.title ?? parsed.title
                    let cogLoad = max(1, min(10, llmResponse?.cognitiveLoad ?? parsed.cognitiveLoad))
                    let minutes = llmResponse?.estimatedMinutes ?? parsed.estimatedMinutes

                    let deadline: Date
                    if let llmDeadline = llmResponse?.deadlineDescription {
                        deadline = CognitiveEngine.shared.extractDeadline(llmDeadline.lowercased())
                    } else {
                        deadline = parsed.deadline
                    }

                    let category: TaskCategory
                    if let llmCat = llmResponse?.category?.lowercased() {
                        switch llmCat {
                        case "deepwork", "deep work": category = .deepWork
                        case "lightwork", "light work": category = .lightWork
                        case "review": category = .review
                        case "creative": category = .creative
                        default: category = parsed.category
                        }
                    } else {
                        category = parsed.category
                    }

                    let task = CATSTask(
                        title: title,
                        deadline: deadline,
                        cognitiveLoad: cogLoad,
                        estimatedMinutes: minutes,
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

                    // Build confirmation message
                    let cat = CatFaces.happy.randomElement()!
                    let loadDesc = loadDescription(cogLoad)
                    let fmt = DateFormatter()
                    fmt.dateFormat = "MMM d, h:mm a"
                    let xpEstimate = llmResponse?.xpPreview ?? (cogLoad * minutes / 10)
                    let isAI = llmResponse != nil

                    let replyText = llmResponse?.reply ?? "Added \"\(title)\"!"
                    var lines: [String] = [replyText]
                    lines.append("")
                    lines.append("Cognitive load: \(cogLoad)/10 (\(loadDesc))")
                    if let reasoning = llmResponse?.loadReasoning {
                        lines.append("  \(reasoning)")
                    }
                    lines.append("Deadline: \(fmt.string(from: deadline))")
                    lines.append("Est. \(minutes) min of \(category.rawValue.lowercased())")

                    chatHistory.addMessage(ChatMessage(
                        text: lines.joined(separator: "\n"),
                        isUser: false,
                        cat: cat,
                        xpEarned: xpEstimate,
                        difficultyBadge: llmResponse?.difficultyBadge,
                        cognitiveLoad: cogLoad,
                        isAIPowered: isAI
                    ))

                    // XP popup
                    if xpEstimate > 0 {
                        lastXPGain = xpEstimate
                        withAnimation(.spring(duration: 0.4)) { showXPPopup = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { showXPPopup = false }
                        }
                    }

                    // Recovery cycle / energy warnings
                    checkAndSuggestRecovery(afterTaskLoad: cogLoad)

                } else if let response = llmResponse, response.intent == "task",
                          let title = response.title,
                          let cogLoad = response.cognitiveLoad
                {
                    // --- LLM detected task intent that local detector missed ---
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

                    if calendarManager.isAuthorized {
                        if let eventID = calendarManager.writeDeadlineToCalendar(for: task) {
                            var updated = task
                            updated.calendarEventID = eventID
                            taskStore.updateTask(updated)
                        }
                    }

                    let cat = CatFaces.happy.randomElement()!
                    let loadDesc = loadDescription(cogLoad)
                    let fmt = DateFormatter()
                    fmt.dateFormat = "MMM d, h:mm a"
                    let xpEstimate = response.xpPreview ?? (cogLoad * (response.estimatedMinutes ?? 60) / 10)

                    var lines: [String] = [response.reply]
                    lines.append("")
                    lines.append("Cognitive load: \(cogLoad)/10 (\(loadDesc))")
                    lines.append("Deadline: \(fmt.string(from: deadline))")
                    lines.append("Est. \(response.estimatedMinutes ?? 60) min of \(category.rawValue.lowercased())")

                    chatHistory.addMessage(ChatMessage(
                        text: lines.joined(separator: "\n"),
                        isUser: false,
                        cat: cat,
                        xpEarned: xpEstimate,
                        cognitiveLoad: cogLoad,
                        isAIPowered: true
                    ))

                } else {
                    // --- CHAT PATH ---
                    let replyText: String
                    if let r = llmResponse?.reply,
                       !r.trimmingCharacters(in: .whitespaces).hasPrefix("{")
                    {
                        replyText = r
                    } else {
                        replyText = generateFallbackChatResponse(text)
                    }

                    let cat = CatFaces.happy.randomElement()!
                    chatHistory.addMessage(ChatMessage(
                        text: replyText,
                        isUser: false,
                        cat: cat,
                        isAIPowered: llmResponse != nil
                    ))
                }
            }
        }
    }

    // MARK: - Fallback (offline mode with intent detection)

    private func sendWithFallback(_ text: String) {
        let intent = detectLocalIntent(text)

        if intent == "task" {
            // Task creation via CognitiveEngine keyword parsing + time extraction
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
                chatHistory.addMessage(ChatMessage(
                    text: response,
                    isUser: false,
                    cat: cat,
                    xpEarned: xpEstimate,
                    cognitiveLoad: parsed.cognitiveLoad
                ))

                // Recovery cycle / energy warnings
                checkAndSuggestRecovery(afterTaskLoad: parsed.cognitiveLoad)
            }
        } else {
            // Conversational fallback with hardcoded + time-aware responses
            let response = generateFallbackChatResponse(text)
            let cat = CatFaces.happy.randomElement()!

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                chatHistory.addMessage(ChatMessage(
                    text: response,
                    isUser: false,
                    cat: cat
                ))
            }
        }
    }

    // MARK: - Local Intent Detection (for fallback when LLM unavailable)

    private func detectLocalIntent(_ text: String) -> String {
        let lower = text.lowercased()

        // Task-like prefixes
        let taskPrefixes = [
            "i need to ", "i have to ", "i want to ", "i should ",
            "need to ", "have to ", "want to ", "gotta ",
            "finish ", "complete ", "work on ", "study ",
            "prepare ", "submit ", "practice ", "start ",
        ]
        for prefix in taskPrefixes {
            if lower.hasPrefix(prefix) { return "task" }
        }

        // Task-like keywords
        let taskKeywords = [
            "deadline", "due date", "assignment", "homework", "project",
            "exam prep", "quiz prep", "lab report", "problem set",
            "by tomorrow", "by friday", "by monday", "by tuesday",
            "by wednesday", "by thursday", "by saturday", "by sunday",
            "by end of day", "by eod", "by tonight",
        ]
        for keyword in taskKeywords {
            if lower.contains(keyword) { return "task" }
        }

        // Action + subject pattern
        let actionPrefixes = [
            "do ", "make ", "create ", "build ", "implement ", "solve ",
            "debug ", "fix ", "read ", "review ", "write ", "edit ",
        ]
        for prefix in actionPrefixes {
            if lower.hasPrefix(prefix) { return "task" }
        }

        return "chat"
    }

    // MARK: - Hardcoded Chat Responses (time-aware fallback)

    private func generateFallbackChatResponse(_ text: String) -> String {
        let lower = text.lowercased()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())

        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "HH"
        let currentHour = Int(hourFormatter.string(from: Date())) ?? 12

        let timeOfDay: String = {
            switch currentHour {
            case 5..<12: return "morning"
            case 12..<17: return "afternoon"
            case 17..<21: return "evening"
            default: return "night"
            }
        }()

        // Greeting
        if lower.contains("hello") || lower.hasPrefix("hi") || lower.contains("hey") || lower.contains("good morning") || lower.contains("good afternoon") || lower.contains("good evening") {
            return "Hey there! Good \(timeOfDay)! It's \(currentTime) and your energy is at \(Int(profile.currentEnergy))%. \(profile.isPeakHour ? "You're in peak hours — great time for deep work!" : "What would you like to work on?")"
        }

        // How are you / what's up
        if lower.contains("how are you") || lower.contains("what's up") || lower.contains("sup") || lower.contains("how's it going") {
            return "Purring along nicely this \(timeOfDay)! It's \(currentTime) — \(profile.isPeakHour ? "you're in your peak hours, purrfect for deep work!" : "off-peak time, good for lighter tasks.") What can I help with?"
        }

        // Help / capabilities
        if lower.contains("help") || lower.contains("what can you do") || lower.contains("how do you work") || lower.contains("features") {
            return "I help you manage tasks with cognitive load awareness! Tell me something like 'I need to study calculus by Friday' and I'll track it with difficulty ratings, deadlines, and XP. I also monitor your energy and suggest optimal work times."
        }

        // Thanks
        if lower.contains("thank") || lower.contains("thanks") || lower.contains("thx") {
            return "You're welcome! Keep that streak going — \(profile.currentStreak) days strong! It's \(currentTime), \(profile.currentEnergy > 60 ? "and you've got plenty of energy left." : "remember to take care of yourself too.")"
        }

        // Time-related queries
        if lower.contains("what time") || lower.contains("current time") || lower.contains("time is it") {
            return "It's \(currentTime) (\(timeOfDay)). \(profile.isPeakHour ? "You're in peak cognitive hours — great time to tackle hard tasks!" : "Off-peak right now. Consider lighter work or taking a break.")"
        }

        // Energy / status queries
        if lower.contains("energy") || lower.contains("how am i doing") || lower.contains("my status") || lower.contains("my stats") || lower.contains("my level") {
            let taskCount = taskStore.activeTasks.count
            return "Here's your status at \(currentTime):\nEnergy: \(Int(profile.currentEnergy))% | Streak: \(profile.currentStreak) days | Level: \(profile.currentLevel.name) | Active tasks: \(taskCount)\n\(profile.currentEnergy > 60 ? "You're doing great!" : "Take it easy — your energy is running low.")"
        }

        // Schedule request
        if lower.contains("schedule") || lower.contains("plan my day") || lower.contains("plan my time") {
            let busySlots = calendarManager.getBusySlots()
            let schedule = CognitiveEngine.shared.generateDaySchedule(
                tasks: taskStore.activeTasks,
                profile: profile,
                busySlots: busySlots
            )
            if !schedule.isEmpty {
                return CognitiveEngine.shared.formatSchedule(schedule)
            }
            return "No tasks to schedule yet. Add some tasks first and I'll build a burnout-free plan!"
        }

        // Schedule advice / what should I do
        if lower.contains("what should i") || lower.contains("suggest") || lower.contains("recommend") || lower.contains("advice") || lower.contains("what next") || lower.contains("what now") {
            if taskStore.activeTasks.isEmpty {
                return "You don't have any active tasks right now! Tell me what you need to work on and I'll help you plan. It's \(currentTime) — \(profile.isPeakHour ? "prime time for challenging work." : "a good time to plan ahead.")"
            }
            let sorted = CognitiveEngine.shared.suggestSchedule(tasks: taskStore.activeTasks, profile: profile)
            if let top = sorted.first {
                let urgencyNote = top.isUrgent ? " (urgent!)" : ""
                return "At \(currentTime) with \(Int(profile.currentEnergy))% energy, I'd suggest working on \"\(top.title)\" (load: \(top.cognitiveLoad)/10)\(urgencyNote). \(profile.isPeakHour ? "It's peak hour — great time for it!" : "Take it at your own pace.")"
            }
            return "Based on your energy (\(Int(profile.currentEnergy))%) at \(currentTime), I'd suggest \(profile.currentEnergy > 60 ? "tackling your hardest task" : "starting with something light")."
        }

        // Identity / model
        if lower.contains("what model") || lower.contains("what are you") || lower.contains("who are you") || lower.contains("your name") {
            return "I'm CATS — Cognitive-Aware Task Scheduler! I'm currently in offline mode, using built-in smarts for task management. Add an API key in Settings for full AI-powered conversations!"
        }

        // Peak hours
        if lower.contains("peak hour") || lower.contains("best time") || lower.contains("when should") {
            return "Right now it's \(currentTime). \(profile.isPeakHour ? "You're in your peak cognitive hours! This is the best time for demanding work." : "You're off-peak right now. Peak hours are typically morning (9-11 AM) — save your hardest tasks for then.")"
        }

        // Break
        if lower.contains("break") || lower.contains("tired") || lower.contains("exhausted") || lower.contains("rest") {
            return "Taking breaks is smart, not lazy! Your energy is at \(Int(profile.currentEnergy))%. \(profile.currentEnergy < 40 ? "You definitely need one — step away for 10-15 minutes." : "A quick 5-minute stretch can boost focus. You've got this!")"
        }

        // Bye
        if lower.contains("bye") || lower.contains("goodbye") || lower.contains("see you") || lower.contains("later") {
            return "See you later! It's \(currentTime) — \(taskStore.activeTasks.isEmpty ? "enjoy your free time!" : "you have \(taskStore.activeTasks.count) task(s) waiting. Come back when you're ready!") Keep that streak alive!"
        }

        // Default
        return "I'm in offline mode right now (\(currentTime)). I work best with task management — try telling me about a task like 'Study algorithms by Friday'! For full AI chat, add an API key in Settings."
    }

    // MARK: - Schedule Advice

    private func getScheduleAdvice() {
        isThinking = true

        chatHistory.addMessage(ChatMessage(
            text: "Generate my smart schedule",
            isUser: true,
            cat: nil
        ))

        // Generate the intelligent schedule locally (instant, no LLM needed)
        let busySlots = calendarManager.getBusySlots()
        let schedule = CognitiveEngine.shared.generateDaySchedule(
            tasks: taskStore.activeTasks,
            profile: profile,
            busySlots: busySlots
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isThinking = false

            if schedule.isEmpty {
                chatHistory.addMessage(ChatMessage(
                    text: "No tasks to schedule right now. Add some tasks and I'll build you a burnout-free plan!",
                    isUser: false,
                    cat: CatFaces.happy.randomElement()
                ))
                return
            }

            // Show the schedule in chat
            let formatted = CognitiveEngine.shared.formatSchedule(schedule)
            chatHistory.addMessage(ChatMessage(
                text: formatted,
                isUser: false,
                cat: CatFaces.focused.randomElement(),
                isAIPowered: false
            ))

            // Write to calendar if authorized
            if calendarManager.isAuthorized {
                calendarManager.clearTodaySchedule()
                let count = calendarManager.writeScheduleToCalendar(schedule)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    chatHistory.addMessage(ChatMessage(
                        text: "Synced \(count) blocks to your Apple Calendar! You'll get reminders before each session.",
                        isUser: false,
                        cat: CatFaces.happy.randomElement()
                    ))
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    chatHistory.addMessage(ChatMessage(
                        text: "Tip: Grant calendar access in Settings to auto-sync your schedule with Apple Calendar!",
                        isUser: false,
                        cat: CatFaces.focused.randomElement()
                    ))
                }
            }
        }
    }

    // MARK: - Calendar Import

    private func importFromCalendar() {
        if !calendarManager.isAuthorized {
            calendarManager.requestAccess()
            chatHistory.addMessage(ChatMessage(
                text: "Requesting calendar access...",
                isUser: false,
                cat: CatFaces.focused.randomElement()!
            ))
        } else {
            calendarManager.importDeadlinesAsTasks(into: taskStore)
            let count = calendarManager.calendarEvents.count
            chatHistory.addMessage(ChatMessage(
                text: "Scanned \(count) upcoming calendar events and imported relevant deadlines!",
                isUser: false,
                cat: CatFaces.happy.randomElement()!
            ))
        }
    }

    // MARK: - Recovery Cycle Suggestions

    private func checkAndSuggestRecovery(afterTaskLoad: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let cycle = profile.recoveryCycle

            if cycle.needsBreak {
                // Full recovery cycle suggestion
                let activities = cycle.activities.prefix(3).joined(separator: "\n  - ")
                let msg = """
                    \(cycle.type.rawValue) recommended (\(cycle.minutes) min)
                    \(cycle.message)

                    Try:
                      - \(activities)
                    """
                chatHistory.addMessage(ChatMessage(
                    text: msg,
                    isUser: false,
                    cat: CatFaces.stressed.randomElement()
                ))
            } else if profile.currentEnergy < 40 && afterTaskLoad >= 7 {
                // Simple low energy warning
                chatHistory.addMessage(ChatMessage(
                    text: "Heads up — energy at \(Int(profile.currentEnergy))%. This is a heavy task (load \(afterTaskLoad)/10). Consider a lighter task or break first.",
                    isUser: false,
                    cat: CatFaces.stressed.randomElement()
                ))
            } else if profile.consecutiveHighLoadTasks >= 1 && afterTaskLoad >= 7 {
                // Building fatigue warning
                chatHistory.addMessage(ChatMessage(
                    text: "You're stacking heavy tasks (\(profile.consecutiveHighLoadTasks + 1) in a row). Consider mixing in a lighter task to maintain retention.",
                    isUser: false,
                    cat: CatFaces.focused.randomElement()
                ))
            }
        }
    }

    // MARK: - Helpers

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
