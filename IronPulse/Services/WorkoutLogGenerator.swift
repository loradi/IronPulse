import Foundation
import SwiftData

enum WorkoutLogGenerator {
    /// Generates a log for `day`, inserts it into `context`, and saves — the shared
    /// "start a session" behavior used by both DashboardView and RoutineTabView.
    @MainActor
    static func startSession(
        for day: RoutineDay,
        routineName: String,
        profile: UserProfile,
        in context: ModelContext
    ) -> WorkoutLog {
        let previousWeights = WorkoutStatsService.mostRecentWeights(in: profile.workoutLogs)
        let log = generate(for: day, routineName: routineName, profile: profile, previousWeights: previousWeights)
        context.insert(log)
        try? context.save()
        return log
    }

    static func generate(
        for day: RoutineDay,
        routineName: String,
        profile: UserProfile,
        previousWeights: [String: Double] = [:]
    ) -> WorkoutLog {
        let log = WorkoutLog(
            routineName: routineName,
            dayTitle: day.title,
            profile: profile
        )

        var setIndex = 0
        for routineExercise in day.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            for _ in 0..<routineExercise.targetSets {
                let setLog = SetLog(
                    exerciseId: routineExercise.exercise.id,
                    setIndex: setIndex,
                    weightKg: previousWeights[routineExercise.exercise.id] ?? 0,
                    repsCompleted: routineExercise.targetRepsMin,
                    restSeconds: routineExercise.restSeconds,
                    targetRepsMin: routineExercise.targetRepsMin,
                    targetRepsMax: routineExercise.targetRepsMax
                )
                log.completedSets.append(setLog)
                setIndex += 1
            }
        }

        return log
    }
}
