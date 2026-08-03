import AVFoundation
import Foundation

/// A source of speech-voice metadata that `bestVoice(among:language:)`
/// can rank by quality. `AVSpeechSynthesisVoice` conforms below; tests
/// use a fake struct instead, so the ranking logic can be verified
/// without depending on which real voices happen to be installed on
/// the machine running the tests.
protocol SpeechVoiceCandidate {
    var language: String { get }
    var quality: AVSpeechSynthesisVoiceQuality { get }
}

extension AVSpeechSynthesisVoice: SpeechVoiceCandidate {}

/// Speaks the Smart Assistant's feedback phrases aloud via the
/// system's text-to-speech voice, in the app's currently selected
/// language. Picks the best-quality voice installed for that language
/// (falling back to the system default if the user hasn't downloaded
/// an Enhanced/Premium one in Settings > Accessibility > Spoken
/// Content > Voices) and speaks at a tuned rate/pitch, so it sounds
/// less robotic than the untouched system default. Configured with
/// `.mixWithOthers` so it doesn't interrupt music or podcasts playing
/// during a workout.
@Observable
final class SmartAssistantAudioAnnouncer {
    private static let mutedDefaultsKey = "smart_assistant.audio_muted"
    private static let speechRate: Float = 0.47
    private static let speechPitch: Float = 0.92

    private let synthesizer = AVSpeechSynthesizer()
    private let userDefaults: UserDefaults
    private var hasConfiguredAudioSession = false
    private var cachedVoices: [AppLanguage: AVSpeechSynthesisVoice] = [:]

    var isMuted: Bool {
        didSet {
            userDefaults.set(isMuted, forKey: Self.mutedDefaultsKey)
            if isMuted {
                stop()
            }
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isMuted = userDefaults.bool(forKey: Self.mutedDefaultsKey)
    }

    /// Cancels any utterance still being spoken before starting the
    /// new one — the latest feedback always wins over a stale one
    /// that hasn't finished yet (reps can complete faster than a
    /// sentence takes to say).
    func speak(_ text: String, language: AppLanguage) {
        guard !isMuted else { return }
        if !hasConfiguredAudioSession {
            hasConfiguredAudioSession = true
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = Self.makeUtterance(text, voice: resolvedVoice(for: language))
        synthesizer.speak(utterance)
    }

    /// Immediately silences any utterance currently being spoken.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func toggleMute() {
        isMuted.toggle()
    }

    /// Picks the best-quality installed voice for `language`, caching
    /// the result so `AVSpeechSynthesisVoice.speechVoices()` - a full
    /// scan of every voice installed on the device - isn't repeated on
    /// every spoken phrase.
    func resolvedVoice(for language: AppLanguage) -> AVSpeechSynthesisVoice? {
        if let cached = cachedVoices[language] { return cached }
        let code = language.speechLanguageCode
        let voice = Self.bestVoice(among: AVSpeechSynthesisVoice.speechVoices(), language: code)
            ?? AVSpeechSynthesisVoice(language: code)
        cachedVoices[language] = voice
        return voice
    }

    /// Pure ranking logic, generic over `SpeechVoiceCandidate` so it's
    /// testable with fake candidates instead of the real system voice
    /// list. Picks the highest-quality candidate matching `language`
    /// exactly (`.premium` > `.enhanced` > `.default`).
    static func bestVoice<V: SpeechVoiceCandidate>(among candidates: [V], language: String) -> V? {
        candidates
            .filter { $0.language == language }
            .max { $0.quality.rawValue < $1.quality.rawValue }
    }

    static func makeUtterance(_ text: String, voice: AVSpeechSynthesisVoice?) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        return utterance
    }
}
