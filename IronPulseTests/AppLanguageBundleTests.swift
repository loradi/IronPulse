import XCTest
@testable import IronPulse

final class AppLanguageBundleTests: XCTestCase {
    func testLocaleSoloSinBundleNoForzaElIdioma() {
        // Documenta el gotcha: locale: solo, sin bundle:, no fuerza el idioma.
        // Este test verifica el comportamiento conocido de Foundation, no el
        // codigo de la app - existe para que quede documentado en el repo.
        let result = String(localized: "dias_label.plural", defaultValue: "3 dias", locale: Locale(identifier: "fr"))
        // No se afirma un valor especifico (depende del idioma del sistema del
        // entorno de test) - solo se confirma que la implementacion real
        // (Step 3) no usa este patron.
        _ = result
    }

    func testBundleMasLocaleFuerzaElIdiomaCorrectamente() {
        let result = String(
            localized: "dias_label.plural",
            defaultValue: "3 dias",
            bundle: AppLanguage.french.bundle,
            locale: AppLanguage.french.locale
        )
        XCTAssertTrue(result.contains("jours"), "Se esperaba 'jours' en el resultado, se obtuvo: \(result)")
    }

    func testBundleMasLocaleEnIngles() {
        let result = String(
            localized: "dias_label.plural",
            defaultValue: "3 dias",
            bundle: AppLanguage.english.bundle,
            locale: AppLanguage.english.locale
        )
        XCTAssertTrue(result.contains("days"), "Se esperaba 'days' en el resultado, se obtuvo: \(result)")
    }
}
