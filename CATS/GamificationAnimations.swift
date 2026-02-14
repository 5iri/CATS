//
//  GamificationAnimations.swift
//  CATS - Cognitive-Aware Task Scheduler
//
//  Gamification animations for energy, streaks, XP, and task completion
//

import SwiftUI
import Pow

// MARK: - Animation State Manager

class AnimationState: ObservableObject {
    static let shared = AnimationState()
    
    @Published var streakTrigger: Int = 0
    @Published var xpTrigger: Int = 0
    @Published var levelUpTrigger: Int = 0
    @Published var taskCompleteTrigger: Int = 0
    @Published var energyWarningTrigger: Int = 0
    
    @Published var lastXPGain: Int = 0
    @Published var showLevelUpBanner: Bool = false
    @Published var newLevelName: String = ""
    
    func triggerStreakAnimation() {
        streakTrigger += 1
    }
    
    func triggerXPAnimation(amount: Int) {
        lastXPGain = amount
        xpTrigger += 1
    }
    
    func triggerLevelUp(levelName: String) {
        newLevelName = levelName
        levelUpTrigger += 1
        showLevelUpBanner = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.5)) {
                self.showLevelUpBanner = false
            }
        }
    }
    
    func triggerTaskComplete() {
        taskCompleteTrigger += 1
    }
    
    func triggerEnergyWarning() {
        energyWarningTrigger += 1
    }
}

// MARK: - Energy Pulse Modifier

struct EnergyPulseModifier: ViewModifier {
    let isLowEnergy: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isLowEnergy {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isPulsing ? 1.4 : 1.0)
                        .opacity(isPulsing ? 0 : 0.8)
                }
            }
            .onChange(of: isLowEnergy) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
            .onAppear {
                if isLowEnergy {
                    withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            }
    }
}

// MARK: - Breathing Glow Modifier (for urgent tasks)

struct BreathingGlowModifier: ViewModifier {
    let isUrgent: Bool
    let color: Color
    @State private var isBreathing = false
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: isUrgent ? color.opacity(isBreathing ? 0.6 : 0.2) : .clear,
                radius: isBreathing ? 8 : 4
            )
            .onChange(of: isUrgent) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                } else {
                    isBreathing = false
                }
            }
            .onAppear {
                if isUrgent {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
            }
    }
}

// MARK: - Bounce Scale Modifier

struct BounceScaleModifier: ViewModifier {
    @Binding var trigger: Int
    
    func body(content: Content) -> some View {
        content
            .changeEffect(
                .jump(height: 10),
                value: trigger
            )
    }
}

// MARK: - Floating XP Text View

struct FloatingXPView: View {
    let amount: Int
    @Binding var trigger: Int
    @State private var isAnimating = false
    @State private var showXP = false
    
    var body: some View {
        ZStack {
            if showXP {
                Text("+\(amount) XP")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.5), radius: 4)
                    .offset(y: isAnimating ? -25 : 0)
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .onChange(of: trigger) { _, _ in
            showXP = true
            isAnimating = false
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showXP = false
                isAnimating = false
            }
        }
    }
}

// MARK: - Streak Fire Spray View

struct StreakSprayView: View {
    @Binding var trigger: Int
    
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .changeEffect(
                .spray(origin: .center) {
                    Text("🔥")
                        .font(.system(size: 14))
                },
                value: trigger
            )
    }
}

// MARK: - Level Up Celebration View

struct LevelUpBannerView: View {
    let levelName: String
    let isShowing: Bool
    @State private var confettiTrigger: Int = 0
    
    var body: some View {
        ZStack {
            if isShowing {
                VStack(spacing: 4) {
                    Text("🎉 LEVEL UP! 🎉")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                    
                    Text(levelName)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .purple.opacity(0.5), radius: 20)
                )
                .changeEffect(
                    .spray(origin: .center) {
                        Group {
                            Text("⭐")
                            Text("✨")
                            Text("🌟")
                        }
                        .font(.system(size: 16))
                    },
                    value: confettiTrigger
                )
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    confettiTrigger += 1
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isShowing)
    }
}

// MARK: - Task Completion Checkmark Animation

struct CompletionCheckmarkView: View {
    @Binding var trigger: Int
    @State private var showCheck = false
    @State private var checkScale: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            if showCheck {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
                    .scaleEffect(checkScale)
                    .shadow(color: .green.opacity(0.5), radius: 8)
            }
        }
        .onChange(of: trigger) { _, _ in
            showCheck = true
            checkScale = 0.5
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                checkScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    checkScale = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCheck = false
                }
            }
        }
    }
}

// MARK: - Shine Effect for Achievements

struct ShineModifier: ViewModifier {
    @Binding var trigger: Int
    
    func body(content: Content) -> some View {
        content
            .changeEffect(
                .shine,
                value: trigger
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Adds a pulsing glow when energy is low
    func energyPulse(isLowEnergy: Bool) -> some View {
        modifier(EnergyPulseModifier(isLowEnergy: isLowEnergy))
    }
    
    /// Adds a breathing glow effect for urgent items
    func breathingGlow(isUrgent: Bool, color: Color = .red) -> some View {
        modifier(BreathingGlowModifier(isUrgent: isUrgent, color: color))
    }
    
    /// Adds a bounce effect triggered by value changes
    func bounceOnChange(_ trigger: Binding<Int>) -> some View {
        modifier(BounceScaleModifier(trigger: trigger))
    }
    
    /// Adds shine effect on trigger
    func shineOnChange(_ trigger: Binding<Int>) -> some View {
        modifier(ShineModifier(trigger: trigger))
    }
}

// MARK: - Cat Face Transition

extension AnyTransition {
    static var catBounce: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .scale(scale: 1.2).combined(with: .opacity)
        )
    }
}

// MARK: - Number Counter Animation

struct AnimatedNumber: View {
    let value: Int
    let font: Font
    let color: Color
    
    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(countsDown: false))
            .animation(.snappy, value: value)
    }
}

// MARK: - Progress Bar with Glow

struct GlowingProgressBar: View {
    let progress: Double
    let gradient: [Color]
    let height: CGFloat
    @State private var isGlowing = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .shadow(color: gradient.last?.opacity(isGlowing ? 0.6 : 0.3) ?? .clear, radius: isGlowing ? 6 : 3)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}
