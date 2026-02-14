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
    // Task fields (present when intent == "task")
    let title: String?
    let cognitiveLoad: Int?
    let loadReasoning: String?
    let estimatedMinutes: Int?
    let category: String?
    let deadlineDescription: String?
    let difficultyBadge: String?
    let xpPreview: Int?
    // Always present
    let reply: String
}

// MARK: - OpenRouter Service

class OpenRouterService: ObservableObject {
    static let shared = OpenRouterService()

    static let defaultModel = "stepfun/step-3.5-flash:free"

    @PublishedPersist(key: "cats_openrouter_api_key2", defaultValue: "")
    var apiKey: String

    @PublishedPersist(key: "cats_openrouter_model2", defaultValue: "stepfun/step-3.5-flash:free")
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
        ("stepfun/step-3.5-flash:free", "Step 3.5 Flash", "Free"),
        ("openai/gpt-4.1-nano", "GPT-4.1 Nano", "Fast"),
        ("openai/gpt-4.1-mini", "GPT-4.1 Mini", "Balanced"),
        ("openai/gpt-4.1", "GPT-4.1", "Smart"),
        ("anthropic/claude-3.5-haiku", "Claude 3.5 Haiku", "Fast"),
        ("anthropic/claude-3.7-sonnet", "Claude 3.7 Sonnet", "Smart"),
        ("google/gemini-2.0-flash-001", "Gemini 2.0 Flash", "Fast"),
        ("google/gemini-2.5-pro-preview", "Gemini 2.5 Pro", "Smart"),
        ("deepseek/deepseek-chat-v3-0324", "DeepSeek V3", "Balanced"),
    ]

    private init() {}

    // MARK: - Unified Chat (detects intent: task vs conversation)

    func sendChat(
        _ input: String,
        energy: Double,
        peakHour: Bool,
        existingTasks: [CATSTask],
        streak: Int,
        level: String
    ) async throws -> LLMChatResponse {
        let taskContext = existingTasks.prefix(5).map { task in
            "- \(task.title) (load: \(task.cognitiveLoad)/10, due: \(task.timeRemainingFormatted))"
        }.joined(separator: "\n")

        let systemPrompt = """
            You are CATS (Cognitive-Aware Task Scheduler), a gamified AI study buddy living in a \
            macOS Dynamic Island. You're a friendly cat-themed productivity assistant that helps \
            students manage cognitive load and study sessions.

            The user's current state:
            - Energy: \(Int(energy))%\(peakHour ? " (PEAK HOUR - optimal for hard tasks!)" : "")
            - Streak: \(streak) days
            - Level: \(level)
            \(taskContext.isEmpty ? "- No existing tasks" : "- Current tasks:\n\(taskContext)")

            IMPORTANT: First determine the user's INTENT:
            - If they want to ADD A TASK (e.g. "I need to finish X", "study Y by Friday", "work on Z"), \
            set intent to "task" and fill in ALL task fields.
            - If they're asking a QUESTION or CHATTING (e.g. "what model are you", "how are you", \
            "what should I do", "help", "thanks"), set intent to "chat" and just reply conversationally.

            Respond ONLY with valid JSON (no markdown, no code fences):
            {
              "intent": "task" or "chat",
              "title": "Task title" or null,
              "cognitiveLoad": 1-10 or null,
              "loadReasoning": "Why this load rating" or null,
              "estimatedMinutes": 30-120 or null,
              "category": "deepWork|lightWork|review|creative" or null,
              "deadlineDescription": "today|tomorrow|by friday|etc" or null,
              "difficultyBadge": "Fun 2-3 word badge" or null,
              "xpPreview": estimated_xp or null,
              "reply": "Your response message to the user (ALWAYS required, keep it short and fun)"
            }

            For chat intent: be helpful, witty, cat-themed. You ARE the CATS app. If asked what model \
            you are, say you're CATS powered by AI. Keep replies under 2-3 sentences.
            For task intent: the reply should confirm the task was added with encouragement.
            """

        let response = try await sendRequest(
            systemPrompt: systemPrompt,
            userMessage: input,
            maxTokens: 500
        )

        guard let data = response.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(LLMChatResponse.self, from: data)
        else {
            // If JSON parsing fails, treat raw text as a chat response
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
                reply: response
            )
        }

        return parsed
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
            "temperature": 0.7,
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
