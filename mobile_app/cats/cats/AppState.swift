//
//  AppState.swift
//  cats
//
//  Created by Shaunak Datar on 14/02/26.
//
import Foundation
import Combine

class AppState: ObservableObject {
    let settings = SettingsManager()
    let calendar = CalendarManager()
    lazy var chat: ChatManager = ChatManager(settingsManager: self.settings)
}
