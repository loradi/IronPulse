import AVFoundation
import Foundation
import Testing
@testable import IronPulse

struct SmartAssistantAudioAnnouncerTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "SmartAssistantAudioAnnouncerTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func mutedDefaultsToFalseWhenNothingStored() {
        let announcer = SmartAssistantAudioAnnouncer(userDefaults: makeIsolatedDefaults())
        #expect(announcer.isMuted == false)
    }

    @Test func toggleMutePersistsAcrossInstancesSharingTheSameDefaults() {
        let defaults = makeIsolatedDefaults()
        let first = SmartAssistantAudioAnnouncer(userDefaults: defaults)
        first.toggleMute()
        #expect(first.isMuted == true)

        let second = SmartAssistantAudioAnnouncer(userDefaults: defaults)
        #expect(second.isMuted == true)
    }

    private struct FakeVoiceCandidate: SpeechVoiceCandidate {
        let language: String
        let quality: AVSpeechSynthesisVoiceQuality
    }

    @Test func bestVoicePicksThePremiumVoiceOverEnhancedAndDefault() {
        let candidates = [
            FakeVoiceCandidate(language: "es-ES", quality: .default),
            FakeVoiceCandidate(language: "es-ES", quality: .premium),
            FakeVoiceCandidate(language: "es-ES", quality: .enhanced),
            FakeVoiceCandidate(language: "en-US", quality: .premium),
        ]
        let best = SmartAssistantAudioAnnouncer.bestVoice(among: candidates, language: "es-ES")
        #expect(best?.quality == .premium)
    }

    @Test func bestVoiceIgnoresCandidatesForOtherLanguages() {
        let candidates = [FakeVoiceCandidate(language: "fr-FR", quality: .premium)]
        let best = SmartAssistantAudioAnnouncer.bestVoice(among: candidates, language: "es-ES")
        #expect(best == nil)
    }

    @Test func makeUtteranceUsesTheTunedRateAndPitch() {
        let utterance = SmartAssistantAudioAnnouncer.makeUtterance("hola", voice: nil)
        #expect(utterance.rate == 0.47)
        #expect(utterance.pitchMultiplier == 0.92)
    }

    @Test func resolvedVoiceCachesTheSameInstanceForRepeatedCallsWithTheSameLanguage() {
        let announcer = SmartAssistantAudioAnnouncer(userDefaults: makeIsolatedDefaults())
        let first = announcer.resolvedVoice(for: .spanish)
        let second = announcer.resolvedVoice(for: .spanish)
        #expect(first === second)
    }

    @Test func audioURLIsNilWhenPhraseIDIsEmpty() {
        let phrase = LocalizedString(es: "x", en: "x", fr: "x")
        #expect(SmartAssistantAudioAnnouncer.audioURL(for: phrase, language: .spanish) == nil)
    }

    @Test func audioURLIsNilWhenNoBundledClipMatchesTheID() {
        let phrase = LocalizedString(es: "x", en: "x", fr: "x", id: "does_not_exist_yet")
        #expect(SmartAssistantAudioAnnouncer.audioURL(for: phrase, language: .spanish) == nil)
    }
}
