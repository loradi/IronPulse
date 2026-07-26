import Foundation

#if canImport(HealthKit)
import HealthKit

final class HealthKitProfileImporter {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }

        if let leanBodyMass = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanBodyMass)
        }

        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }

        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }

        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        if let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRate)
        }

        if let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(biologicalSex)
        }

        if let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dateOfBirth)
        }

        types.insert(HKObjectType.workoutType())
        return types
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitProfileImporterError.healthDataUnavailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func makeSnapshot(for profile: UserProfile? = nil) async throws -> HealthSnapshot {
        guard isHealthDataAvailable else {
            throw HealthKitProfileImporterError.healthDataUnavailable
        }

        async let bodyMass = latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        async let leanBodyMass = latestQuantity(.leanBodyMass, unit: .gramUnit(with: .kilo))
        async let height = latestQuantity(.height, unit: .meterUnit(with: .centi))
        async let steps = cumulativeQuantity(.stepCount, unit: .count(), daysBack: 7)
        async let activeEnergy = cumulativeQuantity(.activeEnergyBurned, unit: .kilocalorie(), daysBack: 7)
        async let restingHeartRate = latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let workoutMinutes = workoutMinutes(daysBack: 7)

        let snapshot = HealthSnapshot(
            bodyMassKg: try await bodyMass,
            leanBodyMassKg: try await leanBodyMass,
            heightCm: try await height,
            biologicalSex: readBiologicalSex(),
            dateOfBirth: readDateOfBirth(),
            stepCount: try await steps,
            activeEnergyKcal: try await activeEnergy,
            restingHeartRateBPM: try await restingHeartRate,
            workoutMinutes: try await workoutMinutes,
            profile: profile
        )

        apply(snapshot, to: profile)
        return snapshot
    }

    private func apply(_ snapshot: HealthSnapshot, to profile: UserProfile?) {
        guard let profile else { return }

        if let bodyMassKg = snapshot.bodyMassKg {
            profile.weightKg = bodyMassKg
        }

        if let heightCm = snapshot.heightCm {
            profile.heightCm = heightCm
        }

        if let dateOfBirth = snapshot.dateOfBirth,
           let years = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year,
           years > 0 {
            profile.age = years
        }
    }

    private func readBiologicalSex() -> BiologicalSex {
        do {
            switch try healthStore.biologicalSex().biologicalSex {
            case .female:
                return .female
            case .male:
                return .male
            case .other:
                return .other
            case .notSet:
                return .notSet
            @unknown default:
                return .notSet
            }
        } catch {
            return .notSet
        }
    }

    private func readDateOfBirth() -> Date? {
        do {
            let components = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: components)
        } catch {
            return nil
        }
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func cumulativeQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, daysBack: Int) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func workoutMinutes(daysBack: Int) async throws -> Double? {
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                let minutes = workouts.reduce(0.0) { $0 + ($1.duration / 60.0) }
                continuation.resume(returning: minutes)
            }

            healthStore.execute(query)
        }
    }
}

enum HealthKitProfileImporterError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "HealthKit no esta disponible en este dispositivo."
        }
    }
}
#else
final class HealthKitProfileImporter {
    var isHealthDataAvailable: Bool { false }

    func requestAuthorization() async throws {
        throw HealthKitProfileImporterError.healthDataUnavailable
    }

    func makeSnapshot(for profile: UserProfile? = nil) async throws -> HealthSnapshot {
        throw HealthKitProfileImporterError.healthDataUnavailable
    }
}

enum HealthKitProfileImporterError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        "HealthKit no esta disponible en esta plataforma."
    }
}
#endif
