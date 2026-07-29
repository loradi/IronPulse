import Foundation

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    static var current: UnitSystem {
        UnitSystem(rawValue: UserDefaults.standard.string(forKey: "unitSystem") ?? "") ?? .metric
    }

    var displayName: String {
        switch self {
        case .metric:
            return String(localized: "unit_system.metric", defaultValue: "Metrico (kg/cm)", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .imperial:
            return String(localized: "unit_system.imperial", defaultValue: "Imperial (lbs/pies)", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }
}

extension UnitSystem {
    static func kgToLbs(_ kg: Double) -> Double { kg * 2.2046226218 }
    static func lbsToKg(_ lbs: Double) -> Double { lbs / 2.2046226218 }

    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int((totalInches - Double(feet) * 12).rounded())
        return inches == 12 ? (feet + 1, 0) : (feet, inches)
    }

    static func feetInchesToCm(feet: Int, inches: Int) -> Double {
        (Double(feet) * 12 + Double(inches)) * 2.54
    }

    static func formattedWeight(_ kg: Double, system: UnitSystem) -> String {
        let value = system == .metric ? kg : kgToLbs(kg)
        let suffix = system == .metric ? "kg" : "lbs"
        return value.formatted(.number.precision(.fractionLength(1))) + " " + suffix
    }

    static func formattedHeight(_ cm: Double, system: UnitSystem) -> String {
        switch system {
        case .metric:
            return cm.formatted(.number.precision(.fractionLength(0...1))) + " cm"
        case .imperial:
            let (feet, inches) = cmToFeetInches(cm)
            return "\(feet)'\(inches)\""
        }
    }
}
