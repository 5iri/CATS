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

        let store = self.eventStore
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let calendar = Calendar.current
            let now = Date()
            guard let endDate = calendar.date(byAdding: .day, value: 14, to: now) else { return }

            let predicate = store.predicateForEvents(
                withStart: now,
                end: endDate,
                calendars: nil
            )

            let events = store.events(matching: predicate)
            DispatchQueue.main.async {
                self?.calendarEvents = events.sorted { $0.startDate < $1.startDate }
            }
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

        // Schedule the study block at the next free slot, NOT at the deadline
        let start = nextFreeSlot(duration: task.estimatedMinutes)
        let end = start.addingTimeInterval(Double(task.estimatedMinutes) * 60)

        let event = EKEvent(eventStore: eventStore)
        event.title = "CATS: \(task.title)"
        event.startDate = start
        event.endDate = end
        event.notes = """
            Cognitive Load: \(task.cognitiveLoad)/10
            Category: \(task.category.rawValue)
            Duration: \(task.estimatedMinutes)m
            Scheduled by CATS (=^·ω·^=)
            """
        event.calendar = eventStore.defaultCalendarForNewEvents

        let alarm = EKAlarm(relativeOffset: -300) // 5 min before
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            fetchUpcomingEvents()
            return event.eventIdentifier
        } catch {
            print("[CATS] Failed to save calendar event: \(error)")
            return nil
        }
    }

    /// Find the next free time slot starting from now that fits the given duration
    private func nextFreeSlot(duration: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()

        // Round up to next 5-minute mark
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = components.minute ?? 0
        components.minute = ((minute + 4) / 5) * 5
        let roundedNow = calendar.date(from: components) ?? now

        let needed = TimeInterval(duration * 60)

        // Get existing CATS events for today to avoid overlap
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? now
        let predicate = eventStore.predicateForEvents(
            withStart: roundedNow,
            end: endOfDay,
            calendars: nil
        )
        let existing = eventStore.events(matching: predicate)
            .filter { $0.title?.contains("CATS:") == true }
            .sorted { $0.startDate < $1.startDate }

        // Try to fit after each existing CATS event
        var candidate = roundedNow
        for event in existing {
            guard let evStart = event.startDate, let evEnd = event.endDate else { continue }
            // If our candidate overlaps this event, push past it
            let candidateEnd = candidate.addingTimeInterval(needed)
            if candidate < evEnd && candidateEnd > evStart {
                candidate = evEnd
            }
        }

        return candidate
    }

    func removeEvent(identifier: String) {
        guard isAuthorized, let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }

    // MARK: - Intelligent Schedule to Calendar

    /// Get busy time slots from existing calendar events
    func getBusySlots() -> [(start: Date, end: Date)] {
        calendarEvents.compactMap { event in
            guard let start = event.startDate, let end = event.endDate else { return nil }
            // Skip all-day events
            if event.isAllDay { return nil }
            return (start, end)
        }
    }

    /// Rearrange schedule on calendar: update existing CATS events in place, create new ones as needed.
    /// Keeps everything and just rearranges — does not clear all events first.
    @discardableResult
    func rearrangeScheduleOnCalendar(_ blocks: [CognitiveEngine.ScheduleBlock]) -> Int {
        guard isAuthorized else { return 0 }

        let existing = fetchTodayCATSEvents()
        var count = 0

        for (idx, block) in blocks.enumerated() {
            let (title, notes) = blockTitleAndNotes(for: block)

            if idx < existing.count {
                // Update existing event in place (rearrange)
                let event = existing[idx]
                event.title = title
                event.notes = notes
                event.startDate = block.startTime
                event.endDate = block.endTime
                if let alarms = event.alarms {
                    for alarm in alarms { event.removeAlarm(alarm) }
                }
                let alertOffset: TimeInterval = block.task != nil ? -300 : -60
                event.addAlarm(EKAlarm(relativeOffset: alertOffset))

                do {
                    try eventStore.save(event, span: .thisEvent)
                    count += 1
                } catch {
                    print("[CATS] Failed to update calendar event: \(error)")
                }
            } else {
                // Create new event
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.notes = notes
                event.startDate = block.startTime
                event.endDate = block.endTime
                event.calendar = eventStore.defaultCalendarForNewEvents
                let alertOffset: TimeInterval = block.task != nil ? -300 : -60
                event.addAlarm(EKAlarm(relativeOffset: alertOffset))

                do {
                    try eventStore.save(event, span: .thisEvent)
                    count += 1
                } catch {
                    print("[CATS] Failed to save calendar event: \(error)")
                }
            }
        }

        fetchUpcomingEvents()
        return count
    }

    private func fetchTodayCATSEvents() -> [EKEvent] {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .filter { $0.title?.contains("CATS:") == true }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }

    private func blockTitleAndNotes(for block: CognitiveEngine.ScheduleBlock) -> (String, String) {
        let title: String
        switch block.type {
        case .deepWork:
            title = "🧠 CATS: \(block.label)"
        case .lightWork:
            title = "📖 CATS: \(block.label)"
        case .recoveryBreak:
            title = "💚 CATS: Recovery Break"
        case .microBreak:
            title = "☕ CATS: Micro Break"
        }

        var notes = "Scheduled by CATS (=^·ω·^=)\n"
        notes += block.reason
        if let task = block.task {
            notes += "\nCognitive Load: \(task.cognitiveLoad)/10"
            notes += "\nCategory: \(task.category.rawValue)"
        }

        return (title, notes)
    }

    /// Write an entire generated schedule to the calendar (creates new events only)
    @discardableResult
    func writeScheduleToCalendar(_ blocks: [CognitiveEngine.ScheduleBlock]) -> Int {
        guard isAuthorized else { return 0 }

        var count = 0
        for block in blocks {
            let (title, notes) = blockTitleAndNotes(for: block)
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.notes = notes
            event.startDate = block.startTime
            event.endDate = block.endTime
            event.calendar = eventStore.defaultCalendarForNewEvents

            let alertOffset: TimeInterval = block.task != nil ? -300 : -60
            event.addAlarm(EKAlarm(relativeOffset: alertOffset))

            do {
                try eventStore.save(event, span: .thisEvent)
                count += 1
            } catch {
                print("[CATS] Failed to save schedule block: \(error)")
            }
        }

        fetchUpcomingEvents()
        return count
    }

    /// Remove all CATS-generated schedule events for today
    func clearTodaySchedule() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
        for event in events {
            if let title = event.title, title.contains("CATS:") {
                try? eventStore.remove(event, span: .thisEvent)
            }
        }

        fetchUpcomingEvents()
    }
}
