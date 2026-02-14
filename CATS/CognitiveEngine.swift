//
//  CognitiveEngine.swift
//  CATS
//

import Foundation

class CognitiveEngine {
    static let shared = CognitiveEngine()

    // MARK: - Parsed Result (enhanced with LLM fields)

    struct ParsedTask {
        var title: String
        var deadline: Date
        var cognitiveLoad: Int
        var estimatedMinutes: Int
        var category: TaskCategory

        // LLM-enhanced fields (nil when using fallback)
        var loadReasoning: String?
        var motivationalMessage: String?
        var schedulingSuggestion: String?
        var difficultyBadge: String?
        var xpPreview: Int?
        var isAIPowered: Bool = false
    }

    // MARK: - Keyword Tables (fallback)

    private let highLoadKeywords: [(pattern: String, load: Int)] = [
        ("dynamic programming", 9),
        ("algorithm", 8),
        ("algorithms", 8),
        ("data structure", 8),
        ("proof", 8),
        ("theorem", 8),
        ("calculus", 9),
        ("differential equation", 9),
        ("linear algebra", 8),
        ("system design", 8),
        ("compiler", 9),
        ("operating system", 8),
        ("machine learning", 9),
        ("neural network", 9),
        ("graph theory", 8),
        ("recursion", 7),
        ("backtracking", 8),
        ("optimization", 8),
        ("complexity analysis", 8),
        ("concurrency", 8),
        ("distributed system", 9),
        ("database design", 7),
        ("physics", 7),
        ("chemistry", 7),
        ("organic chemistry", 9),
        ("quantum", 10),
    ]

    private let mediumLoadKeywords: [(pattern: String, load: Int)] = [
        ("essay", 5),
        ("report", 5),
        ("project", 6),
        ("debug", 6),
        ("debugging", 6),
        ("presentation", 5),
        ("lab", 5),
        ("assignment", 5),
        ("homework", 5),
        ("coding", 6),
        ("programming", 6),
        ("implement", 6),
        ("analysis", 6),
        ("research", 6),
        ("design", 5),
        ("test", 5),
        ("exam prep", 7),
        ("study", 5),
        ("practice", 5),
        ("problem set", 6),
    ]

    private let lowLoadKeywords: [(pattern: String, load: Int)] = [
        ("reading", 3),
        ("read", 3),
        ("review", 3),
        ("notes", 2),
        ("email", 2),
        ("organize", 2),
        ("plan", 2),
        ("outline", 3),
        ("flashcard", 3),
        ("watch lecture", 3),
        ("watch video", 2),
        ("summarize", 3),
        ("rewrite", 4),
        ("edit", 3),
        ("proofread", 3),
    ]

    // Day-level deadline patterns (these get snapped to 23:59 of the target day)
    // Order matters: longer/more-specific patterns MUST come first
    private let dayDeadlinePatterns: [(pattern: String, daysOffset: Int)] = [
        ("day after tomorrow", 2),
        ("next week", 7),
        ("this week", 3),
        ("tomorrow", 1),
        ("tonight", 0),
        ("today", 0),
    ]

    // MARK: - Keyword-Based Parsing (fallback)

    func parseNaturalLanguage(_ input: String) -> ParsedTask {
        let lower = input.lowercased()
        let cogLoad = estimateCognitiveLoad(lower)
        let deadline = extractDeadline(lower)
        let duration = estimateDuration(cogLoad, text: lower)
        let category = inferCategory(cogLoad, text: lower)
        let title = cleanTitle(input)

        return ParsedTask(
            title: title,
            deadline: deadline,
            cognitiveLoad: cogLoad,
            estimatedMinutes: duration,
            category: category
        )
    }

    func estimateCognitiveLoad(_ text: String) -> Int {
        let lower = text.lowercased()

        // Check high load first
        for kw in highLoadKeywords {
            if lower.contains(kw.pattern) { return kw.load }
        }
        // Medium
        for kw in mediumLoadKeywords {
            if lower.contains(kw.pattern) { return kw.load }
        }
        // Low
        for kw in lowLoadKeywords {
            if lower.contains(kw.pattern) { return kw.load }
        }

        return 5 // default medium
    }

