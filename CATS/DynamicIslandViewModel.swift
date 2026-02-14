//
//  DynamicIslandViewModel.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import Cocoa
import Combine
import Foundation
import LaunchAtLogin
import SwiftUI

class DynamicIslandViewModel: NSObject, ObservableObject {
    var cancellables: Set<AnyCancellable> = []
    let inset: CGFloat

    init(inset: CGFloat = -4) {
        self.inset = inset
        super.init()
        setupCancellables()
    }

    deinit {
        destroy()
    }

    let animation: Animation = .interactiveSpring(
        duration: 0.5,
        extraBounce: 0.25,
        blendDuration: 0.125
    )

    let notchOpenedSize: CGSize = .init(width: 600, height: 180)
    let notchDropdownSize: CGSize = .init(width: 600, height: 420)
    let dropDetectorRange: CGFloat = 32

    enum Status: String, Codable, Hashable, Equatable {
        case closed
        case opened
        case popping
        case dropdown
    }

    enum OpenReason: String, Codable, Hashable, Equatable {
        case click
        case doubleClick
        case boot
        case unknown
    }

    enum ContentType: Int, Codable, Hashable, Equatable {
        case tasks
        case chat
        case deepWork
        case settings
    }

    var notchOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - notchOpenedSize.height,
            width: notchOpenedSize.width,
            height: notchOpenedSize.height
        )
    }

    var notchDropdownRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchDropdownSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - notchDropdownSize.height,
            width: notchDropdownSize.width,
            height: notchDropdownSize.height
        )
    }

    var headlineOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - deviceNotchRect.height,
            width: notchOpenedSize.width,
            height: deviceNotchRect.height
        )
    }

    @Published private(set) var status: Status = .closed
    @Published var openReason: OpenReason = .unknown
    @Published var contentType: ContentType = .tasks

    @Published var spacing: CGFloat = 16
    @Published var cornerRadius: CGFloat = 16
    @Published var deviceNotchRect: CGRect = .zero
    @Published var screenRect: CGRect = .zero
    @Published var optionKeyPressed: Bool = false
    @Published var notchVisible: Bool = true
    @Published var waitInterval: Double = 3

    @PublishedPersist(key: "selectedLanguage", defaultValue: .system)
    var selectedLanguage: Language

    let hapticSender = PassthroughSubject<Void, Never>()

    // MARK: - TaskStore & Profile references

    let taskStore = TaskStore.shared
    let profile = CognitiveProfile.shared
    let calendarManager = CalendarManager.shared

    // MARK: - State Transitions

    func notchOpen(_ reason: OpenReason) {
        openReason = reason
        status = .opened
        if reason != .doubleClick {
            contentType = .tasks
        }
    }

    func notchClose() {
        openReason = .unknown
        status = .closed
        contentType = .tasks
    }

    func notchDropdown() {
        openReason = .doubleClick
        status = .dropdown
    }

    func showSettings() {
        contentType = .settings
    }

    func showChat() {
        contentType = .chat
    }

    func showDeepWork() {
        contentType = .deepWork
    }

    func showTasks() {
        contentType = .tasks
    }

    func notchPop() {
        openReason = .unknown
        status = .popping
    }
}
