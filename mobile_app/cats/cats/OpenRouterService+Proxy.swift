//
//  OpenRouterService+Proxy.swift
//  cats
//
//  CATSTaskProxy is defined HERE and only here.
//  ChatManager imports this type — do NOT redeclare it in ChatManager.swift.
//

import Foundation

// MARK: - Proxy type (keeps ChatManager independent of the macOS CATSTask)

struct CATSTaskProxy {
    let title: String
    let cognitiveLoad: Int
    let timeRemainingFormatted: String
    let category: String   // "deepWork" | "lightWork" | "review" | "creative"
}

// MARK: - OpenRouterService mobile extension

extension OpenRouterService {

    func sendChatProxy(
        input: String,
        energy: Double,
        peakHour: Bool,
        existingTasks: [CATSTaskProxy],
        conversationHistory: [(role: String, content: String)] = []
    ) async throws -> LLMChatResponse {

        let taskContext = existingTasks.prefix(5).map {
            "- \($0.title) (load: \($0.cognitiveLoad)/10, est: \($0.timeRemainingFormatted))"
        }.joined(separator: "\n")

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEEE, MMM d yyyy, h:mm a"
        let nowString = dateFmt.string(from: Date())

        let systemPrompt = """
            You are CATS, a cat-themed cognitive task scheduler on iOS. \
            Current time: \(nowString). \
            User energy: \(Int(energy))%. \
            \(peakHour ? "PEAK HOUR — great for hard tasks." : "Off-peak — lighter tasks preferred.")
            \(taskContext.isEmpty ? "" : "Current tasks:\n\(taskContext)")

            Reply with ONLY raw JSON. No markdown. No code fences. No extra text.

            If the user wants to ADD A TASK reply EXACTLY like this:
            {"intent":"task","title":"Study Calculus","cognitiveLoad":7,"estimatedMinutes":60,"category":"deepWork","reply":"Added Study Calculus — 60 min deep work. You've got this! (=^･ω･^=)"}

            If the user is CHATTING reply EXACTLY like this:
            {"intent":"chat","reply":"Hey there! Ready to help you plan! (=^･ω･^=)"}

            Rules:
            - cognitiveLoad must be a plain integer 1-10
            - estimatedMinutes must be a single plain integer, never a range like 60-90
            - category is one of: deepWork | lightWork | review | creative
            - reply must always be present, friendly, and cat-themed
            """

        var messages: [(role: String, content: String)] = [("system", systemPrompt)]
        messages.append(contentsOf: conversationHistory.suffix(10))
        messages.append(("user", input))

        let raw = try await sendRequestWithMessages(messages: messages, maxTokens: 300)

        // Layer 1: standard JSONDecoder
        let sanitized = LLMChatResponse.sanitizeJSON(raw)
        if let data = sanitized.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(LLMChatResponse.self, from: data) {
            return parsed
        }

        // Layer 2: lenient manual parse
        if let parsed = LLMChatResponse.parseManually(from: raw) {
            return parsed
        }

        // Layer 3: regex-extract reply only
        let fallback = LLMChatResponse.extractReplyFromRaw(raw)
            ?? "I'm here! Try asking me to add a task. (=^･ω･^=)"

        return LLMChatResponse(
            intent: "chat",
            title: nil,
            cognitiveLoad: nil,
            loadReasoning: nil,
            estimatedMinutes: nil,
            category: nil,
            deadlineDescription: nil,
            difficultyBadge: nil,
            xpPreview: nil,
            reply: fallback
        )
    }
}
