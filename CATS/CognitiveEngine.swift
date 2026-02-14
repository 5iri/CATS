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

    private let deadlinePatterns: [(pattern: String, offset: TimeInterval)] = [
        ("today", 0),
        ("tonight", 0),
        ("tomorrow", 86400),
        ("day after tomorrow", 86400 * 2),
        ("next week", 86400 * 7),
        ("this week", 86400 * 3),
        ("in an hour", 3600),
        ("in 2 hours", 7200),
        ("in 3 hours", 10800),
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

    // MARK: - Scheduling

    func suggestSchedule(tasks: [CATSTask], profile: CognitiveProfile) -> [CATSTask] {
        let active = tasks.filter { $0.status != .completed }
        var sorted = active.sorted { $0.priorityScore > $1.priorityScore }

        // If in peak hours, prioritize high cognitive load tasks
        if profile.isPeakHour {
            sorted.sort { a, b in
                if a.cognitiveLoad != b.cognitiveLoad && a.cognitiveLoad >= 7 {
                    return true
                }
                return a.priorityScore > b.priorityScore
            }
        }

        // If energy is low, deprioritize high cognitive load
        if profile.currentEnergy < 40 {
            sorted.sort { a, b in
                if a.cognitiveLoad < b.cognitiveLoad && b.cognitiveLoad >= 7 {
                    return true
                }
                return a.priorityScore > b.priorityScore
            }
        }

        return sorted
    }

    func shouldSuggestBreak(profile: CognitiveProfile) -> (shouldBreak: Bool, message: String, cat: String) {
        if profile.needsFullBreak {
            return (
                true,
                "Time for a recovery break! You've been working hard.",
                CatFaces.page.breakHint
            )
        }
        if profile.needsMicroBreak {
            return (
                true,
                "Quick break? Your brain will thank you.",
                CatFaces.page.microBreak
            )
        }
        return (false, "", "")
    }

    // MARK: - Private Helpers

    func extractDeadline(_ text: String) -> Date {
        let calendar = Calendar.current

        // Check specific day names
        let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for (idx, day) in dayNames.enumerated() {
            if text.contains(day) {
                let weekday = idx + 2 // Calendar weekday: Sun=1, Mon=2, ...
                let adjustedWeekday = weekday > 7 ? weekday - 7 : weekday
                if let next = calendar.nextDate(
                    after: Date(),
                    matching: DateComponents(weekday: adjustedWeekday),
                    matchingPolicy: .nextTime
                ) {
                    return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: next) ?? next
                }
            }
        }

        // Check relative patterns
        for pattern in deadlinePatterns {
            if text.contains(pattern.pattern) {
                let base = Date().addingTimeInterval(pattern.offset)
                return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: base) ?? base
            }
        }

        // Check "in X days" pattern
        if let range = text.range(of: #"in (\d+) days?"#, options: .regularExpression) {
            let match = String(text[range])
            let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let days = Int(nums) {
                let base = Date().addingTimeInterval(Double(days) * 86400)
                return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: base) ?? base
            }
        }

        // Check "in X hours" pattern
        if let range = text.range(of: #"in (\d+) hours?"#, options: .regularExpression) {
            let match = String(text[range])
            let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let hours = Int(nums) {
                return Date().addingTimeInterval(Double(hours) * 3600)
            }
        }

        // Check "by <time>" patterns
        if text.contains("by tonight") || text.contains("by end of day") || text.contains("by eod") {
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: Date()) ?? Date()
        }

        // Default: end of today
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: Date())
            ?? Date().addingTimeInterval(86400)
    }

    private func estimateDuration(_ cognitiveLoad: Int, text: String) -> Int {
        // Check for explicit duration
        if let range = text.range(of: #"(\d+)\s*(min|minute|minutes|hr|hour|hours)"#, options: .regularExpression) {
            let match = String(text[range])
            let nums = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let val = Int(nums) {
                if match.contains("hr") || match.contains("hour") {
                    return val * 60
                }
                return val
            }
        }

        // Estimate based on cognitive load
        switch cognitiveLoad {
        case 1...3: return 30
        case 4...6: return 60
        case 7...8: return 90
        case 9...10: return 120
        default: return 60
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
