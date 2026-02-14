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

    var body: some View {
        VStack(spacing: 10) {
            // Row 1: Language + Launch at Login
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

            // Row 2: Calendar + Energy Settings
            HStack {
                // Calendar status
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

                // Reset energy
                Button("Reset Energy") {
                    profile.currentEnergy = 100
                    profile.fatigueAccumulator = 0
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }

            // Row 3: Stats
            HStack(spacing: 16) {
                statItem("Level", value: profile.currentLevel.name)
                statItem("Total XP", value: "\(profile.totalXP)")
                statItem("Streak", value: "\(profile.currentStreak) days")
                statItem("Today", value: "\(profile.deepWorkMinutesToday) min")
                Spacer()
            }
        }
        .padding()
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private func statItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
    }
}
