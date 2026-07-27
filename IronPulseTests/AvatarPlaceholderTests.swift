import XCTest
@testable import IronPulse

final class AvatarPlaceholderTests: XCTestCase {
    func testDosPalabrasDevuelveDosIniciales() {
        XCTAssertEqual(initials(from: "Diego Lora"), "DL")
    }

    func testUnaPalabraDevuelveUnaInicial() {
        XCTAssertEqual(initials(from: "Diego"), "D")
    }

    func testNombreVacioDevuelveSignoDePregunta() {
        XCTAssertEqual(initials(from: "   "), "?")
    }

    func testTresPalabrasUsaSoloLasDosPrimeras() {
        XCTAssertEqual(initials(from: "Diego Andres Lora"), "DA")
    }
}
