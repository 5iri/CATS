import SwiftUI
import EventKit

struct CalendarIntegrationView: View {
    @ObservedObject var calendarManager: CalendarManager
    let tasks: [ScheduledTask]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Status
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green).font(.title2)
                                Text("Calendar \(calendarManager.hasAccess ? "Connected" : "Disconnected")")
                                    .font(.headline).foregroundColor(.white)
                            }
                            Text("Tasks sync automatically with your iPhone Calendar")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(white: 0.1)).cornerRadius(15)

                        // Count
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Active Tasks").font(.headline).foregroundColor(.white)
                            HStack {
                                Text("\(tasks.filter { !$0.isCompleted }.count)")
                                    .font(.system(size: 40, weight: .bold)).foregroundColor(.blue)
                                Text("tasks scheduled")
                                    .font(.subheadline).foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.1)).cornerRadius(15)

                        // Events
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Calendar Events")
                                .font(.headline).foregroundColor(.white)
                            if calendarManager.events.isEmpty {
                                Text("No events found")
                                    .font(.subheadline).foregroundColor(.gray).padding()
                            } else {
                                ForEach(calendarManager.events.prefix(5), id: \.eventIdentifier) { event in
                                    CalendarEventRow(event: event)
                                }
                            }
                        }
                        .padding()
                        .background(Color(white: 0.1)).cornerRadius(15)

                        // Info
                        VStack(alignment: .leading, spacing: 10) {
                            Text("How it works").font(.headline).foregroundColor(.white)
                            InfoRow(icon: "plus.circle.fill",   text: "New tasks added to Calendar automatically")
                            InfoRow(icon: "checkmark.circle.fill", text: "Completed tasks marked with ✅")
                            InfoRow(icon: "bell.fill",          text: "15-minute reminder before each task")
                        }
                        .padding()
                        .background(Color(white: 0.1)).cornerRadius(15)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Calendar Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.blue)
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
                Text(dayStr).font(.caption).foregroundColor(.gray)
                Text(dateStr).font(.title3).fontWeight(.bold).foregroundColor(.white)
            }
            .frame(width: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled").font(.body).foregroundColor(.white)
                Text(timeStr).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            if event.title?.contains("🐱") == true {
                Image(systemName: "pawprint.fill").foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(white: 0.05)).cornerRadius(10)
    }
    private var dayStr:  String { formatted("EEE") }
    private var dateStr: String { formatted("dd")  }
    private var timeStr: String { formatted("h:mm a") }
    private func formatted(_ fmt: String) -> String {
        let f = DateFormatter(); f.dateFormat = fmt
        return f.string(from: event.startDate)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 24)
            Text(text).font(.subheadline).foregroundColor(.gray)
        }
    }
}
