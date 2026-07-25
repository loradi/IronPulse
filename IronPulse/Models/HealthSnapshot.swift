import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    var source: String
    var bodyMassKg: Double?
    var heightCm: Double?
    var biologicalSex: BiologicalSex
    var dateOfBirth: Date?
    var stepCount: Double?
    var activeEnergyKcal: Double?
    var restingHeartRateBPM: Double?
    var workoutMinutes: Double?
    var profile: UserProfile?

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        source: String = "HealthKit",
        bodyMassKg: Double? = nil,
        heightCm: Double? = nil,
        biologicalSex: BiologicalSex = .notSet,
        dateOfBirth: Date? = nil,
        stepCount: Double? = nil,
        activeEnergyKcal: Double? = nil,
        restingHeartRateBPM: Double? = nil,
        workoutMinutes: Double? = nil,
        profile: UserProfile? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.source = source
        self.bodyMassKg = bodyMassKg
        self.heightCm = heightCm
        self.biologicalSex = biologicalSex
        self.dateOfBirth = dateOfBirth
        self.stepCount = stepCount
        self.activeEnergyKcal = activeEnergyKcal
        self.restingHeartRateBPM = restingHeartRateBPM
        self.workoutMinutes = workoutMinutes
        self.profile = profile
    }
}
