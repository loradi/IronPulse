import XCTest
@testable import IronPulse

final class UnitSystemTests: XCTestCase {
    func testKgToLbsConvierteCorrectamente() {
        XCTAssertEqual(UnitSystem.kgToLbs(100), 220.462, accuracy: 0.001)
    }

    func testLbsToKgConvierteCorrectamente() {
        XCTAssertEqual(UnitSystem.lbsToKg(220.462), 100, accuracy: 0.001)
    }

    func testCmToFeetInchesConvierteCorrectamente() {
        let result = UnitSystem.cmToFeetInches(175)
        XCTAssertEqual(result.feet, 5)
        XCTAssertEqual(result.inches, 9)
    }

    func testCmToFeetInchesRedondeaAlPieSiguienteEnElLimiteDe12Pulgadas() {
        // 71.6 pulgadas totales = 5 pies + 11.6" -> redondea a 12" -> debe subir a 6 pies, 0"
        let result = UnitSystem.cmToFeetInches(181.864)
        XCTAssertEqual(result.feet, 6)
        XCTAssertEqual(result.inches, 0)
    }

    func testFeetInchesToCmConvierteCorrectamente() {
        XCTAssertEqual(UnitSystem.feetInchesToCm(feet: 5, inches: 9), 175.26, accuracy: 0.01)
    }

    func testFormattedWeightEnMetricoUsaKgConUnDecimal() {
        XCTAssertEqual(UnitSystem.formattedWeight(68.34, system: .metric), "68.3 kg")
    }

    func testFormattedWeightEnImperialConvierteAyMuestraLbs() {
        XCTAssertEqual(UnitSystem.formattedWeight(100, system: .imperial), "220.5 lbs")
    }

    func testFormattedHeightEnMetricoUsaCm() {
        XCTAssertEqual(UnitSystem.formattedHeight(175, system: .metric), "175 cm")
    }

    func testFormattedHeightEnImperialUsaPiesYPulgadas() {
        XCTAssertEqual(UnitSystem.formattedHeight(175, system: .imperial), "5'9\"")
    }

    func testCurrentSinValorGuardadoDevuelveMetrico() {
        let original = UserDefaults.standard.string(forKey: "unitSystem")
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: "unitSystem")
            } else {
                UserDefaults.standard.removeObject(forKey: "unitSystem")
            }
        }
        UserDefaults.standard.removeObject(forKey: "unitSystem")
        XCTAssertEqual(UnitSystem.current, .metric)
    }

    func testCurrentConValorGuardadoDevuelveElValorGuardado() {
        let original = UserDefaults.standard.string(forKey: "unitSystem")
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: "unitSystem")
            } else {
                UserDefaults.standard.removeObject(forKey: "unitSystem")
            }
        }
        UserDefaults.standard.set("imperial", forKey: "unitSystem")
        XCTAssertEqual(UnitSystem.current, .imperial)
    }
}
