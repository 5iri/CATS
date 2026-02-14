//
//  DynamicIslandHeaderView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import SwiftUI

struct DynamicIslandHeaderView: View {
    @StateObject var vm: DynamicIslandViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Cat face based on mood
            Text(vm.profile.energyMood)
                .font(.system(size: 14))

            // CATS title and content type
            Text(headerTitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            Spacer()

            // Energy bar
            energyBar

            // Streak badge
            if vm.profile.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text("\(vm.profile.currentStreak)")
                        .font(.system(size: 9, weight: .bold))
                }
            }

            // Navigation dots
            Image(systemName: "ellipsis")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .animation(vm.animation, value: vm.contentType)
    }

    private var headerTitle: String {
        switch vm.contentType {
        case .tasks: return "CATS"
        case .chat: return "Chat"
        case .deepWork: return "Deep Work"
        case .settings: return "Settings"
        }
    }

    private var energyBar: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 7))
                .foregroundStyle(energyColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(energyColor)
                        .frame(width: geo.size.width * vm.profile.currentEnergy / 100)
                }
            }
            .frame(width: 30, height: 4)

            Text("\(Int(vm.profile.currentEnergy))%")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(energyColor)
        }
    }

    private var energyColor: Color {
        switch vm.profile.currentEnergy {
        case 60...100: return .green
        case 30..<60: return .yellow
        default: return .red
        }
    }
}
