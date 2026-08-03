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
}
