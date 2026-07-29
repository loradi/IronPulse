import XCTest
@testable import IronPulse

final class AppLanguageBundleTests: XCTestCase {
    func testDisplayNameCambiaConAppLanguageCurrent() {
        let original = UserDefaults.standard.string(forKey: "appLanguage")
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: "appLanguage")
            } else {
                UserDefaults.standard.removeObject(forKey: "appLanguage")
            }
        }

        UserDefaults.standard.set(AppLanguage.spanish.rawValue, forKey: "appLanguage")
        let es = PrimaryGoal.strength.displayName

        UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: "appLanguage")
        let en = PrimaryGoal.strength.displayName

        XCTAssertNotEqual(es, en)
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
