import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    var role: String
    var content: String
    var isLoading: Bool = false
    var isError: Bool = false
}

struct TaskCreationResult {
    var title: String
    var workType: WorkType
    var hours: Int
    var minutes: Int
    var seconds: Int
    var cognitiveLoad: Int
}

enum APIKeyStatus {
    case empty
    case checking
    case valid
    case invalid
}

class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var apiKeyStatus: APIKeyStatus = .empty

    private let settingsManager: SettingsManager
    private var conversationHistory: [(role: String, content: String)] = []

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        apiKeyStatus = settingsManager.apiKey.isEmpty ? .empty : .invalid

        OpenRouterService.shared.apiKey = settingsManager.apiKey
        OpenRouterService.shared.model  = settingsManager.selectedModel

        messages.append(ChatMessage(
            role: "assistant",
            content: settingsManager.apiKey.isEmpty
                ? "Meow! (=^･ω･^=) Add an OpenRouter API key in Settings (⚙) to unlock AI features!"
                : "Meow! (=^･ω･^=) I'm CATS! Tell me what you need to get done and I'll schedule it!"
        ))
    }

    // MARK: - Key Validation

    func validateAndSaveKey(_ rawKey: String, completion: @escaping (APIKeyStatus) -> Void) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            settingsManager.apiKey = ""
            OpenRouterService.shared.apiKey = ""
            apiKeyStatus = .empty
            appendSystemMessage("⚠️ No API key entered. Get one free at openrouter.ai!")
            completion(.empty)
            return
        }

        apiKeyStatus = .checking

        var req = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        req.httpMethod = "GET"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0

                if error == nil && code == 200 {
                    self.settingsManager.apiKey = key
                    OpenRouterService.shared.apiKey = key
                    OpenRouterService.shared.model  = self.settingsManager.selectedModel
                    self.apiKeyStatus = .valid
                    self.appendSystemMessage(
                        "✅ Connected! Ready using \(self.settingsManager.selectedModel). Tell me what to schedule!"
                    )
                    completion(.valid)
                } else {
                    self.apiKeyStatus = .invalid
                    let hint = code == 401
                        ? "Key rejected (401). Double-check it at openrouter.ai."
                        : error != nil
                            ? "Network error: \(error!.localizedDescription)"
                            : "Unexpected response (HTTP \(code))."
                    self.appendSystemMessage("❌ Incorrect API key — \(hint)")
                    completion(.invalid)
                }
            }
        }.resume()
    }

    // MARK: - Send Message

    func sendMessage(
        _ userText: String,
        activeTasks: [ScheduledTask],      // ← uses ScheduledTask to avoid collision with Swift.Task
        energyPercentage: Int,
        onTaskCreate: @escaping (TaskCreationResult) -> Void
    ) {
        let text = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(role: "user", content: text))
        conversationHistory.append((role: "user", content: text))

        guard apiKeyStatus == .valid else {
            appendSystemMessage(
                apiKeyStatus == .empty
                    ? "⚠️ No API key set. Go to Settings (⚙) and add your OpenRouter key."
                    : "❌ API key invalid. Go to Settings (⚙) to fix it.",
                isError: true
            )
            return
        }

        isLoading = true
        messages.append(ChatMessage(role: "assistant", content: "", isLoading: true))

        // Sync model from settings before every API call
        OpenRouterService.shared.model = settingsManager.selectedModel

        let proxies = activeTasks.map {
            CATSTaskProxy(
                title: $0.title,
                cognitiveLoad: $0.loadPoints,
                timeRemainingFormatted: $0.duration,
                category: $0.workType == .deep ? "deepWork" : "lightWork"
            )
        }

        let isPeakHour: Bool = {
            let h = Calendar.current.component(.hour, from: Date())
            return (h >= 9 && h <= 12) || (h >= 14 && h <= 17)
        }()

        Task {
            do {
                let response = try await OpenRouterService.shared.sendChatProxy(
                    input: text,
                    energy: Double(energyPercentage),
                    peakHour: isPeakHour,
                    existingTasks: proxies,
                    conversationHistory: conversationHistory
                )

                await MainActor.run {
                    self.isLoading = false
                    self.messages.removeAll { $0.isLoading }
                    self.conversationHistory.append((role: "assistant", content: response.reply))

                    if response.intent == "task", let title = response.title {
                        let minutes = response.estimatedMinutes ?? 30
                        let wt: WorkType = {
                            switch response.category ?? "" {
                            case "deepWork", "creative": return .deep
                            default:                     return .light
                            }
                        }()
                        onTaskCreate(TaskCreationResult(
                            title:         title,
                            workType:      wt,
                            hours:         minutes / 60,
                            minutes:       minutes % 60,
                            seconds:       0,
                            cognitiveLoad: response.cognitiveLoad ?? 5
                        ))
                    }

                    self.messages.append(ChatMessage(
                        role: "assistant",
                        content: response.reply
                    ))
                }
            } catch let err as OpenRouterError {
                await MainActor.run {
                    self.isLoading = false
                    self.messages.removeAll { $0.isLoading }
                    if case .authError = err { self.apiKeyStatus = .invalid }
                    self.appendSystemMessage("Error: \(err.localizedDescription)", isError: true)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.messages.removeAll { $0.isLoading }
                    self.appendSystemMessage(
                        "Network error: \(error.localizedDescription)", isError: true
                    )
                }
            }
        }
    }

    private func appendSystemMessage(_ text: String, isError: Bool = false) {
        messages.append(ChatMessage(role: "assistant", content: text, isError: isError))
    }
}
