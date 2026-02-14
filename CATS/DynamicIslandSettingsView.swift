//
//  DynamicIslandSettingsView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import LaunchAtLogin
import SwiftUI

struct DynamicIslandSettingsView: View {
    @StateObject var vm: DynamicIslandViewModel
    @ObservedObject var profile = CognitiveProfile.shared
    @ObservedObject var calendarManager = CalendarManager.shared
    @ObservedObject var llm = OpenRouterService.shared

    @State private var apiKeyInput: String = ""
    @State private var showAPIKey = false
    @State private var apiKeyStatus: APIKeyStatus = .unchecked

    enum APIKeyStatus {
        case unchecked, checking, valid, invalid
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                // Section 1: AI Configuration
                aiSection

                Divider().background(Color.white.opacity(0.1))

                // Section 2: General Settings
                generalSection

                Divider().background(Color.white.opacity(0.1))

                // Section 3: Stats & Gamification
                statsSection
            }
            .padding()
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .onAppear {
            apiKeyInput = llm.apiKey
            apiKeyStatus = llm.isConfigured ? .valid : .unchecked
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
                Text("AI Engine")
                    .font(.system(size: 11, weight: .bold, design: .rounded))

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(llm.isConfigured ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(llm.isConfigured ? "Connected" : "Not Configured")
                        .font(.system(size: 9))
                        .foregroundStyle(llm.isConfigured ? .green : .orange)
                }
            }

            // API Key
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenRouter API Key")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if showAPIKey {
                        TextField("sk-or-...", text: $apiKeyInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                    } else {
                        SecureField("sk-or-...", text: $apiKeyInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                    }

                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button("Save") {
                        llm.apiKey = apiKeyInput
                        apiKeyStatus = apiKeyInput.isEmpty ? .unchecked : .valid
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("Get a key at openrouter.ai — many models have free tiers!")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }

            // Model picker
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Model")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                Picker("Model", selection: $llm.model) {
                    ForEach(OpenRouterService.availableModels, id: \.id) { model in
                        HStack {
                            Text(model.name)
                            Text("(\(model.tier))")
                                .foregroundStyle(.secondary)
                        }
                        .tag(model.id)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 10))
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gear")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("General")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            HStack {
                Picker("Language: ", selection: $vm.selectedLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(language.localized).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 160)

                LaunchAtLogin.Toggle {
                    Text(NSLocalizedString("Launch at Login", comment: ""))
                }
                .padding(.leading, 20)

                Spacer()
            }

            // Calendar + Energy
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(calendarManager.isAuthorized ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(calendarManager.isAuthorized ? "Calendar Connected" : "Calendar Not Connected")
                        .font(.system(size: 10))

                    if !calendarManager.isAuthorized {
                        Button("Connect") {
                            calendarManager.requestAccess()
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }

                Spacer()

                Button("Reset Energy") {
                    profile.currentEnergy = 100
                    profile.fatigueAccumulator = 0
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                Text("Stats & Progress")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            // Level card
            HStack(spacing: 10) {
                Text(profile.currentLevel.cat)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.currentLevel.name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * profile.levelProgress)
                        }
                    }
                    .frame(height: 6)

                    if let next = profile.nextLevel {
                        Text("\(profile.totalXP) / \(next.xpRequired) XP to \(next.name)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )

            // Stats row
            HStack(spacing: 16) {
                statItem("Total XP", value: "\(profile.totalXP)", icon: "star.fill", color: .yellow)
                statItem("Streak", value: "\(profile.currentStreak)d", icon: "flame.fill", color: .orange)
                statItem("Today", value: "\(profile.deepWorkMinutesToday)m", icon: "clock.fill", color: .blue)
                statItem("Energy", value: "\(Int(profile.currentEnergy))%", icon: "bolt.fill", color: energyColor)
                Spacer()
            }
        }
    }

    private func statItem(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 7))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
        }
    }

    private var energyColor: Color {
        switch profile.currentEnergy {
        case 60...100: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }
}