    // MARK: - Bandwidth-Aware Smart Scheduling

    /// Compute a scheduling score for a task based on current mental bandwidth
    /// Higher score = should do this task sooner
    func schedulingScore(for task: CATSTask, profile: CognitiveProfile) -> Double {
        // 1. Urgency component (0-40 points) — deadline proximity
        let hoursLeft = max(0, task.timeRemaining / 3600)
        let urgency: Double
        if task.isOverdue {
            urgency = 40
        } else if hoursLeft < 1 {
            urgency = 38
        } else if hoursLeft < 3 {
            urgency = 32
        } else if hoursLeft < 12 {
            urgency = 24
        } else if hoursLeft < 24 {
            urgency = 16
        } else {
            urgency = max(0, 12 - hoursLeft * 0.1)
        }

        // 2. Bandwidth match component (0-30 points) — does cognitive load match current energy?
        let bandwidthMatch = profile.bandwidthMatch(for: task.cognitiveLoad)
        let bandwidth = bandwidthMatch * 30

        // 3. Peak hour bonus (0-15 points) — heavy tasks get bonus during peak hours
        let peakBonus: Double
        if profile.isPeakHour && task.cognitiveLoad >= 7 {
            peakBonus = 15
        } else if profile.isPeakHour && task.cognitiveLoad >= 5 {
            peakBonus = 8
        } else if !profile.isPeakHour && task.cognitiveLoad <= 4 {
            peakBonus = 10 // light tasks bonus during off-peak
        } else {
            peakBonus = 0
        }

        // 4. Fatigue penalty (0 to -20 points) — penalize heavy tasks after fatigue sequence
        let fatiguePenalty: Double
        if profile.isFatigueSequence && task.cognitiveLoad >= 7 {
            fatiguePenalty = -20
        } else if profile.consecutiveHighLoadTasks >= 1 && task.cognitiveLoad >= 8 {
            fatiguePenalty = -10
        } else {
            fatiguePenalty = 0
        }

        // 5. Category variety bonus (0-5 points) — avoid same-type fatigue
        let varietyBonus: Double = 5 // TODO: track last category and bonus for switching

        // 6. In-progress tasks get a boost to avoid context-switching
        let statusBonus: Double = task.status == .inProgress ? 15 : 0

        return urgency + bandwidth + peakBonus + fatiguePenalty + varietyBonus + statusBonus
    }

    /// Smart schedule: tasks ordered by bandwidth-aware scheduling score
    func suggestSchedule(tasks: [CATSTask], profile: CognitiveProfile) -> [CATSTask] {
        let active = tasks.filter { $0.status != .completed }
        return active.sorted { a, b in
            schedulingScore(for: a, profile: profile) > schedulingScore(for: b, profile: profile)
        }
    }

    /// Human-readable explanation of why a task is recommended now
    func schedulingReason(for task: CATSTask, profile: CognitiveProfile) -> String {
        let range = profile.optimalLoadRange
        let match = profile.bandwidthMatch(for: task.cognitiveLoad)

        if task.isOverdue {
            return "Overdue — needs immediate attention"
        }
        if task.isUrgent {
            return "Due very soon — high priority"
        }
        if task.status == .inProgress {
            return "Already in progress — maintain focus"
        }
        if profile.isPeakHour && task.cognitiveLoad >= 7 && match > 0.8 {
            return "Peak hour + high energy — ideal for this heavy task"
        }
        if match >= 0.9 {
            return "Perfect bandwidth match (load \(task.cognitiveLoad) fits \(range.lowerBound)-\(range.upperBound))"
        }
        if match >= 0.7 {
            return "Good fit for current energy (\(Int(profile.currentEnergy))%)"
        }
        if profile.isFatigueSequence && task.cognitiveLoad <= 4 {
            return "Light task — good for recovery after heavy work"
        }
        if task.timeRemaining < 3600 * 6 {
            return "Approaching deadline"
        }
        return "Scheduled based on priority"
    }

