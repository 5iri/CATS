//
//  OpenRouterService.swift
//  CATS - Cognitive-Aware Task Scheduler
//
//  LLM integration via OpenRouter (OpenAI-compatible API)
//

import Combine
import Foundation

// MARK: - Response Models

struct LLMChatResponse: Codable {
    let intent: String // "task" or "chat"
    let title: String?
    let cognitiveLoad: Int?
    let loadReasoning: String?
    let estimatedMinutes: Int?
    let category: String?
    let deadlineDescription: String? // LLM may send as "deadline" or "deadlineDescription"
    let difficultyBadge: String?
    let xpPreview: Int?
    let reply: String

    // MARK: - Memberwise init

    init(
        intent: String,
        title: String?,
        cognitiveLoad: Int?,
        loadReasoning: String?,
        estimatedMinutes: Int?,
        category: String?,
        deadlineDescription: String?,
        difficultyBadge: String?,
        xpPreview: Int?,
        reply: String
    ) {
        self.intent = intent
        self.title = title
        self.cognitiveLoad = cognitiveLoad
        self.loadReasoning = loadReasoning
        self.estimatedMinutes = estimatedMinutes
        self.category = category
        self.deadlineDescription = deadlineDescription
        self.difficultyBadge = difficultyBadge
        self.xpPreview = xpPreview
        self.reply = reply
    }

    // MARK: - Flexible Codable (handles LLM type mismatches & key aliases)

    enum CodingKeys: String, CodingKey {
        case intent, title, cognitiveLoad, loadReasoning, estimatedMinutes
        case category, deadlineDescription, deadline, difficultyBadge, xpPreview, reply
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intent, forKey: .intent)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(cognitiveLoad, forKey: .cognitiveLoad)
        try container.encodeIfPresent(loadReasoning, forKey: .loadReasoning)
        try container.encodeIfPresent(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(deadlineDescription, forKey: .deadlineDescription)
        try container.encodeIfPresent(difficultyBadge, forKey: .difficultyBadge)
        try container.encodeIfPresent(xpPreview, forKey: .xpPreview)
        try container.encode(reply, forKey: .reply)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intent = (try? container.decode(String.self, forKey: .intent)) ?? "chat"
        title = try? container.decode(String.self, forKey: .title)
        cognitiveLoad = Self.decodeFlexibleInt(container: container, key: .cognitiveLoad)
        loadReasoning = try? container.decode(String.self, forKey: .loadReasoning)
        estimatedMinutes = Self.decodeFlexibleInt(container: container, key: .estimatedMinutes)
        category = try? container.decode(String.self, forKey: .category)
        // Accept both "deadline" and "deadlineDescription" keys
        deadlineDescription = (try? container.decode(String.self, forKey: .deadlineDescription))
            ?? (try? container.decode(String.self, forKey: .deadline))
        difficultyBadge = try? container.decode(String.self, forKey: .difficultyBadge)
        xpPreview = Self.decodeFlexibleInt(container: container, key: .xpPreview)
        reply = (try? container.decode(String.self, forKey: .reply)) ?? "Got it!"
    }

    /// Decode a field that should be Int but might be String (e.g. "15 XP") or Double
    private static func decodeFlexibleInt(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        if let val = try? container.decode(Int.self, forKey: key) { return val }
        if let val = try? container.decode(Double.self, forKey: key) { return Int(val) }
        if let str = try? container.decode(String.self, forKey: key) {
            return extractFirstInt(from: str)
        }
        return nil
    }

    /// Extract the first integer from a string like "15 XP" or "60 minutes"
    private static func extractFirstInt(from string: String) -> Int? {
        let parts = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for part in parts where !part.isEmpty {
            if let i = Int(part) { return i }
        }
        return nil
    }

    // MARK: - Sanitize raw LLM JSON (fix common issues before parsing)

