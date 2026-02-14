//
//  EventMonitors.swift
//  CATS
//
//  Created by Ravindra Singh on 10/08/24.
//

import Cocoa
import Combine

class EventMonitors {
    static let shared = EventMonitors()

    private var mouseMoveEvent: EventMonitor!
    private var mouseDownEvent: EventMonitor!
    private var mouseDraggingFileEvent: EventMonitor!
    private var optionKeyPressEvent: EventMonitor!
    private var hotKeyEvent: EventMonitor!
    private var hotKeyActive = false

    let mouseLocation: CurrentValueSubject<NSPoint, Never> = .init(.zero)
    let mouseDown: PassthroughSubject<Void, Never> = .init()
    let mouseDraggingFile: PassthroughSubject<Void, Never> = .init()
    let optionKeyPress: CurrentValueSubject<Bool, Never> = .init(false)
    let hotKeyToggle: PassthroughSubject<Void, Never> = .init()

    private init() {
        mouseMoveEvent = EventMonitor(mask: .mouseMoved) { [weak self] _ in
            guard let self else { return }
            let mouseLocation = NSEvent.mouseLocation
            self.mouseLocation.send(mouseLocation)
        }
        mouseMoveEvent.start()

        mouseDownEvent = EventMonitor(mask: .leftMouseDown) { [weak self] _ in
            guard let self else { return }
            mouseDown.send()
        }
        mouseDownEvent.start()

        mouseDraggingFileEvent = EventMonitor(mask: .leftMouseDragged) { [weak self] _ in
            guard let self else { return }
            mouseDraggingFile.send()
        }
        mouseDraggingFileEvent.start()

        optionKeyPressEvent = EventMonitor(mask: .flagsChanged) { [weak self] event in
            guard let self else { return }
            if event?.modifierFlags.contains(.option) == true {
                optionKeyPress.send(true)
            } else {
                optionKeyPress.send(false)
            }
        }
        optionKeyPressEvent.start()

        // Ctrl+Cmd hotkey: fires once when both modifiers are held
        hotKeyEvent = EventMonitor(mask: .flagsChanged) { [weak self] event in
            guard let self, let event else { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let ctrlCmd = flags.contains(.control) && flags.contains(.command)
            if ctrlCmd && !self.hotKeyActive {
                self.hotKeyActive = true
                self.hotKeyToggle.send()
            } else if !ctrlCmd {
                self.hotKeyActive = false
            }
        }
        hotKeyEvent.start()
    }
}