    func shouldSuggestBreak(profile: CognitiveProfile) -> (shouldBreak: Bool, message: String, cat: String) {
        let cycle = profile.recoveryCycle
        if cycle.needsBreak {
            return (true, cycle.message, CatFaces.page.breakHint)
        }
        return (false, "", "")
    }

    // MARK: - Intelligent Day Scheduling (burnout prevention)

    /// A single block in the generated schedule
    struct ScheduleBlock: Identifiable {
        let id = UUID()
        let startTime: Date
        let endTime: Date
        let type: BlockType
        let task: CATSTask?
        let label: String
        let reason: String

        enum BlockType: String {
            case deepWork = "Deep Work"
            case lightWork = "Light Work"
            case recoveryBreak = "Recovery Break"
            case microBreak = "Micro Break"
        }

        var durationMinutes: Int {
            Int(endTime.timeIntervalSince(startTime) / 60)
        }
    }

    /// Model the expected energy curve for a given hour of day
    func predictedEnergy(atHour hour: Int, profile: CognitiveProfile) -> Double {
        let isPeak = profile.peakHours.contains(hour)
        // Base circadian energy curve
        let base: Double
        switch hour {
        case 6...7:   base = 55  // waking up
        case 8:       base = 70  // warming up
        case 9...11:  base = 90  // morning peak
        case 12:      base = 60  // post-lunch dip
        case 13:      base = 55  // afternoon slump
        case 14...15: base = 75  // afternoon recovery
        case 16...17: base = 65  // winding down
        case 18...19: base = 50  // evening
        case 20...21: base = 40  // late evening
        default:      base = 30  // night
        }
        // Adjust for user-configured peak hours
        return isPeak ? min(100, base + 15) : base
    }

    /// What cognitive load range is ideal for a given hour
    func optimalLoadRange(atHour hour: Int, profile: CognitiveProfile) -> ClosedRange<Int> {
        let energy = predictedEnergy(atHour: hour, profile: profile)
        if energy >= 80 { return 7...10 }
        if energy >= 65 { return 5...8 }
        if energy >= 50 { return 3...6 }
        if energy >= 35 { return 1...5 }
        return 1...3
    }

    /// Generate an intelligent day schedule that prevents burnout
    /// - Parameters:
    ///   - tasks: Active tasks to schedule
    ///   - profile: User's cognitive profile
    ///   - busySlots: Existing calendar events (start, end) to avoid
    ///   - startFrom: When to start scheduling (default: now)
    ///   - endBy: When to stop scheduling (default: 10 PM today)
    /// - Returns: Ordered schedule blocks with tasks + breaks
    func generateDaySchedule(
        tasks: [CATSTask],
        profile: CognitiveProfile,
        busySlots: [(start: Date, end: Date)] = [],
        startFrom: Date? = nil,
        endBy: Date? = nil
    ) -> [ScheduleBlock] {
        let calendar = Calendar.current
        let now = Date()

        // Round start to next 15-minute mark
        let rawStart = startFrom ?? now
        var startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rawStart)
        let minute = startComponents.minute ?? 0
        startComponents.minute = ((minute + 14) / 15) * 15 // round up to next 15
        let scheduleStart = calendar.date(from: startComponents) ?? rawStart

