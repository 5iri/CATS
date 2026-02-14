//
//  Ext+Notification.swift
//  CATS
//

import Foundation

extension Notification.Name {
    static let catsTaskAdded = Notification.Name("catsTaskAdded")
    static let catsTaskCompleted = Notification.Name("catsTaskCompleted")
    static let catsBreakSuggested = Notification.Name("catsBreakSuggested")
    static let catsFocusSessionChanged = Notification.Name("catsFocusSessionChanged")
}
