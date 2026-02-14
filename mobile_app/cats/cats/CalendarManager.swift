import Foundation
import Combine
import EventKit

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var hasAccess = false
    @Published var events: [EKEvent] = []

    private var taskEventIDs: [UUID: String] = [:]

    func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.loadEvents() }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.loadEvents() }
                }
            }
        }
    }

    func loadEvents() {
        let calendars = eventStore.calendars(for: .event)
        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let end   = Calendar.current.date(byAdding: .month, value:  1, to: Date())!
        let pred  = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        DispatchQueue.main.async { self.events = self.eventStore.events(matching: pred) }
    }

    func addTaskToCalendar(task: ScheduledTask) {
        guard hasAccess else { return }
        let event = EKEvent(eventStore: eventStore)
        event.title     = "🐱 \(task.title)"
        event.startDate = task.date
        event.endDate   = Calendar.current.date(
            byAdding: .second, value: task.totalSeconds, to: task.date
        ) ?? task.date
        event.notes    = """
            Work Type: \(task.workType.rawValue)
            Load Points: \(task.loadPoints)
            Duration: \(task.duration)
            XP Reward: ~\(task.loadPoints * 10)
            Created by CATS Task Scheduler
            """
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60))
        do {
            try eventStore.save(event, span: .thisEvent)
            taskEventIDs[task.id] = event.eventIdentifier
            loadEvents()
        } catch { print("Calendar save error: \(error)") }
    }

    func completeTaskInCalendar(task: ScheduledTask) {
        guard hasAccess, let eid = taskEventIDs[task.id],
              let event = eventStore.event(withIdentifier: eid) else { return }
        event.title = "✅ \(task.title)"
        event.notes = (event.notes ?? "") + "\n\n✅ Completed!"
        try? eventStore.save(event, span: .thisEvent)
        loadEvents()
    }

    func removeTaskFromCalendar(task: ScheduledTask) {
        guard hasAccess, let eid = taskEventIDs[task.id],
              let event = eventStore.event(withIdentifier: eid) else { return }
        try? eventStore.remove(event, span: .thisEvent)
        taskEventIDs.removeValue(forKey: task.id)
        loadEvents()
    }
}
