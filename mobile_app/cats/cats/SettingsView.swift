import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var chatManager: ChatManager
    @Environment(\.dismiss) var dismiss

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var showingResetConfirmation = false
    @State private var selectedModel = "liquid/lfm-2.2-6b"

    let availableModels: [(String, String)] = [
        ("liquid/lfm-2.2-6b",                        "LFM 2.2 6B (Default)"),
        ("meta-llama/llama-3.2-3b-instruct:free",    "Llama 3.2 3B (Free)"),
        ("meta-llama/llama-3.3-70b-instruct:free",   "Llama 3.3 70B (Free)"),
        ("microsoft/phi-3-mini-128k-instruct:free",  "Phi-3 Mini (Free)"),
        ("google/gemma-3-4b-it:free",                "Gemma 3 4B (Free)"),
        ("qwen/qwen3-4b:free",                       "Qwen3 4B (Free)"),
        ("deepseek/deepseek-r1:free",                "DeepSeek R1 (Free)")
    ]

    var selectedModelLabel: String {
        availableModels.first { $0.0 == selectedModel }?.1 ?? "Select"
    }

    // ── Derived purely from chatManager.apiKeyStatus ──
    var dotColor: Color {
        switch chatManager.apiKeyStatus {
        case .valid:              return .green
        case .invalid:            return .red
        case .empty, .checking:   return .gray
        }
    }

    var statusLabel: String {
        switch chatManager.apiKeyStatus {
        case .valid:    return "Connected"
        case .invalid:  return "Invalid key"
        case .checking: return "Checking..."
        case .empty:    return "Not connected"
        }
    }

    var isSaveDisabled: Bool {
        apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || chatManager.apiKeyStatus == .checking
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── HEADER ──
                HStack(spacing: 8) {
                    Text("(=^･ω･^=)")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").foregroundColor(.yellow).font(.system(size: 11))
                        Text("\(settingsManager.totalXP)")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill").foregroundColor(.green).font(.system(size: 11))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 44, height: 5)
                            Capsule().fill(Color.green).frame(width: 44, height: 5)
                        }
                        Text("100%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .fixedSize()
                    }

                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray).font(.system(size: 20))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider().background(Color(white: 0.12))

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── AI ENGINE ──
                        SettingsSectionHeader(icon: "sparkles", title: "AI Engine")

                        VStack(alignment: .leading, spacing: 14) {

                            // Status row — NEVER shows Connected until validated
                            HStack {
                                Text("OpenRouter API Key")
                                    .font(.system(size: 14)).foregroundColor(.white)
                                Spacer()
                                if chatManager.apiKeyStatus == .checking {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                        .scaleEffect(0.7)
                                } else {
                                    Circle().fill(dotColor).frame(width: 7, height: 7)
                                }
                                Text(statusLabel)
                                    .font(.system(size: 12))
                                    .foregroundColor(dotColor)
                                    .animation(.easeInOut(duration: 0.25), value: chatManager.apiKeyStatus == .valid)
                            }

                            // Key field + Save button
                            HStack(spacing: 10) {
                                Group {
                                    if showingAPIKey {
                                        TextField("sk-or-v1-...", text: $apiKeyInput)
                                    } else {
                                        SecureField("sk-or-v1-...", text: $apiKeyInput)
                                    }
                                }
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)

                                Button(action: { showingAPIKey.toggle() }) {
                                    Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.gray).font(.system(size: 15))
                                }

                                // Save → validates key → updates chatManager.apiKeyStatus
                                Button(action: {
                                    UIApplication.shared.sendAction(
                                        #selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil
                                    )
                                    chatManager.validateAndSaveKey(apiKeyInput) { _ in }
                                }) {
                                    Text("Save")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(isSaveDisabled ? .gray : .blue)
                                }
                                .disabled(isSaveDisabled)
                            }
                            .padding(12)
                            .background(Color(white: 0.12))
                            .cornerRadius(10)

                            // Validation feedback banner
                            Group {
                                switch chatManager.apiKeyStatus {
                                case .valid:
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green).font(.system(size: 12))
                                        Text("Key verified — AI features active!")
                                            .font(.system(size: 12)).foregroundColor(.green)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)

                                case .invalid:
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red).font(.system(size: 12))
                                        Text("Incorrect or rejected key. Check it at openrouter.ai")
                                            .font(.system(size: 12)).foregroundColor(.red)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)

                                case .empty, .checking:
                                    Text("Get a free key at openrouter.ai — many models are free!")
                                        .font(.system(size: 12)).foregroundColor(.gray)
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: chatManager.apiKeyStatus == .valid)

                            // Model picker
                            HStack {
                                Text("Model").font(.system(size: 14)).foregroundColor(.gray)
                                Spacer()
                                Menu {
                                    ForEach(availableModels, id: \.0) { m in
                                        Button(m.1) {
                                            selectedModel = m.0
                                            settingsManager.selectedModel = m.0
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(selectedModelLabel)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white).lineLimit(1)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10)).foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color(white: 0.15)).cornerRadius(8)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(white: 0.07))

                        Divider().background(Color(white: 0.12))

                        // ── GENERAL ──
                        SettingsSectionHeader(icon: "gearshape", title: "General")

                        VStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Text("Language:").font(.system(size: 14)).foregroundColor(.white)
                                Menu {
                                    Button("English") {}
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("English").font(.system(size: 13)).foregroundColor(.white)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10)).foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color(white: 0.15)).cornerRadius(7)
                                }
                                Spacer()
                            }

                            Divider().background(Color(white: 0.12))

                            HStack {
                                Circle()
                                    .fill(calendarManager.hasAccess ? Color.green : Color.red)
                                    .frame(width: 7, height: 7)
                                Text("Calendar \(calendarManager.hasAccess ? "Connected" : "Disconnected")")
                                    .font(.system(size: 14)).foregroundColor(.white)
                                Spacer()
                                Button(action: { showingResetConfirmation = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bolt.fill").font(.system(size: 11))
                                        Text("Reset Energy").font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(white: 0.07))

                        Divider().background(Color(white: 0.12))

                        // ── STATS ──
                        SettingsSectionHeader(icon: "chart.bar.fill", title: "Stats & Progress")

                        VStack(spacing: 10) {
                            MiniStatRow(label: "Tasks Completed",
                                        value: "\(settingsManager.totalTasksCompleted)", color: .green)
                            MiniStatRow(label: "Total XP Earned",
                                        value: "\(settingsManager.totalXP) XP", color: .yellow)
                            MiniStatRow(label: "Deep Work Sessions",
                                        value: "\(settingsManager.deepWorkSessions)", color: .orange)
                            MiniStatRow(label: "Current Streak",
                                        value: "\(settingsManager.currentStreak) days", color: .blue)
                        }
                        .padding(16)
                        .background(Color(white: 0.07))

                        Divider().background(Color(white: 0.12))

                        // ── ABOUT ──
                        HStack(spacing: 10) {
                            Text("(=^･ω･^=)").font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CATS  v1.0")
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                Text("Cognitive Autonomous Task Scheduler")
                                    .font(.system(size: 11)).foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(white: 0.07))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            apiKeyInput = settingsManager.apiKey
            selectedModel = settingsManager.selectedModel
        }
        .alert("Reset Energy", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { settingsManager.totalXP = 0 }
        } message: {
            Text("This will reset your energy/XP progress.")
        }
    }
}

// MARK: - Reusable sub-views (keep these if you removed the old StatRow/SectionHeader)

struct SettingsSectionHeader: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(.blue)
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

struct MiniStatRow: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
        }
    }
}
