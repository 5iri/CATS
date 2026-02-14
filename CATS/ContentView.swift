//
//  ContentView.swift
//  CATS - Cognitive-Aware Task Scheduler
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text(CatFaces.page.home)
                .font(.system(size: 56))
            Text("CATS")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Cognitive-Aware Task Scheduler")
                .font(.system(size: 18, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Running in the Dynamic Island above")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 300, height: 200)
        .padding()
    }
}

#Preview {
    ContentView()
}
