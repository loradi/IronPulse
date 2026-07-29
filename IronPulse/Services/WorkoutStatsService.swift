import Foundation

enum WorkoutStatsService {
    static func totalVolumeKg(_ logs: [WorkoutLog]) -> Double {
        finishedLogs(logs).reduce(0) { $0 + volumeKg(of: $1) }
    }

    static func workoutCount(_ logs: [WorkoutLog]) -> Int {
        finishedLogs(logs).count
    }

    static func currentStreak(
        scheduledWeekdays: Set<Weekday>,
        logs: [WorkoutLog],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard !scheduledWeekdays.isEmpty else { return 0 }

        let completedDays = Set(finishedLogs(logs).map { calendar.startOfDay(for: $0.startDate) })
        let startDay = calendar.startOfDay(for: today)
        var streak = 0

        for offset in 0..<3650 { // ~10 anos: limite defensivo, no hay racha real mas larga
            guard let cursor = calendar.date(byAdding: .day, value: -offset, to: startDay) else { break }
            let weekday = Weekday.today(calendar: calendar, now: cursor)
            guard scheduledWeekdays.contains(weekday) else { continue }
            guard completedDays.contains(cursor) else {
                if offset == 0 { continue }
                break
            }
            streak += 1
        }

        return streak
    }

    static func dailyVolume(
        _ logs: [WorkoutLog],
        lastDays: Int = 30,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [(date: Date, volumeKg: Double)] {
        var volumeByDay: [Date: Double] = [:]
        for log in finishedLogs(logs) {
            let day = calendar.startOfDay(for: log.startDate)
            volumeByDay[day, default: 0] += volumeKg(of: log)
        }

        let startDay = calendar.startOfDay(for: today)
        return (0..<lastDays).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startDay) else { return nil }
            return (date: day, volumeKg: volumeByDay[day] ?? 0)
        }
    }

    static func progress(
        for exerciseId: String,
        in logs: [WorkoutLog],
        calendar: Calendar = .current
    ) -> [(date: Date, maxWeightKg: Double)] {
        var maxWeightByDay: [Date: Double] = [:]
        for log in finishedLogs(logs) {
            let day = calendar.startOfDay(for: log.startDate)
            for set in log.completedSets where set.isCompleted && set.exerciseId == exerciseId {
                maxWeightByDay[day] = max(maxWeightByDay[day] ?? 0, set.weightKg)
            }
        }
        return maxWeightByDay
            .map { (date: $0.key, maxWeightKg: $0.value) }
            .sorted { $0.date < $1.date }
    }

    enum WeekdayStatus: Equatable {
        case notScheduled
        case pending
        case completed
    }

    static func weekStrip(
        scheduledWeekdays: Set<Weekday>,
        logs: [WorkoutLog],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [(weekday: Weekday, status: WeekdayStatus, isToday: Bool)] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }

        let completedDays = Set(finishedLogs(logs).map { calendar.startOfDay(for: $0.startDate) })
        let todayWeekday = Weekday.today(calendar: calendar, now: today)

        let days = (0..<7).compactMap { offset -> (weekday: Weekday, status: WeekdayStatus, isToday: Bool)? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let weekday = Weekday.today(calendar: calendar, now: date)

            guard scheduledWeekdays.contains(weekday) else {
                return (weekday, .notScheduled, weekday == todayWeekday)
            }

            let status: WeekdayStatus = completedDays.contains(calendar.startOfDay(for: date)) ? .completed : .pending
            return (weekday, status, weekday == todayWeekday)
        }

        return days.sorted { $0.weekday.rawValue < $1.weekday.rawValue }
    }

    static func todaysCompletedLog(logs: [WorkoutLog], today: Date = Date(), calendar: Calendar = .current) -> WorkoutLog? {
        let todayStart = calendar.startOfDay(for: today)
        return finishedLogs(logs).first { calendar.startOfDay(for: $0.startDate) == todayStart }
    }

    private static func finishedLogs(_ logs: [WorkoutLog]) -> [WorkoutLog] {
        logs.filter { $0.endDate != nil }
    }

    private static func volumeKg(of log: WorkoutLog) -> Double {
        log.completedSets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.weightKg * Double($1.repsCompleted) }
    }
}
