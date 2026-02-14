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
    let intent: String
    let title: String?
    let cognitiveLoad: Int?
    let loadReasoning: String?
    let estimatedMinutes: Int?
    let category: String?
    let deadlineDescription: String?
    let difficultyBadge: String?
    let xpPreview: Int?
    let reply: String

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
        deadlineDescription = (try? container.decode(String.self, forKey: .deadlineDescription))
            ?? (try? container.decode(String.self, forKey: .deadline))
        difficultyBadge = try? container.decode(String.self, forKey: .difficultyBadge)
        xpPreview = Self.decodeFlexibleInt(container: container, key: .xpPreview)
        reply = (try? container.decode(String.self, forKey: .reply)) ?? "Got it!"
    }

    private static func decodeFlexibleInt(
        container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int? {
        if let val = try? container.decode(Int.self, forKey: key) { return val }
        if let val = try? container.decode(Double.self, forKey: key) { return Int(val) }
        if let str = try? container.decode(String.self, forKey: key) {
            return extractFirstInt(from: str)
        }
        return nil
    }

    private static func extractFirstInt(from string: String) -> Int? {
        let parts = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for part in parts where !part.isEmpty {
            if let i = Int(part) { return i }
        }
        return nil
    }

    static func sanitizeJSON(_ raw: String) -> String {
        var s = raw
        if let regex = try? NSRegularExpression(
            pattern: #"(?<=:\s{0,4})(\d+)\s*-\s*(\d+)(?=\s*[,\}\]])"#
        ) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        if let regex = try? NSRegularExpression(pattern: #",(\s*[\}\]])"#) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "$1")
        }
        return s
    }

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
            deadlineDescription: (json["deadlineDescription"] as? String)
                ?? (json["deadline"] as? String),
            difficultyBadge: json["difficultyBadge"] as? String,
            xpPreview: flexibleInt(json["xpPreview"]),
            reply: reply
        )
    }

    private static func flexibleInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String { return extractFirstInt(from: s) }
        return nil
    }

    static func extractReplyFromRaw(_ raw: String) -> String? {
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

// MARK: - PublishedPersist Property Wrapper

@propertyWrapper
class PublishedPersist<Value> {
    private let key: String
    private let defaultValue: Value
    private var subject = PassthroughSubject<Value, Never>()

    var wrappedValue: Value {
        get { UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            subject.send(newValue)
        }
    }

    var projectedValue: AnyPublisher<Value, Never> {
        subject.eraseToAnyPublisher()
    }

    init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }

    /// Tells SwiftUI / Combine to fire `objectWillChange` on the enclosing ObservableObject.
    static subscript<EnclosingSelf: ObservableObject>(
        _enclosingInstance instance: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, PublishedPersist<Value>>
    ) -> Value where EnclosingSelf.ObjectWillChangePublisher == ObservableObjectPublisher {
        get {
            instance[keyPath: storageKeyPath].wrappedValue
        }
        set {
            (instance.objectWillChange as ObservableObjectPublisher).send()
            instance[keyPath: storageKeyPath].wrappedValue = newValue
        }
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

    var effectiveAPIKey: String { apiKey }

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

    // MARK: - Unified Chat

    func sendChat(
        _ input: String,
        energy: Double,
        peakHour: Bool,
        existingTasks: [CATSTaskProxy],
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

        let calendarContext = calendarEvents.isEmpty
            ? ""
            : " Upcoming calendar: \(calendarEvents.prefix(5).joined(separator: "; "))."

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

            Rules: cognitiveLoad 1-10 integer. estimatedMinutes single integer. \
            category: deepWork, lightWork, review, or creative. \
            deadline: today, tomorrow, or a weekday name. reply is always required. \
            All numbers must be plain integers like 60, never ranges like 60-90.
            """

        var messages: [(role: String, content: String)] = [("system", systemPrompt)]
        messages.append(contentsOf: Array(conversationHistory.suffix(10)))
        messages.append(("user", input))

        let raw = try await sendRequestWithMessages(messages: messages, maxTokens: 500)

        let sanitized = LLMChatResponse.sanitizeJSON(raw)
        if let data = sanitized.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(LLMChatResponse.self, from: data) {
            return parsed
        }
        if let parsed = LLMChatResponse.parseManually(from: raw) {
            return parsed
        }
        let fallbackReply = LLMChatResponse.extractReplyFromRaw(raw) ?? raw
        let isRawJSON = fallbackReply.trimmingCharacters(in: .whitespaces).hasPrefix("{")
        return LLMChatResponse(
            intent: "chat", title: nil, cognitiveLoad: nil, loadReasoning: nil,
            estimatedMinutes: nil, category: nil, deadlineDescription: nil,
            difficultyBadge: nil, xpPreview: nil,
            reply: isRawJSON
                ? "I understood your request, but had trouble formatting my response. Please try again!"
                : fallbackReply
        )
    }

    // MARK: - Schedule Advice

    func getScheduleAdvice(
        tasks: [CATSTaskProxy],
        energy: Double,
        peakHour: Bool,
        fatigue: Double,
        deepWorkMinutes: Int
    ) async throws -> String {
        let taskList = tasks.map { task in
            "- \(task.title): load \(task.cognitiveLoad)/10, due \(task.timeRemainingFormatted), \(task.category)"
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

        return try await sendRequest(
            systemPrompt: systemPrompt,
            userMessage: "What should I work on right now?",
            maxTokens: 200
        )
    }

    // MARK: - HTTP Layer

    private func sendRequest(
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int
    ) async throws -> String {
        let messages = [("system", systemPrompt), ("user", userMessage)]
        return try await sendRequestWithMessages(messages: messages, maxTokens: maxTokens)
    }

    // ↓↓ ONLY CHANGE FROM ORIGINAL: removed `private` so the proxy extension can call it ↓↓
    func sendRequestWithMessages(
        messages: [(role: String, content: String)],
        maxTokens: Int
    ) async throws -> String {
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

        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
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
