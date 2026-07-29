import XCTest
import SwiftData
@testable import IronPulse

final class UserProfileTests: XCTestCase {
    @MainActor
    func testBiologicalSexPorDefectoEsNotSet() {
        let profile = UserProfile(name: "Test", age: 30, weightKg: 70, heightCm: 170)
        XCTAssertEqual(profile.biologicalSex, .notSet)
    }

    @MainActor
    func testBiologicalSexEsIndependienteDelDeHealthSnapshot() {
        let profile = UserProfile(name: "Test", age: 30, weightKg: 70, heightCm: 170)
        profile.biologicalSex = .female

        let snapshot = HealthSnapshot(biologicalSex: .male, profile: profile)
        profile.healthSnapshots.append(snapshot)

        XCTAssertEqual(profile.biologicalSex, .female)
        XCTAssertEqual(profile.healthSnapshots.first?.biologicalSex, .male)
    }
}
