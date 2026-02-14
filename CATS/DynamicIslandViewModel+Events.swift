//
//  DynamicIslandViewModel+Events.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import Cocoa
import Combine
import Foundation
import SwiftUI

extension DynamicIslandViewModel {
    func setupCancellables() {
        let events = EventMonitors.shared

        // Track double-click timing
        var lastClickTime: Date?

        events.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let mouseLocation: NSPoint = NSEvent.mouseLocation
                let now = Date()

                switch status {
                case .opened:
                    // Click outside -> close
                    if !notchOpenedRect.contains(mouseLocation) {
                        notchClose()
                    } else if deviceNotchRect.insetBy(dx: inset, dy: inset).contains(mouseLocation) {
                        notchClose()
                    } else if headlineOpenedRect.contains(mouseLocation) {
                        // Cycle through content types
                        if let nextValue = ContentType(rawValue: contentType.rawValue + 1) {
                            contentType = nextValue
                        } else {
                            contentType = ContentType(rawValue: 0)!
                        }
                    }
                case .dropdown:
                    // Click outside dropdown -> close
                    if !notchDropdownRect.contains(mouseLocation) {
                        notchClose()
                    } else if deviceNotchRect.insetBy(dx: inset, dy: inset).contains(mouseLocation) {
                        notchClose()
                    }
                case .closed, .popping:
                    if deviceNotchRect.insetBy(dx: inset, dy: inset).contains(mouseLocation) {
                        // Detect double-click
                        if let last = lastClickTime,
                           now.timeIntervalSince(last) < 0.4
                        {
                            // Double click -> dropdown
                            lastClickTime = nil
                            notchDropdown()
                            hapticSender.send()
                        } else {
                            // Single click -> open
                            lastClickTime = now
                            // Delay to detect potential double-click
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                                guard let self else { return }
                                if self.status == .closed || self.status == .popping {
                                    if let last = lastClickTime, now == last {
                                        self.notchOpen(.click)
                                        lastClickTime = nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)

        events.optionKeyPress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] input in
                guard let self else { return }
                optionKeyPressed = input
            }
            .store(in: &cancellables)

        events.mouseLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let mouseLocation: NSPoint = NSEvent.mouseLocation
                let aboutToOpen = deviceNotchRect.insetBy(dx: inset, dy: inset).contains(mouseLocation)
                if status == .closed, aboutToOpen { notchPop() }
                if status == .popping, !aboutToOpen { notchClose() }
            }
            .store(in: &cancellables)

        $status
            .filter { $0 != .closed }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                withAnimation { self?.notchVisible = true }
            }
            .store(in: &cancellables)

        $status
            .filter { $0 == .popping }
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] _ in
                guard NSEvent.pressedMouseButtons == 0 else { return }
                self?.hapticSender.send()
            }
            .store(in: &cancellables)

        hapticSender
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: false)
            .sink { _ in
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .levelChange,
                    performanceTime: .now
                )
            }
            .store(in: &cancellables)

        $status
            .debounce(for: 0.5, scheduler: DispatchQueue.global(qos: .userInitiated))
            .filter { $0 == .closed }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                withAnimation {
                    self?.notchVisible = false
                }
            }
            .store(in: &cancellables)

        // Ctrl+Cmd hotkey: single = open chat, double = dropdown (like double-clicking notch)
        var lastHotKeyTime: Date?

        events.hotKeyToggle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let now = Date()

                switch status {
                case .closed, .popping:
                    if let last = lastHotKeyTime,
                       now.timeIntervalSince(last) < 0.4
                    {
                        // Double tap -> dropdown (full task list)
                        lastHotKeyTime = nil
                        notchDropdown()
                        hapticSender.send()
                    } else {
                        // Single tap -> open to chat (with delay to detect double)
                        lastHotKeyTime = now
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                            guard let self else { return }
                            if (self.status == .closed || self.status == .popping),
                               let last = lastHotKeyTime, now == last
                            {
                                lastHotKeyTime = nil
                                self.notchOpen(.click)
                                self.contentType = .chat
                                self.hapticSender.send()
                            }
                        }
                    }
                case .opened, .dropdown:
                    lastHotKeyTime = nil
                    notchClose()
                }
            }
            .store(in: &cancellables)

        $selectedLanguage
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] output in
                self?.notchClose()
                output.apply()
            }
            .store(in: &cancellables)
    }

    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
