import SwiftUI

struct AddTaskView: View {
    @State private var taskTitle: String = ""
    @State private var selectedWorkType: WorkType = .light
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var seconds: Int = 0
    @State private var scheduledDate: Date = Date()
    
    let onAdd: (String, WorkType, Int, Int, Int, Date) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Task Title Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Task Title")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Enter task description", text: $taskTitle)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color(white: 0.15))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        // Date Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Scheduled Date & Time")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            DatePicker("", selection: $scheduledDate, in: Date()...)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .accentColor(.blue)
                        }
                        
                        // Work Type Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Work Type")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Picker("Work Type", selection: $selectedWorkType) {
                                ForEach(WorkType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // Time Duration Picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Duration")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 0) {
                                // Hours Picker
                                Picker("Hours", selection: $hours) {
                                    ForEach(0..<24) { hour in
                                        Text(String(format: "%02d", hour))
                                            .foregroundColor(.white)
                                            .tag(hour)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 80)
                                .clipped()
                                
                                Text("h")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                
                                // Minutes Picker
                                Picker("Minutes", selection: $minutes) {
                                    ForEach(0..<60) { minute in
                                        Text(String(format: "%02d", minute))
                                            .foregroundColor(.white)
                                            .tag(minute)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 80)
                                .clipped()
                                
                                Text("m")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                
                                // Seconds Picker
                                Picker("Seconds", selection: $seconds) {
                                    ForEach(0..<60) { second in
                                        Text(String(format: "%02d", second))
                                            .foregroundColor(.white)
                                            .tag(second)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 80)
                                .clipped()
                                
                                Text("s")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                            }
                            .frame(height: 150)
                        }
                        
                        Spacer()
                        
                        // Add Button
                        Button(action: {
                            if isValidTask {
                                onAdd(taskTitle, selectedWorkType, hours, minutes, seconds, scheduledDate)
                            }
                        }) {
                            Text("Add Task to Calendar")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isValidTask ? Color.blue : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!isValidTask)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var isValidTask: Bool {
        !taskTitle.isEmpty && (hours > 0 || minutes > 0 || seconds > 0)
    }
}
