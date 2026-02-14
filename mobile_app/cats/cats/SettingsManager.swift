//
//  SettingsManager.swift
//  cats
//
//  Created by Shaunak Datar on 14/02/26.
//

import Foundation
import Combine

class SettingsManager: ObservableObject {
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "openrouter_api_key") }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selected_model") }
    }
    @Published var totalXP: Int {
        didSet { UserDefaults.standard.set(totalXP, forKey: "total_xp") }
    }
    @Published var totalTasksCompleted: Int {
        didSet { UserDefaults.standard.set(totalTasksCompleted, forKey: "tasks_completed") }
    }
    @Published var deepWorkSessions: Int {
        didSet { UserDefaults.standard.set(deepWorkSessions, forKey: "deep_work_sessions") }
    }
    @Published var currentStreak: Int {
        didSet { UserDefaults.standard.set(currentStreak, forKey: "current_streak") }
    }
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "openrouter_api_key") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selected_model") ?? "liquid/lfm-2.2-6b"
        self.totalXP = UserDefaults.standard.integer(forKey: "total_xp")
        self.totalTasksCompleted = UserDefaults.standard.integer(forKey: "tasks_completed")
        self.deepWorkSessions = UserDefaults.standard.integer(forKey: "deep_work_sessions")
        self.currentStreak = UserDefaults.standard.integer(forKey: "current_streak")
    }
}
