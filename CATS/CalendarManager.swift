//
//  CalendarManager.swift
//  CATS
//

import EventKit
import Foundation

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    @Published var calendarEvents: [EKEvent] = []

    private init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        if #available(macOS 14.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            switch status {
            case .fullAccess, .authorized:
                isAuthorized = true
                fetchUpcomingEvents()
            case .notDetermined:
                break
            default:
                isAuthorized = false
            }
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            isAuthorized = status == .authorized
            if isAuthorized { fetchUpcomingEvents() }
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.fetchUpcomingEvents()
                    }
                    if let error {
                        print("[CATS] Calendar access error: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.fetchUpcomingEvents()
                    }
                    if let error {
                        print("[CATS] Calendar access error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Read Events

    func fetchUpcomingEvents() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let now = Date()
        guard let endDate = calendar.date(byAdding: .day, value: 14, to: now) else { return }

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
        DispatchQueue.main.async {
            self.calendarEvents = events.sorted { $0.startDate < $1.startDate }
        }
    }

    func importDeadlinesAsTasks(into store: TaskStore) {
        guard isAuthorized else { return }
        fetchUpcomingEvents()

        for event in calendarEvents {
            // Skip events that are already imported
            let alreadyExists = store.tasks.contains { $0.calendarEventID == event.eventIdentifier }
            guard !alreadyExists else { continue }

            // Only import events with "deadline", "due", "submit" in title
            let title = event.title?.lowercased() ?? ""
            let isDeadline = title.contains("deadline") || title.contains("due")
                || title.contains("submit") || title.contains("assignment")
                || title.contains("exam") || title.contains("quiz")
                || title.contains("test") || title.contains("project")

            guard isDeadline else { continue }

            let cogLoad = CognitiveEngine.shared.estimateCognitiveLoad(event.title ?? "")
            let task = CATSTask(
                title: event.title ?? "Calendar Event",
                description: event.notes ?? "",
                deadline: event.endDate ?? event.startDate,
                cognitiveLoad: cogLoad,
                calendarEventID: event.eventIdentifier
            )
            store.addTask(task)
        }
    }

    // MARK: - Write Events

    func createStudyBlock(for task: CATSTask, startDate: Date, duration: Int) -> String? {
        guard isAuthorized else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = "CATS: \(task.title)"
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))
        event.notes = """
            Cognitive Load: \(task.cognitiveLoad)/10
            Category: \(task.category.rawValue)
            Scheduled by CATS (=^･ω･^=)
            """
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add alert 5 minutes before
        let alarm = EKAlarm(relativeOffset: -300)
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("[CATS] Failed to save calendar event: \(error)")
            return nil
        }
    }

    func writeDeadlineToCalendar(for task: CATSTask) -> String? {
        guard isAuthorized else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = "Deadline: \(task.title)"
        event.startDate = task.deadline.addingTimeInterval(-3600) // 1 hour before
        event.endDate = task.deadline
        event.notes = """
            CATS Task Deadline
            Cognitive Load: \(task.cognitiveLoad)/10
            \(CatFaces.focused.randomElement()!)
            """
        event.calendar = eventStore.defaultCalendarForNewEvents

        let alarm = EKAlarm(relativeOffset: -1800) // 30 min before
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("[CATS] Failed to save deadline event: \(error)")
            return nil
        }
    }

    func removeEvent(identifier: String) {
        guard isAuthorized, let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}
