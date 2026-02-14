//
//  DynamicIslandHeaderView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import SwiftUI
import Pow

struct DynamicIslandHeaderView: View {
    @StateObject var vm: DynamicIslandViewModel
    @StateObject private var animState = AnimationState.shared
    
    @State private var catFace: String = ""
    @State private var previousStreak: Int = 0
    @State private var previousXP: Int = 0
    @State private var xpGainTrigger: Int = 0
    @State private var showXPGain: Bool = false
    @State private var lastXPGain: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            // Cat face based on mood with bounce animation
            Text(catFace)
                .font(.system(size: 18))
                .transition(.catBounce)
                .id(catFace)
                .changeEffect(
                    .spray(origin: .center) {
                        Text("✨").font(.system(size: 14))
                    },
                    value: xpGainTrigger
                )

            // CATS title and content type
            Text(headerTitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            Spacer()

            // XP badge with animation
            ZStack {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text("\(vm.profile.totalXP)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: vm.profile.totalXP)
                }
                .changeEffect(.shine, value: xpGainTrigger)

                // Floating +XP text
                if showXPGain {
                    Text("+\(lastXPGain) XP")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .offset(y: -18)
                }
            }

            // Energy bar with pulse when low
            energyBar
                .energyPulse(isLowEnergy: vm.profile.currentEnergy < 30)

            // Streak badge with fire animation
            if vm.profile.currentStreak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .changeEffect(
                            .spray(origin: .center) {
                                Text("🔥").font(.system(size: 14))
                            },
                            value: animState.streakTrigger
                        )

                    AnimatedNumber(
                        value: vm.profile.currentStreak,
                        font: .system(size: 13, weight: .bold),
                        color: .primary
                    )
                }
                .changeEffect(.jump(height: 5), value: vm.profile.currentStreak)
            }

            // Navigation buttons
            Button(action: { vm.notchDropdown() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12))
                    .foregroundStyle(vm.status == .dropdown ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .help("Tasks")

            Button(action: { vm.showDeepWork() }) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundStyle(vm.contentType == .deepWork ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .help("Deep Work")

            Button(action: { vm.showChat() }) {
                Image(systemName: "message")
                    .font(.system(size: 12))
                    .foregroundStyle(vm.contentType == .chat ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .help("Chat")

            Button(action: { vm.showSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(vm.contentType == .settings ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .animation(vm.animation, value: vm.contentType)
        .onAppear {
            catFace = vm.profile.energyMood
            previousStreak = vm.profile.currentStreak
            previousXP = vm.profile.totalXP
        }
        .onChange(of: vm.profile.energyMood) { _, newMood in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                catFace = newMood
            }
        }
        .onChange(of: vm.profile.currentStreak) { oldVal, newVal in
            if newVal > oldVal {
                animState.triggerStreakAnimation()
            }
        }
        .onChange(of: vm.profile.totalXP) { oldVal, newVal in
            if newVal > oldVal {
                lastXPGain = newVal - oldVal
                xpGainTrigger += 1
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showXPGain = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showXPGain = false
                    }
                }
            }
        }
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
                .font(.system(size: 11))
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
                .font(.system(size: 12, weight: .medium, design: .monospaced))
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
