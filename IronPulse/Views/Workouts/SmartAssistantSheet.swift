import SwiftUI

/// Stage-1 UI shell for the Smart Exercise Assistant: the full
/// overlay (exercise name, rep counter, feedback banner, Finish Set
/// button) driven by a mock, self-incrementing counter so the whole
/// flow is reviewable before any camera code exists. A later task
/// swaps the black background for a live camera preview, and another
/// swaps this mock timer for real Vision-based tracking — this
/// view's `onFinish` contract does not change across either swap.
struct SmartAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let targetReps: Int
    let onFinish: (Int) -> Void

    @State private var repCount = 0
    @State private var feedbackMessage: String?
    @State private var mockCountingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(exerciseName)
                    .font(.wwHeadline)
                    .foregroundStyle(.white)
                    .padding(.top, 60)

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
        .onAppear(perform: startMockCounting)
        .onDisappear { mockCountingTask?.cancel() }
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
}