        // Default end: 10 PM today (or tomorrow if it's already past 10 PM)
        let defaultEnd: Date = {
            var end = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
            if end <= scheduleStart {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            return end
        }()
        let scheduleEnd = endBy ?? defaultEnd

        // Sort tasks by priority: urgent first, then by cognitive load matching energy curve
        let activeTasks = tasks.filter { $0.status != .completed }
        guard !activeTasks.isEmpty else { return [] }

        // Build free time slots by removing busy slots
        var freeSlots = buildFreeSlots(
            from: scheduleStart,
            to: scheduleEnd,
            avoiding: busySlots
        )

        // Assign tasks to optimal slots
        var schedule: [ScheduleBlock] = []
        var remainingTasks = activeTasks.sorted { $0.priorityScore > $1.priorityScore }
        var consecutiveHeavy = 0

        while !remainingTasks.isEmpty && !freeSlots.isEmpty {
            guard let (_, slot) = bestSlot(
                for: remainingTasks[0],
                in: freeSlots,
                profile: profile,
                consecutiveHeavy: consecutiveHeavy
            ) else {
                // Can't fit this task anywhere — skip it
                remainingTasks.removeFirst()
                continue
            }

            let task = remainingTasks.removeFirst()
            let duration = min(task.estimatedMinutes, Int(slot.end.timeIntervalSince(slot.start) / 60))
            let blockEnd = slot.start.addingTimeInterval(Double(duration) * 60)

            // Determine block type
            let blockType: ScheduleBlock.BlockType = task.cognitiveLoad >= 7 ? .deepWork : .lightWork
            let hour = calendar.component(.hour, from: slot.start)
            let loadRange = optimalLoadRange(atHour: hour, profile: profile)
            let matchDesc = loadRange.contains(task.cognitiveLoad) ? "optimal match" : "adjusted"

            schedule.append(ScheduleBlock(
                startTime: slot.start,
                endTime: blockEnd,
                type: blockType,
                task: task,
                label: task.title,
                reason: "Load \(task.cognitiveLoad)/10 at \(hour):00 (\(matchDesc))"
            ))

            // Track consecutive heavy tasks for break insertion
            if task.cognitiveLoad >= 7 {
                consecutiveHeavy += 1
            } else {
                consecutiveHeavy = 0
            }

            // Insert recovery break after heavy work or after 2+ consecutive heavy tasks
            let needsBreak = consecutiveHeavy >= 2 || (task.cognitiveLoad >= 8 && duration >= 60)
            let breakMinutes = consecutiveHeavy >= 2 ? 15 : (task.cognitiveLoad >= 8 ? 10 : 5)

            if needsBreak {
                let breakStart = blockEnd
                let breakEnd = breakStart.addingTimeInterval(Double(breakMinutes) * 60)
                if breakEnd <= scheduleEnd {
                    schedule.append(ScheduleBlock(
                        startTime: breakStart,
                        endTime: breakEnd,
                        type: consecutiveHeavy >= 2 ? .recoveryBreak : .microBreak,
                        task: nil,
                        label: consecutiveHeavy >= 2 ? "Recovery Break" : "Micro Break",
                        reason: consecutiveHeavy >= 2
                            ? "Burnout prevention: \(consecutiveHeavy) heavy tasks in a row"
                            : "Mental reset after intense work"
                    ))
                    consecutiveHeavy = 0

                    // Update free slots to account for break
                    freeSlots = updateFreeSlots(freeSlots, removing: (breakStart, breakEnd))
                }
            }

            // Standard micro break between all tasks (5 min buffer)
            if !needsBreak {
                let bufferEnd = blockEnd.addingTimeInterval(5 * 60)
                freeSlots = updateFreeSlots(freeSlots, removing: (slot.start, bufferEnd))
            } else {
                freeSlots = updateFreeSlots(freeSlots, removing: (slot.start, blockEnd))
            }
        }

        return schedule.sorted { $0.startTime < $1.startTime }
    }

    /// Format a schedule into a human-readable string
    func formatSchedule(_ blocks: [ScheduleBlock]) -> String {
        guard !blocks.isEmpty else { return "No tasks to schedule." }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        var lines: [String] = ["Today's Smart Schedule:"]
        lines.append("")

        var totalWork = 0
        var totalBreak = 0

        for block in blocks {
            let start = timeFmt.string(from: block.startTime)
            let end = timeFmt.string(from: block.endTime)
            let icon: String
            switch block.type {
            case .deepWork:     icon = "🧠"
            case .lightWork:    icon = "📖"
            case .recoveryBreak: icon = "💚"
            case .microBreak:   icon = "☕"
            }

            if block.task != nil {
                lines.append("\(icon) \(start)–\(end): \(block.label) [\(block.durationMinutes)min]")
                lines.append("   \(block.reason)")
                totalWork += block.durationMinutes
            } else {
                lines.append("\(icon) \(start)–\(end): \(block.label) [\(block.durationMinutes)min]")
                lines.append("   \(block.reason)")
                totalBreak += block.durationMinutes
            }
        }

        lines.append("")
        lines.append("Total: \(totalWork)min work · \(totalBreak)min recovery")
        let taskCount = blocks.filter { $0.task != nil }.count
        lines.append("\(taskCount) tasks scheduled with burnout prevention")

        return lines.joined(separator: "\n")
    }

