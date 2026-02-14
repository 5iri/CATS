//
//  TimerView.swift
//  cats
//
//  Created by Shaunak Datar on 14/02/26.
//

import SwiftUI

struct TimerView: View {
    let task: Task
    let onDismiss: () -> Void
    
    @State private var timeRemaining: Int
    @State private var timer: Timer?
    @State private var isPaused = false
    
    init(task: Task, onDismiss: @escaping () -> Void) {
        self.task = task
        self.onDismiss = onDismiss
        _timeRemaining = State(initialValue: task.totalSeconds)
    }
    
    var progress: Double {
        Double(timeRemaining) / Double(task.totalSeconds)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Task Title
                VStack(spacing: 10) {
                    Text(task.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text(task.workType.rawValue)
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Circular Timer
                ZStack {
                    // Background Circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 300, height: 300)
                    
                    // Progress Circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            task.workType == .deep ? Color.orange : Color.green,
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: progress)
                    
                    // Time Display
                    VStack(spacing: 10) {
                        Text(formatTime(timeRemaining))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("remaining")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Control Buttons
                HStack(spacing: 40) {
                    // Pause/Resume Button
                    Button(action: togglePause) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color(white: 0.15))
                            .clipShape(Circle())
                    }
                    
                    // Stop Button
                    Button(action: {
                        stopTimer()
                        onDismiss()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onTapGesture {
            // Tap anywhere to dismiss
            stopTimer()
            onDismiss()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopTimer()
                onDismiss()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
