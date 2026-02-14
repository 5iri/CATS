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
}

struct ChatInputView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var profile: CognitiveProfile
    @ObservedObject var calendarManager: CalendarManager

    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var showingCalendarImport = false

    var body: some View {
        VStack(spacing: 0) {
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

                TextField("Tell me what you need to do...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .rounded))
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var welcomeMessage: some View {
        VStack(spacing: 8) {
            Text(CatFaces.page.welcome)
                .font(.system(size: 24))

            Text("What do you need to work on?")
                .font(.system(size: 12, weight: .medium, design: .rounded))

            VStack(alignment: .leading, spacing: 4) {
                suggestionChip("I need to finish Graph Theory today")
                suggestionChip("Study Dynamic Programming by Friday")
                suggestionChip("Review notes for tomorrow's quiz")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func suggestionChip(_ text: String) -> some View {
        Button(action: {
            inputText = text
            sendMessage()
        }) {
            Text(text)
                .font(.system(size: 10, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer() }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 2) {
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
            }

            if !msg.isUser { Spacer() }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        messages.append(ChatMessage(text: text, isUser: true, cat: nil))
        inputText = ""

        // Parse and create task
        let parsed = CognitiveEngine.shared.parseNaturalLanguage(text)
        let task = CATSTask(
            title: parsed.title,
            deadline: parsed.deadline,
            cognitiveLoad: parsed.cognitiveLoad,
            estimatedMinutes: parsed.estimatedMinutes,
            category: parsed.category
        )
        taskStore.addTask(task)

        // Write to Apple Calendar
        if calendarManager.isAuthorized {
            if let eventID = calendarManager.writeDeadlineToCalendar(for: task) {
                var updated = task
                updated.calendarEventID = eventID
                taskStore.updateTask(updated)
            }
        }

        // Build response
        let cat = CatFaces.happy.randomElement()!
        let loadDesc: String
        switch parsed.cognitiveLoad {
        case 1...3: loadDesc = "light"
        case 4...6: loadDesc = "moderate"
        case 7...8: loadDesc = "heavy"
        case 9...10: loadDesc = "intense"
        default: loadDesc = "moderate"
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"

        let response = """
            Added "\(parsed.title)"!
            Cognitive load: \(parsed.cognitiveLoad)/10 (\(loadDesc))
            Deadline: \(fmt.string(from: parsed.deadline))
            Est. \(parsed.estimatedMinutes) min of \(parsed.category.rawValue.lowercased())
            """

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            messages.append(ChatMessage(text: response, isUser: false, cat: cat))

            // Suggest scheduling based on energy
            if profile.currentEnergy < 40 && parsed.cognitiveLoad >= 7 {
                let warnCat = CatFaces.stressed.randomElement()!
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    messages.append(ChatMessage(
                        text: "Heads up - your energy is low (\(Int(profile.currentEnergy))%). This is a high-load task. Consider tackling it during peak hours or after a break.",
                        isUser: false,
                        cat: warnCat
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
}
