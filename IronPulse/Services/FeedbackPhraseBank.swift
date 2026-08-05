import Foundation

extension LocalizedString {
    func text(for language: AppLanguage) -> String {
        switch language {
        case .spanish: return es
        case .english: return en
        case .french: return fr
        }
    }
}

/// Curated phrase banks for the Smart Assistant's spoken/on-screen
/// feedback, loaded once from the bundled `FeedbackPhrases.json` (see
/// `scripts/generate_smart_assistant_audio.py` for how each phrase's
/// pre-recorded audio clip is generated from this same content). A
/// fresh random phrase is chosen per completed rep so the same line
/// doesn't repeat every time. `.notDeepEnough` and `.tooFast` get
/// separate banks instead of one shared "corrective" pool: mixing them
/// would let a range-of-motion problem get announced as a speed
/// problem, since the two conditions are detected independently by
/// `RepCounterEngine` and are not interchangeable advice.
enum FeedbackPhraseBank {
    private struct PhraseBankDTO: Codable {
        let goodRep: [LocalizedString]
        let notDeepEnough: [LocalizedString]
        let tooFast: [LocalizedString]
        let badForm: [LocalizedString]
    }

    private static let bank: PhraseBankDTO = loadBank()

    private static func loadBank() -> PhraseBankDTO {
        guard let url = Bundle.main.url(forResource: "FeedbackPhrases", withExtension: "json") else {
            assertionFailure("FeedbackPhrases.json missing from bundle")
            return PhraseBankDTO(goodRep: [], notDeepEnough: [], tooFast: [], badForm: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PhraseBankDTO.self, from: data)
        } catch {
            assertionFailure("Failed to load FeedbackPhrases.json: \(error)")
            return PhraseBankDTO(goodRep: [], notDeepEnough: [], tooFast: [], badForm: [])
        }
    }

    static let goodRepPhrases: [LocalizedString] = bank.goodRep
    static let notDeepEnoughPhrases: [LocalizedString] = bank.notDeepEnough
    static let tooFastPhrases: [LocalizedString] = bank.tooFast
    static let badFormPhrases: [LocalizedString] = bank.badForm

    static func randomPhrase(for feedback: FormFeedback) -> LocalizedString {
        let bank = phrases(for: feedback)
        return bank.randomElement() ?? LocalizedString(es: "", en: "", fr: "")
    }

    private static func phrases(for feedback: FormFeedback) -> [LocalizedString] {
        switch feedback {
        case .goodRep: return goodRepPhrases
        case .notDeepEnough: return notDeepEnoughPhrases
        case .tooFast: return tooFastPhrases
        case .badForm: return badFormPhrases
        }
    }
}
