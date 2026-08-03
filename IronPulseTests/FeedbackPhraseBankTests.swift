import Foundation
import Testing
@testable import IronPulse

struct FeedbackPhraseBankTests {
    @Test func goodRepBankHasExactlyTwentyPhrases() {
        #expect(FeedbackPhraseBank.goodRepPhrases.count == 20)
    }

    @Test func notDeepEnoughBankHasExactlyTwentyPhrases() {
        #expect(FeedbackPhraseBank.notDeepEnoughPhrases.count == 20)
    }

    @Test func tooFastBankHasExactlyEightPhrases() {
        #expect(FeedbackPhraseBank.tooFastPhrases.count == 8)
    }

    @Test func randomPhraseAlwaysComesFromTheMatchingBank() {
        for _ in 0..<50 {
            let phrase = FeedbackPhraseBank.randomPhrase(for: .goodRep, language: .spanish)
            #expect(FeedbackPhraseBank.goodRepPhrases.contains { $0.es == phrase })
        }
    }

    @Test func everyPhraseHasNonEmptyTextInAllThreeLanguages() {
        let allPhrases = FeedbackPhraseBank.goodRepPhrases
            + FeedbackPhraseBank.notDeepEnoughPhrases
            + FeedbackPhraseBank.tooFastPhrases
        for phrase in allPhrases {
            for language in AppLanguage.allCases {
                #expect(!phrase.text(for: language).isEmpty)
            }
        }
    }
}
