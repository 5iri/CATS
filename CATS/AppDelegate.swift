//
//  AppDelegate.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import AppKit
import Cocoa
import LaunchAtLogin

class AppDelegate: NSObject, NSApplicationDelegate {
    var isFirstOpen = true
    var isLaunchedAtLogin = false
    var mainWindowController: DynamicIslandWindowController?

    var timer: Timer?

    func applicationDidFinishLaunching(_: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildApplicationWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSApp.setActivationPolicy(.accessory)

        isLaunchedAtLogin = LaunchAtLogin.wasLaunchedAtLogin

        _ = EventMonitors.shared
        let timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            self?.determineIfProcessIdentifierMatches()
            self?.makeKeyAndVisibleIfNeeded()
        }
        self.timer = timer

        // Request calendar access on first launch
        CalendarManager.shared.requestAccess()

        rebuildApplicationWindows()
    }

    func applicationWillTerminate(_: Notification) {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try? FileManager.default.removeItem(at: pidFile)
    }

    func findScreenFitsOurNeeds() -> NSScreen? {
        if let screen = NSScreen.buildin, screen.notchSize != .zero { return screen }
        return .main
    }

    @objc func rebuildApplicationWindows() {
        defer { isFirstOpen = false }
        if let mainWindowController {
            mainWindowController.destroy()
        }

        mainWindowController = nil
        guard let mainScreen = findScreenFitsOurNeeds() else { return }
        mainWindowController = .init(screen: mainScreen)
        if isFirstOpen, !isLaunchedAtLogin {
            mainWindowController?.openAfterCreate = true
        }
    }

    func determineIfProcessIdentifierMatches() {
        let pid = String(NSRunningApplication.current.processIdentifier)
        let url = pidFile
        DispatchQueue.global(qos: .utility).async {
            let content = (try? String(contentsOf: url)) ?? ""
            guard pid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                == content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            else {
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
                return
            }
        }
    }

    func makeKeyAndVisibleIfNeeded() {
        guard let controller = mainWindowController,
              let window = controller.window,
              let vm = controller.vm,
              vm.status == .opened || vm.status == .dropdown
        else { return }
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        guard let controller = mainWindowController,
              let vm = controller.vm
        else { return true }
        vm.notchOpen(.click)
        return true
    }
}