    // MARK: - Schedule Helpers

    private func buildFreeSlots(
        from start: Date, to end: Date, avoiding busy: [(start: Date, end: Date)]
    ) -> [(start: Date, end: Date)] {
        var slots: [(start: Date, end: Date)] = [(start, end)]
        let sorted = busy.sorted { $0.start < $1.start }

        for event in sorted {
            var newSlots: [(start: Date, end: Date)] = []
            for slot in slots {
                if event.end <= slot.start || event.start >= slot.end {
                    // No overlap
                    newSlots.append(slot)
                } else {
                    // Split around the busy event
                    if event.start > slot.start {
                        newSlots.append((slot.start, event.start))
                    }
                    if event.end < slot.end {
                        newSlots.append((event.end, slot.end))
                    }
                }
            }
            slots = newSlots
        }

        // Filter out slots shorter than 15 minutes
        return slots.filter { $0.end.timeIntervalSince($0.start) >= 15 * 60 }
    }

    private func updateFreeSlots(
        _ slots: [(start: Date, end: Date)],
        removing used: (Date, Date)
    ) -> [(start: Date, end: Date)] {
        buildFreeSlots(from: slots.first?.start ?? Date(), to: slots.last?.end ?? Date(), avoiding: [used])
            .filter { slot in
                // Only keep slots that were in the original free set
                slots.contains { orig in
                    slot.start >= orig.start && slot.end <= orig.end
                }
            }
    }

    private func bestSlot(
        for task: CATSTask,
        in slots: [(start: Date, end: Date)],
        profile: CognitiveProfile,
        consecutiveHeavy: Int
    ) -> (Int, (start: Date, end: Date))? {
        let calendar = Calendar.current
        let needed = Double(task.estimatedMinutes) * 60

        var bestScore = -Double.infinity
        var bestIdx: Int?

        for (idx, slot) in slots.enumerated() {
            let available = slot.end.timeIntervalSince(slot.start)
            guard available >= min(needed, 15 * 60) else { continue } // need at least 15 min

            let hour = calendar.component(.hour, from: slot.start)
            let loadRange = optimalLoadRange(atHour: hour, profile: profile)

            var score: Double = 0

            // Match bonus: cognitive load fits this time slot's optimal range
            if loadRange.contains(task.cognitiveLoad) {
                score += 30
            } else {
                let distance = task.cognitiveLoad < loadRange.lowerBound
                    ? Double(loadRange.lowerBound - task.cognitiveLoad)
                    : Double(task.cognitiveLoad - loadRange.upperBound)
                score -= distance * 5
            }

            // Urgency: prefer earlier slots for urgent tasks
            if task.isUrgent || task.isOverdue {
                score += 20 - Double(idx) * 2
            }

            // Prefer earlier slots generally (don't procrastinate)
            score -= Double(idx) * 0.5

            // Burnout prevention: if we've had heavy tasks, prefer light task slots
            if consecutiveHeavy >= 2 && task.cognitiveLoad >= 7 {
                score -= 15
            }

            if score > bestScore {
                bestScore = score
                bestIdx = idx
            }
        }

        guard let idx = bestIdx else { return nil }
        return (idx, slots[idx])
    }

    // MARK: - Private Helpers

