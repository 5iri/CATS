//
//  ContentView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text(CatFaces.page.home)
                .font(.system(size: 48))
            Text("CATS")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Cognitive-Aware Task Scheduler")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Running in the Dynamic Island above")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 300, height: 200)
        .padding()
    }
}

#Preview {
    ContentView()
}
