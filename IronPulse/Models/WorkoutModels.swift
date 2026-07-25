import Foundation
import SwiftData

@Model
final class WorkoutRoutine {
    @Attribute(.unique) var id: UUID
    var name: String
    var goal: FitnessGoal
    var experienceLevel: ExperienceLevel
    var daysPerWeek: Int
    var createdAt: Date
    var isActive: Bool
    var profile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \RoutineDay.routine)
    var days: [RoutineDay]

    init(
        id: UUID = UUID(),
        name: String,
        goal: FitnessGoal,
        experienceLevel: ExperienceLevel,
        daysPerWeek: Int,
        createdAt: Date = Date(),
        isActive: Bool = true,
        profile: UserProfile? = nil,
        days: [RoutineDay] = []
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.experienceLevel = experienceLevel
        self.daysPerWeek = daysPerWeek
        self.createdAt = createdAt
        self.isActive = isActive
        self.profile = profile
        self.days = days
    }
}

@Model
final class RoutineDay {
    @Attribute(.unique) var id: UUID
    var title: String
    var dayIndex: Int
    var routine: WorkoutRoutine?

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.day)
    var exercises: [RoutineExercise]

    init(
        id: UUID = UUID(),
        title: String,
        dayIndex: Int,
        routine: WorkoutRoutine? = nil,
        exercises: [RoutineExercise] = []
    ) {
        self.id = id
        self.title = title
        self.dayIndex = dayIndex
        self.routine = routine
        self.exercises = exercises
    }
}

@Model
final class RoutineExercise {
    @Attribute(.unique) var id: UUID
    var wgerExerciseID: Int?
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: EquipmentType
    var sets: Int
    var repRange: String
    var targetRPE: Int
    var restSeconds: Int
    var instructions: String
    var demoImageURL: String?
    var orderIndex: Int
    var day: RoutineDay?

    init(
        id: UUID = UUID(),
        wgerExerciseID: Int? = nil,
        name: String,
        muscleGroup: MuscleGroup,
        equipment: EquipmentType,
        sets: Int,
        repRange: String,
        targetRPE: Int,
        restSeconds: Int,
        instructions: String = "",
        demoImageURL: String? = nil,
        orderIndex: Int,
        day: RoutineDay? = nil
    ) {
        self.id = id
        self.wgerExerciseID = wgerExerciseID
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.sets = sets
        self.repRange = repRange
        self.targetRPE = targetRPE
        self.restSeconds = restSeconds
        self.instructions = instructions
        self.demoImageURL = demoImageURL
        self.orderIndex = orderIndex
        self.day = day
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var title: String
    var profile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutLogSet.session)
    var sets: [WorkoutLogSet]

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        title: String,
        profile: UserProfile? = nil,
        sets: [WorkoutLogSet] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.profile = profile
        self.sets = sets
    }
}

@Model
final class WorkoutLogSet {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var setIndex: Int
    var previousWeightKg: Double?
    var weightKg: Double?
    var reps: Int
    var rpe: Int
    var isCompleted: Bool
    var completedAt: Date?
    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        setIndex: Int,
        previousWeightKg: Double? = nil,
        weightKg: Double? = nil,
        reps: Int = 10,
        rpe: Int = 7,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        session: WorkoutSession? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.previousWeightKg = previousWeightKg
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.session = session
    }
}
