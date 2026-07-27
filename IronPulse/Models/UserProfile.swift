import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var experienceLevel: ExperienceLevel
    var primaryGoal: PrimaryGoal
    var workoutDaysPerWeek: Int
    var preferredEquipment: [EquipmentType]
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HealthSnapshot.profile)
    var healthSnapshots: [HealthSnapshot]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutRoutine.profile)
    var routines: [WorkoutRoutine]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutLog.profile)
    var workoutLogs: [WorkoutLog]

    var activeRoutine: WorkoutRoutine? {
        routines.first { $0.isActive }
    }

    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        weightKg: Double,
        heightCm: Double,
        experienceLevel: ExperienceLevel = .beginner,
        primaryGoal: PrimaryGoal = .hypertrophy,
        workoutDaysPerWeek: Int = 3,
        preferredEquipment: [EquipmentType] = [.bodyweight],
        createdAt: Date = Date(),
        healthSnapshots: [HealthSnapshot] = [],
        routines: [WorkoutRoutine] = [],
        workoutLogs: [WorkoutLog] = []
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.experienceLevel = experienceLevel
        self.primaryGoal = primaryGoal
        self.workoutDaysPerWeek = workoutDaysPerWeek
        self.preferredEquipment = preferredEquipment
        self.createdAt = createdAt
        self.healthSnapshots = healthSnapshots
        self.routines = routines
        self.workoutLogs = workoutLogs
    }
}

extension UserProfile {
    /// Unico punto de activacion de rutinas: lo usan tanto el generador como el armador manual.
    /// Las rutinas viejas quedan con isActive = false a modo de historial, no se borran.
    func activate(_ routine: WorkoutRoutine, in context: ModelContext) {
        for existing in routines {
            existing.isActive = false
        }
        routine.isActive = true
        routine.profile = self
        context.insert(routine)
        try? context.save()
    }
}
