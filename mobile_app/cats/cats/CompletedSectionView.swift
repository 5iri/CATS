import SwiftUI

struct CompletedSectionView: View {
    let tasks: [Task]
    let onClearAll: () -> Void
    @State private var isExpanded = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Completed (\(tasks.count))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    if !tasks.isEmpty {
                        Button(action: { showingClearConfirmation = true }) {
                            Text("Clear All")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color(white: 0.08))
            }
            
            if isExpanded {
                ForEach(tasks) { task in
                    CompletedTaskRow(task: task)
                }
            }
        }
        .alert("Clear All Completed Tasks", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                onClearAll()
            }
        } message: {
            Text("Are you sure you want to clear all \(tasks.count) completed tasks? This cannot be undone.")
        }
    }
}

struct CompletedTaskRow: View {
    let task: Task
    
    var statusColor: Color {
        task.workType == .deep ? .orange : .green
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(statusColor.opacity(0.3))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.gray)
                    .strikethrough()
                
                HStack(spacing: 8) {
                    Image(systemName: task.workType == .light ? "book" : "brain")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(task.workType.rawValue)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(formatDate(task.date))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color(white: 0.08))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, hh:mm a"
        return formatter.string(from: date)
    }
}