    /// Fix invalid JSON patterns that LLMs commonly produce
    static func sanitizeJSON(_ raw: String) -> String {
        var s = raw

        // Fix bare number ranges like 60-90 → 60 (outside of quoted strings)
        // Pattern: colon, optional whitespace, digits, hyphen, digits (not inside quotes)
        if let regex = try? NSRegularExpression(pattern: #"(?<=:\s{0,4})(\d+)\s*-\s*(\d+)(?=\s*[,\}\]])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }

        // Fix trailing commas before } or ]
        if let regex = try? NSRegularExpression(pattern: #",(\s*[\}\]])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }

        return s
    }

    // MARK: - Manual parsing via JSONSerialization (most lenient)

    /// Best-effort parse from a raw JSON string using JSONSerialization
    static func parseManually(from raw: String) -> LLMChatResponse? {
        let sanitized = sanitizeJSON(raw)
        guard let data = sanitized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let reply = json["reply"] as? String else { return nil }

        return LLMChatResponse(
            intent: json["intent"] as? String ?? "chat",
            title: json["title"] as? String,
            cognitiveLoad: flexibleInt(json["cognitiveLoad"]),
            loadReasoning: json["loadReasoning"] as? String,
            estimatedMinutes: flexibleInt(json["estimatedMinutes"]),
            category: json["category"] as? String,
            deadlineDescription: (json["deadlineDescription"] as? String) ?? (json["deadline"] as? String),
            difficultyBadge: json["difficultyBadge"] as? String,
            xpPreview: flexibleInt(json["xpPreview"]),
            reply: reply
        )
    }

    /// Flexible int extraction from Any value
    private static func flexibleInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String { return extractFirstInt(from: s) }
        return nil
    }

    // MARK: - Last-resort reply extraction via regex

    /// Extract just the "reply" value from raw text even if JSON is totally broken
    static func extractReplyFromRaw(_ raw: String) -> String? {
        // Match "reply" : "..." handling escaped quotes inside
        guard let regex = try? NSRegularExpression(
            pattern: #""reply"\s*:\s*"((?:[^"\\]|\\.)*)""#
        ) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let captureRange = Range(match.range(at: 1), in: raw)
        else { return nil }
        return String(raw[captureRange])
            .replacingOccurrences(of: #"\""#, with: "\"")
            .replacingOccurrences(of: #"\n"#, with: "\n")
    }
}

// MARK: - OpenRouter Service

class OpenRouterService: ObservableObject {
    static let shared = OpenRouterService()

    static let defaultModel = "liquid/lfm-2.2-6b"

    @PublishedPersist(key: "cats_openrouter_api_key2", defaultValue: "")
    var apiKey: String

    @PublishedPersist(key: "cats_openrouter_model2", defaultValue: "liquid/lfm-2.2-6b")
    var model: String

    @Published var isProcessing: Bool = false
    @Published var lastError: String?

    /// The actual key to use — user must provide their own key in Settings
    var effectiveAPIKey: String { apiKey }

    /// The actual model to use
    var effectiveModel: String {
        let m = model
        return m.isEmpty ? Self.defaultModel : m
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"

    static let availableModels: [(id: String, name: String, tier: String)] = [
        ("liquid/lfm-2.2-6b", "LFM 2.2 6B", "Default"),
    ]

    private init() {}

    // MARK: - Unified Chat (detects intent: task vs conversation)

    func sendChat(
        _ input: String,
        energy: Double,
        peakHour: Bool,
        existingTasks: [CATSTask],
        streak: Int,
        level: String,
        conversationHistory: [(role: String, content: String)] = [],
        calendarEvents: [String] = [],
        fatigueSequence: Bool = false,
        optimalLoadRange: String = "5-8"
    ) async throws -> LLMChatResponse {
        let taskContext = existingTasks.prefix(5).map { task in
            "- \(task.title) (load: \(task.cognitiveLoad)/10, due: \(task.timeRemainingFormatted))"
        }.joined(separator: "\n")

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEEE, MMM d yyyy, h:mm a"
        let nowString = dateFmt.string(from: Date())

        let calendarContext = calendarEvents.isEmpty ? "" : " Upcoming calendar: \(calendarEvents.prefix(5).joined(separator: "; "))."

        let systemPrompt = """
            You are CATS, a cat-themed study buddy. Current time: \(nowString). \
            User energy: \(Int(energy))%. Streak: \(streak) days. Level: \(level). \
            Optimal cognitive load range now: \(optimalLoadRange).\
            \(peakHour ? " PEAK HOUR — best for hard tasks." : "")\
            \(fatigueSequence ? " WARNING: User is in a fatigue sequence, suggest lighter work or a break." : "")\
            \(taskContext.isEmpty ? "" : " Tasks: \(taskContext)")\
            \(calendarContext)

            Reply with ONLY raw JSON. No markdown. No code fences.

            If user wants to ADD A TASK, reply EXACTLY like this example:
            {"intent":"task","title":"Study Calculus","cognitiveLoad":7,"estimatedMinutes":60,"category":"deepWork","deadline":"today","reply":"Let's crush calculus!"}

            If user is CHATTING, reply EXACTLY like this example:
            {"intent":"chat","reply":"Hey! Ready to help you study!"}

            Rules: cognitiveLoad 1-10 integer (use the optimal range as guide). \
            estimatedMinutes single integer. \
            category: deepWork, lightWork, review, or creative. \
            deadline: today, tomorrow, or a weekday name. reply is always required. \
            All numbers must be plain integers like 60, never ranges like 60-90.
            """

        // Build multi-turn messages with conversation history
        var messages: [(role: String, content: String)] = [
            ("system", systemPrompt),
        ]

        // Append recent conversation history for context (last 10 turns)
        let recentHistory = Array(conversationHistory.suffix(10))
        messages.append(contentsOf: recentHistory)

        // Append current user message
        messages.append(("user", input))

        let raw = try await sendRequestWithMessages(
            messages: messages,
            maxTokens: 500
        )

        // Layer 1: Try standard JSONDecoder on sanitized JSON
        let sanitized = LLMChatResponse.sanitizeJSON(raw)
        if let data = sanitized.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(LLMChatResponse.self, from: data)
        {
            return parsed
        }

        // Layer 2: Try manual parsing via JSONSerialization (handles type mismatches)
        if let parsed = LLMChatResponse.parseManually(from: raw) {
            return parsed
        }

        // Layer 3: Extract just the reply field via regex (totally broken JSON)
        let fallbackReply = LLMChatResponse.extractReplyFromRaw(raw) ?? raw

        // If the fallback reply IS the raw JSON, don't show it — give a clean message
        let isRawJSON = fallbackReply.trimmingCharacters(in: .whitespaces).hasPrefix("{")
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
            reply: isRawJSON ? "I understood your request, but had trouble formatting my response. Please try again!" : fallbackReply
        )
    }

    // MARK: - Schedule Advice via LLM

    func getScheduleAdvice(
        tasks: [CATSTask],
        energy: Double,
        peakHour: Bool,
        fatigue: Double,
        deepWorkMinutes: Int
    ) async throws -> String {
        let taskList = tasks.map { task in
            "- \(task.title): load \(task.cognitiveLoad)/10, due \(task.timeRemainingFormatted), \(task.category.rawValue)"
        }.joined(separator: "\n")

        let systemPrompt = """
            You are CATS, a cognitive-aware task scheduling AI. Based on the user's mental state \
            and task list, give a brief (2-3 sentences) scheduling suggestion. Be specific about \
            which task to do NOW and why. Use cat personality. No JSON, just plain text.

            User state: Energy \(Int(energy))%, Fatigue \(Int(fatigue))%, \
            \(peakHour ? "Peak Hour" : "Off-Peak"), \(deepWorkMinutes)min deep work today.

            Tasks:
            \(taskList.isEmpty ? "No tasks" : taskList)
            """

        let response = try await sendRequest(
            systemPrompt: systemPrompt,
            userMessage: "What should I work on right now?",
            maxTokens: 200
        )

        return response
    }

    // MARK: - HTTP Layer

    private func sendRequest(systemPrompt: String, userMessage: String, maxTokens: Int) async throws -> String {
        let messages = [
            ("system", systemPrompt),
            ("user", userMessage),
        ]
        return try await sendRequestWithMessages(messages: messages, maxTokens: maxTokens)
    }

    private func sendRequestWithMessages(messages: [(role: String, content: String)], maxTokens: Int) async throws -> String {
        guard isConfigured else {
            throw OpenRouterError.notConfigured
        }

        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(effectiveAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("CATS/2.0", forHTTPHeaderField: "X-Title")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": effectiveModel,
            "messages": messages.map { ["role": $0.0, "content": $0.1] },
            "max_tokens": maxTokens,
            "temperature": 0.3,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw OpenRouterError.authError("Invalid API key. Check your OpenRouter key in Settings.")
            }
            if httpResponse.statusCode == 429 {
                throw OpenRouterError.rateLimited("Rate limited. Wait a moment and try again.")
            }
            throw OpenRouterError.apiError(httpResponse.statusCode, errorBody)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw OpenRouterError.parseError("Could not extract response content")
        }

        // Clean up: strip markdown code fences if the LLM wrapped JSON in them
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}

// MARK: - Errors

enum OpenRouterError: LocalizedError {
    case notConfigured
    case authError(String)
    case rateLimited(String)
    case networkError(String)
    case apiError(Int, String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OpenRouter API key not set. Add it in Settings."
        case .authError(let msg), .rateLimited(let msg),
             .networkError(let msg), .parseError(let msg):
            return msg
        case .apiError(let code, let msg):
            return "API error (\(code)): \(msg)"
        }
    }
}