    func extractDeadline(_ text: String) -> Date {
        let calendar = Calendar.current
        let now = Date()

        // --- 1. Time-precise patterns (return exact offset, NO snap to 23:59) ---

        // "in an hour" / "in 1 hour"
        if text.contains("in an hour") || text.contains("in 1 hour") {
            return now.addingTimeInterval(3600)
        }

        // "in X hours"
        if let range = text.range(of: #"in (\d+) hours?"#, options: .regularExpression) {
            let match = String(text[range])
            let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let hours = Int(nums) {
                return now.addingTimeInterval(Double(hours) * 3600)
            }
        }

        // "in X minutes" / "in X mins"
        if let range = text.range(of: #"in (\d+)\s*(?:min(?:ute)?s?|mins)"#, options: .regularExpression) {
            let match = String(text[range])
            let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let mins = Int(nums) {
                return now.addingTimeInterval(Double(mins) * 60)
            }
        }

        // --- 2. Specific day names (snap to 23:59 of that day) ---

        let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for (idx, day) in dayNames.enumerated() {
            if text.contains(day) {
                let weekday = idx + 2 // Calendar weekday: Sun=1, Mon=2, ...
                let adjustedWeekday = weekday > 7 ? weekday - 7 : weekday
                if let next = calendar.nextDate(
                    after: now,
                    matching: DateComponents(weekday: adjustedWeekday),
                    matchingPolicy: .nextTime
                ) {
                    return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: next) ?? next
                }
            }
        }

        // --- 3. "in X days" (snap to 23:59, DST-safe) ---

        if let range = text.range(of: #"in (\d+) days?"#, options: .regularExpression) {
            let match = String(text[range])
            let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let days = Int(nums) {
                let base = calendar.date(byAdding: .day, value: days, to: now) ?? now
                return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: base) ?? base
            }
        }

        // --- 4. Relative day patterns (snap to 23:59, DST-safe) ---
        // Checked in order: longer/more-specific patterns first

        for pattern in dayDeadlinePatterns {
            if text.contains(pattern.pattern) {
                let base = calendar.date(byAdding: .day, value: pattern.daysOffset, to: now) ?? now
                return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: base) ?? base
            }
        }

        // "by end of day" / "by eod" / "by tonight"
        if text.contains("by end of day") || text.contains("by eod") || text.contains("by tonight") {
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? now
        }

        // --- 5. Default: end of today ---
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now)
            ?? now.addingTimeInterval(86400)
    }

    private func estimateDuration(_ cognitiveLoad: Int, text: String) -> Int {
        // Check for explicit duration
        if let range = text.range(of: #"(\d+)\s*(min|minute|minutes|hr|hour|hours)"#, options: .regularExpression) {
            let match = String(text[range])
            let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let val = Int(nums) {
                let raw = match.contains("hr") || match.contains("hour") ? val * 60 : val
                return CATSTask.snapDuration(raw)
            }
        }

        // Estimate based on cognitive load → snapped to 15/30/60
        switch cognitiveLoad {
        case 1...3: return 15
        case 4...6: return 30
        case 7...10: return 60
        default: return 30
        }
    }

    func inferCategory(_ cognitiveLoad: Int, text: String) -> TaskCategory {
        if text.contains("review") || text.contains("revise") || text.contains("proofread") {
            return .review
        }
        if text.contains("creative") || text.contains("design") || text.contains("draw") || text.contains("write essay") {
            return .creative
        }
        if cognitiveLoad >= 7 {
            return .deepWork
        }
        return .lightWork
    }

    private func cleanTitle(_ input: String) -> String {
        var title = input

        // Remove common prefixes
        let prefixes = [
            "i need to ", "i have to ", "i want to ", "i should ",
            "need to ", "have to ", "want to ", "gotta ",
            "finish ", "complete ", "do ", "work on ",
        ]
        let lower = title.lowercased()
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
                break
            }
        }

        // Remove deadline parts
        let deadlinePhrases = [
            "today", "tonight", "tomorrow", "by friday", "by monday",
            "by tuesday", "by wednesday", "by thursday", "by saturday",
            "by sunday", "this week", "next week",
            "by end of day", "by eod", "by tonight",
        ]
        var cleaned = title
        for phrase in deadlinePhrases {
            if let range = cleaned.lowercased().range(of: phrase) {
                // Remove the phrase and any leading "by " or trailing space
                var start = range.lowerBound
                if start > cleaned.startIndex {
                    let before = cleaned.index(before: start)
                    if cleaned[before] == " " { start = before }
                }
                cleaned.removeSubrange(start..<range.upperBound)
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }
}
