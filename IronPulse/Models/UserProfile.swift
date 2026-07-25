import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var birthDate: Date?
    var biologicalSex: BiologicalSex
    var heightCm: Double?
    var weightKg: Double?
    var experienceLevel: ExperienceLevel
    var fitnessGoal: FitnessGoal
    var trainingDaysPerWeek: Int
    var sessionDurationMinutes: Int
    var limitations: [String]
    var equipment: [EquipmentType]
    var syncsWithHealth: Bool
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HealthSnapshot.profile)
    var healthSnapshots: [HealthSnapshot]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutRoutine.profile)
    var routines: [WorkoutRoutine]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.profile)
    var workoutSessions: [WorkoutSession]

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date? = nil,
        biologicalSex: BiologicalSex = .notSet,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        experienceLevel: ExperienceLevel = .beginner,
        fitnessGoal: FitnessGoal = .maintenance,
        trainingDaysPerWeek: Int = 3,
        sessionDurationMinutes: Int = 60,
        limitations: [String] = [],
        equipment: [EquipmentType] = [.fullGym],
        syncsWithHealth: Bool = false,
        isActive: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        healthSnapshots: [HealthSnapshot] = [],
        routines: [WorkoutRoutine] = [],
        workoutSessions: [WorkoutSession] = []
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.experienceLevel = experienceLevel
        self.fitnessGoal = fitnessGoal
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.sessionDurationMinutes = sessionDurationMinutes
        self.limitations = limitations
        self.equipment = equipment
        self.syncsWithHealth = syncsWithHealth
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.healthSnapshots = healthSnapshots
        self.routines = routines
        self.workoutSessions = workoutSessions
    }

    var age: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    var activeRoutine: WorkoutRoutine? {
        routines.first { $0.isActive } ?? routines.sorted { $0.createdAt > $1.createdAt }.first
    }

    var latestHealthSnapshot: HealthSnapshot? {
        healthSnapshots.max { $0.capturedAt < $1.capturedAt }
    }

    func updateTimestamp() {
        updatedAt = Date()
    }
}
