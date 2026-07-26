import Foundation

enum WorkoutLogGenerator {
    static func generate(for day: RoutineDay, routineName: String, profile: UserProfile) -> WorkoutLog {
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
                    weightKg: 0,
                    repsCompleted: 0,
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
