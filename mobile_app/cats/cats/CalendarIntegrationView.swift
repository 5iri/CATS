//
//  CalendarIntegrationView.swift
//  cats
//
//  Created by Shaunak Datar on 14/02/26.
//

import SwiftUI
import EventKit

struct CalendarIntegrationView: View {
    @ObservedObject var calendarManager: CalendarManager
    let tasks: [Task]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if calendarManager.hasAccess {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Status Card
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                    
                                    Text("Calendar Connected")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Text("Your tasks are automatically synced with your iPhone Calendar app")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(15)
                            
                            // Task Count
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Active Tasks")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    Text("\(tasks.filter { !$0.isCompleted }.count)")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.blue)
                                    
                                    Text("tasks scheduled")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(15)
                            
                            // Recent Calendar Events
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recent Calendar Events")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if calendarManager.events.isEmpty {
                                    Text("No events found")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .padding()
                                } else {
                                    ForEach(calendarManager.events.prefix(5), id: \.eventIdentifier) { event in
                                        CalendarEventRow(event: event)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(15)
                            
                            // Info Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("How it works")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                InfoRow(icon: "plus.circle.fill", text: "New tasks are added to your calendar automatically")
                                InfoRow(icon: "checkmark.circle.fill", text: "Completed tasks are marked with ✅")
                                InfoRow(icon: "bell.fill", text: "You'll get a reminder 15 minutes before each task")
                                InfoRow(icon: "calendar", text: "View all tasks in the Calendar app")
                            }
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(15)
                        }
                        .padding(20)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Calendar Access Required")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("To sync your tasks with the iPhone Calendar, please grant calendar access in Settings.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }
            .navigationTitle("Calendar Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CalendarEventRow: View {
    let event: EKEvent
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Text(dayString)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(dateString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled")
                    .font(.body)
                    .foregroundColor(.white)
                
                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if event.title?.contains("🐱") == true {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(white: 0.05))
        .cornerRadius(10)
    }
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: event.startDate)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: event.startDate)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startDate)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}
