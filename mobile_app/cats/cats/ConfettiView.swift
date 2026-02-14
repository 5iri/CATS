//
//  ConfettiView.swift
//  cats
//
//  Created by Shaunak Datar on 14/02/26.
//

import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<30) { index in
                ConfettiPiece(index: index, animate: animate)
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    let index: Int
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var rotation: Double = 0
    let animate: Bool
    
    private let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
    
    var body: some View {
        Circle()
            .fill(colors[index % colors.count])
            .frame(width: CGFloat.random(in: 5...10), height: CGFloat.random(in: 5...10))
            .offset(x: xOffset, y: yOffset)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    yOffset = CGFloat.random(in: -300...300)
                    xOffset = CGFloat.random(in: -200...200)
                    opacity = 0
                    rotation = Double.random(in: 0...720)
                }
            }
    }
}
