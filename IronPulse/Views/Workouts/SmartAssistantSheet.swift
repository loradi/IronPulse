import SwiftUI

/// UI for the Smart Exercise Assistant: the full overlay (exercise
/// name, rep counter, feedback banner, Finish Set button) composited
/// on top of a live camera preview, with camera permission handling
/// and a front/back toggle. Rep counting is driven by
/// `SmartAssistantModel`, which runs real Vision-based pose detection
/// on the live camera feed.
struct SmartAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseID: String
    let exerciseName: String
    let targetReps: Int
    let onFinish: (Int) -> Void

    @State private var model: SmartAssistantModel

    init(exerciseID: String, exerciseName: String, targetReps: Int, onFinish: @escaping (Int) -> Void) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.targetReps = targetReps
        self.onFinish = onFinish
        _model = State(initialValue: SmartAssistantModel(
            exerciseID: exerciseID,
            targetReps: targetReps,
            onComplete: onFinish
        ))
    }

    var body: some View {
        ZStack {
            switch model.cameraController.authorizationState {
            case .authorized:
                CameraPreviewView(session: model.cameraController.session)
                    .ignoresSafeArea()
            case .denied:
                Color.black.ignoresSafeArea()
                permissionDeniedOverlay
            case .notDetermined:
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 24) {
                HStack {
                    Text(exerciseName)
                        .font(.wwHeadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        model.audioAnnouncer.toggleMute()
                    } label: {
                        Image(systemName: model.audioAnnouncer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(.white)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(toggleAudioLabel)
                    .accessibilityAddTraits(model.audioAnnouncer.isMuted ? .isSelected : [])
                    Button {
                        model.cameraController.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .foregroundStyle(.white)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(toggleCameraLabel)
                }
                .padding(.top, 60)
                .padding(.horizontal)

                if !model.personVisible {
                    Text(noPersonLabel)
                        .font(.wwHeadline)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                } else if let feedbackMessage = model.feedbackMessage {
                    Text(feedbackMessage)
                        .font(.wwHeadline)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.ironAccent.opacity(0.2), in: RoundedRectangle(cornerRadius: 20))
                        .foregroundStyle(Color.ironAccent)
                        .padding(.horizontal)
                }

                Spacer()

                Text("\(model.repCount) / \(targetReps)")
                    .font(.wwDisplay)
                    .foregroundStyle(Color.ironAccent)

                Spacer()

                Button(finishSetLabel) {
                    model.finish()
                    dismiss()
                }
                .buttonStyle(PrimarySportButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .task {
            await model.cameraController.requestAuthorizationIfNeeded()
            if model.cameraController.authorizationState == .authorized {
                model.start()
            }
        }
        .onChange(of: model.didFinish) { _, done in
            guard done else { return }
            // Give the just-spoken completion phrase time to finish
            // playing before the sheet (and its AVSpeechSynthesizer)
            // gets torn down. A pragmatic fixed delay, not a real
            // completion callback.
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            }
        }
        .onDisappear {
            model.cameraController.stop()
            model.audioAnnouncer.stop()
        }
    }

    private var permissionDeniedOverlay: some View {
        VStack(spacing: 16) {
            Text(permissionDeniedLabel)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(openSettingsLabel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .tint(Color.ironAccent)
        }
    }

    private var noPersonLabel: String {
        String(localized: "smart_assistant.no_person_detected", defaultValue: "No te vemos bien, ajusta el encuadre", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var finishSetLabel: String {
        String(localized: "smart_assistant.finish_set", defaultValue: "Finalizar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var permissionDeniedLabel: String {
        String(localized: "smart_assistant.camera_permission_denied", defaultValue: "Watt + Weight necesita acceso a la camara para el Asistente Inteligente.", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var openSettingsLabel: String {
        String(localized: "smart_assistant.open_settings", defaultValue: "Abrir Ajustes", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var toggleCameraLabel: String {
        String(localized: "smart_assistant.toggle_camera", defaultValue: "Cambiar camara", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var toggleAudioLabel: String {
        String(localized: "smart_assistant.toggle_audio", defaultValue: "Cambiar audio", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
}
