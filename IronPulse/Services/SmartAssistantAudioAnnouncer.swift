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

/// Speaks the Smart Assistant's feedback phrases aloud. Primary path:
/// plays a pre-recorded, human-quality audio clip bundled with the app
/// (one per phrase × language, generated once offline by
/// `scripts/generate_smart_assistant_audio.py`) — this is what makes
/// every user hear a natural voice regardless of what TTS voices their
/// device happens to have installed. Falls back to live system TTS
/// (the original fase 3 mechanism, tuned rate/pitch and best-available
/// installed voice) only when no bundled clip exists for a phrase — a
/// phrase added without regenerating its audio, or one with no `id`.
/// Configured with `.mixWithOthers` so it doesn't interrupt music or
/// podcasts playing during a workout.
@Observable
final class SmartAssistantAudioAnnouncer {
    private static let mutedDefaultsKey = "smart_assistant.audio_muted"
    private static let speechRate: Float = 0.47
    private static let speechPitch: Float = 0.92

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
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

    /// Whether either playback path is currently speaking — lets
    /// callers (e.g. the dismiss-timing logic in
    /// `SmartAssistantSheet`) wait for real completion instead of
    /// guessing a fixed delay.
    var isSpeaking: Bool { synthesizer.isSpeaking || (audioPlayer?.isPlaying ?? false) }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isMuted = userDefaults.bool(forKey: Self.mutedDefaultsKey)
    }

    /// Cancels any utterance/clip still playing before starting the
    /// new one — the latest feedback always wins over a stale one
    /// that hasn't finished yet (reps can complete faster than a
    /// phrase takes to play).
    func speak(_ phrase: LocalizedString, language: AppLanguage) {
        guard !isMuted else { return }
        if !hasConfiguredAudioSession {
            hasConfiguredAudioSession = true
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        }
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()

        if let url = Self.audioURL(for: phrase, language: language),
           let player = try? AVAudioPlayer(contentsOf: url) {
            audioPlayer = player
            player.play()
            return
        }

        let utterance = Self.makeUtterance(phrase.text(for: language), voice: resolvedVoice(for: language))
        synthesizer.speak(utterance)
    }

    /// Immediately silences any utterance/clip currently playing.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
    }

    func toggleMute() {
        isMuted.toggle()
    }

    /// The bundled URL for `phrase`'s pre-recorded clip in `language`,
    /// or `nil` if `phrase.id` is empty or no matching `.mp3` is
    /// bundled — either case triggers the live-TTS fallback in `speak`.
    static func audioURL(for phrase: LocalizedString, language: AppLanguage, bundle: Bundle = .main) -> URL? {
        guard !phrase.id.isEmpty else { return nil }
        return bundle.url(forResource: "\(phrase.id)_\(language.rawValue)", withExtension: "mp3")
    }

    /// Picks the best-quality installed voice for `language`, caching
    /// the result so `AVSpeechSynthesisVoice.speechVoices()` - a full
    /// scan of every voice installed on the device - isn't repeated on
    /// every spoken phrase. Only used by the live-TTS fallback path.
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
