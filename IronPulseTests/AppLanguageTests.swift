import XCTest
@testable import IronPulse

final class AppLanguageTests: XCTestCase {
    func testSinValorGuardadoYSistemaEnInglesDevuelveIngles() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: nil, preferredLanguages: ["en-US"]), .english)
    }

    func testSinValorGuardadoYSistemaEnFrancesDevuelveFrances() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: nil, preferredLanguages: ["fr-FR"]), .french)
    }

    func testSinValorGuardadoYSistemaEnOtroIdiomaDevuelveEspanol() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: nil, preferredLanguages: ["de-DE"]), .spanish)
    }

    func testValorGuardadoTienePrioridadSobreElSistema() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: "fr", preferredLanguages: ["en-US"]), .french)
    }

    func testValorGuardadoInvalidoCaeAlSistema() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: "de", preferredLanguages: ["fr-FR"]), .french)
    }
}
