import Foundation
import EventKit
import Combine

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var hasAccess = false
    @Published var events: [EKEvent] = []
    
    private var taskEventIDs: [UUID: String] = [:] // Maps task IDs to calendar event IDs
    
    func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.loadEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted {
                        self?.loadEvents()
                    }
                }
            }
        }
    }
    
    func loadEvents() {
        let calendars = eventStore.calendars(for: .event)
        
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        
        DispatchQueue.main.async { [weak self] in
            self?.events = self?.eventStore.events(matching: predicate) ?? []
        }
    }
    
    func addTaskToCalendar(task: Task) {
        guard hasAccess else {
            print("No calendar access")
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "🐱 \(task.title)"
        event.startDate = task.date
        
        // Calculate end date based on task duration
        let endDate = Calendar.current.date(byAdding: .second, value: task.totalSeconds, to: task.date) ?? task.date
        event.endDate = endDate
        
        // Add work type and load to notes
        event.notes = """
        Work Type: \(task.workType.rawValue)
        Load Points: \(task.loadPoints)
        Duration: \(task.duration)
        XP Reward: ~\(task.loadPoints * 10)
        
        Created by CATS Task Scheduler
        """
        
        // Set calendar (use default calendar)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add alert 15 minutes before
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            taskEventIDs[task.id] = event.eventIdentifier
            loadEvents()
            print("Task added to calendar: \(task.title)")
        } catch {
            print("Error saving event to calendar: \(error.localizedDescription)")
        }
    }
    
    func completeTaskInCalendar(task: Task) {
        guard hasAccess, let eventID = taskEventIDs[task.id] else { return }
        
        if let event = eventStore.event(withIdentifier: eventID) {
            event.title = "✅ \(task.title)"
            event.notes = (event.notes ?? "") + "\n\n✅ Completed!"
            
            do {
                try eventStore.save(event, span: .thisEvent)
                loadEvents()
                print("Task marked as completed in calendar")
            } catch {
                print("Error updating event: \(error.localizedDescription)")
            }
        }
    }
    
    func removeTaskFromCalendar(task: Task) {
        guard hasAccess, let eventID = taskEventIDs[task.id] else { return }
        
        if let event = eventStore.event(withIdentifier: eventID) {
            do {
                try eventStore.remove(event, span: .thisEvent)
                taskEventIDs.removeValue(forKey: task.id)
                loadEvents()
                print("Task removed from calendar")
            } catch {
                print("Error removing event: \(error.localizedDescription)")
            }
        }
    }
}
