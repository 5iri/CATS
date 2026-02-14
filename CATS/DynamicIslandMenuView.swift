//
//  DynamicIslandMenuView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import SwiftUI

struct DynamicIslandMenuView: View {
    @StateObject var vm: DynamicIslandViewModel

    var body: some View {
        HStack(spacing: vm.spacing) {
            menuButton(icon: "xmark", title: "Exit", color: .red) {
                vm.notchClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NSApp.terminate(nil)
                }
            }

            menuButton(icon: "gear", title: "Settings", color: .blue) {
                vm.showSettings()
            }

            menuButton(icon: "calendar", title: "Sync Cal", color: .orange) {
                CalendarManager.shared.fetchUpcomingEvents()
                CalendarManager.shared.importDeadlinesAsTasks(into: vm.taskStore)
            }
        }
    }

    private func menuButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: vm.cornerRadius)
                    .fill(color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}
