import AVFoundation
import Foundation

/// Speaks the Smart Assistant's feedback phrases aloud via the
/// system's text-to-speech voice, in the app's currently selected
/// language. Configured with `.mixWithOthers` so it doesn't
/// interrupt music or podcasts playing during a workout.
@Observable
final class SmartAssistantAudioAnnouncer {
    private static let mutedDefaultsKey = "smart_assistant.audio_muted"

    private let synthesizer = AVSpeechSynthesizer()
    private let userDefaults: UserDefaults

    var isMuted: Bool {
        didSet {
            userDefaults.set(isMuted, forKey: Self.mutedDefaultsKey)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isMuted = userDefaults.bool(forKey: Self.mutedDefaultsKey)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    }

    /// Cancels any utterance still being spoken before starting the
    /// new one — the latest feedback always wins over a stale one
    /// that hasn't finished yet (reps can complete faster than a
    /// sentence takes to say).
    func speak(_ text: String, language: AppLanguage) {
        guard !isMuted else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.speechLanguageCode)
        synthesizer.speak(utterance)
    }

    func toggleMute() {
        isMuted.toggle()
    }
}
