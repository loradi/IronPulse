import SwiftUI

/// Stage-2 UI for the Smart Exercise Assistant: the full overlay
/// (exercise name, rep counter, feedback banner, Finish Set button)
/// now composited on top of a live camera preview, with camera
/// permission handling and a front/back toggle. The rep-counting
/// logic itself is still a mock, self-incrementing counter — a later
/// task swaps this mock timer for real Vision-based tracking; this
/// view's `onFinish` contract does not change across that swap.
struct SmartAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let targetReps: Int
    let onFinish: (Int) -> Void

    @State private var repCount = 0
    @State private var feedbackMessage: String?
    @State private var mockCountingTask: Task<Void, Never>?
    @State private var cameraController = CameraSessionController()

    var body: some View {
        ZStack {
            switch cameraController.authorizationState {
            case .authorized:
                CameraPreviewView(session: cameraController.session)
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
                        cameraController.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(toggleCameraLabel)
                }
                .padding(.top, 60)
                .padding(.horizontal)

                if let feedbackMessage {
                    Text(feedbackMessage)
                        .font(.wwCaption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.ironAccent.opacity(0.2), in: Capsule())
                        .foregroundStyle(Color.ironAccent)
                }

                Spacer()

                Text("\(repCount) / \(targetReps)")
                    .font(.wwDisplay)
                    .foregroundStyle(Color.ironAccent)

                Spacer()

                Button(finishSetLabel, action: finish)
                    .buttonStyle(PrimarySportButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
        .task {
            await cameraController.requestAuthorizationIfNeeded()
            if cameraController.authorizationState == .authorized {
                cameraController.start()
            }
        }
        .onAppear(perform: startMockCounting)
        .onDisappear {
            mockCountingTask?.cancel()
            cameraController.stop()
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

    private func startMockCounting() {
        mockCountingTask = Task { @MainActor in
            while !Task.isCancelled, repCount < targetReps {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                repCount += 1
                feedbackMessage = goodRepLabel
                if repCount >= targetReps {
                    finish()
                }
            }
        }
    }

    private func finish() {
        mockCountingTask?.cancel()
        onFinish(repCount)
        dismiss()
    }

    private var finishSetLabel: String {
        String(localized: "smart_assistant.finish_set", defaultValue: "Finalizar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var goodRepLabel: String {
        String(localized: "smart_assistant.feedback.good_rep", defaultValue: "Buena repeticion", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
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
}
