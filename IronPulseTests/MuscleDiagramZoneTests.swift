import XCTest
@testable import IronPulse

final class MuscleDiagramZoneTests: XCTestCase {
    func testPechoResaltaSoloZonaChest() {
        let result = zones(primary: .chest, secondary: [])
        XCTAssertEqual(result.highlighted, [.chest])
        XCTAssertEqual(result.dimmed, [])
    }

    func testEspaldaMapeaAZonaChest() {
        let result = zones(primary: .back, secondary: [])
        XCTAssertEqual(result.highlighted, [.chest])
    }

    func testSecundariosSeAtenuanSinDuplicarLaPrincipal() {
        // press de banca: principal pecho, secundarios triceps + hombros anteriores
        let result = zones(primary: .chest, secondary: [.triceps, .shoulders])
        XCTAssertEqual(result.highlighted, [.chest])
        XCTAssertEqual(result.dimmed, [.arms, .shoulders])
    }

    func testGluteosYPantorrillasMapeanAZonaLegs() {
        XCTAssertEqual(zones(primary: .glutes, secondary: []).highlighted, [.legs])
        XCTAssertEqual(zones(primary: .calves, secondary: []).highlighted, [.legs])
    }

    func testFullBodyResaltaTodasLasZonas() {
        let result = zones(primary: .fullBody, secondary: [])
        XCTAssertEqual(result.highlighted, Set(DiagramZone.allCases))
        XCTAssertEqual(result.dimmed, [])
    }
}
