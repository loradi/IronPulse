import SwiftUI

/// Small icon shown next to an exercise wherever it's listed (library,
/// exercise detail, routine rows) to indicate it has Smart Assistant
/// coverage. Carries no logic of its own — each call site decides
/// whether to show it via `MovementProfileCatalog.profile(forExerciseID:) != nil`,
/// the same condition `GuidedWorkoutView` already uses to show the
/// Smart Assistant button itself. Uses the same SF Symbol as that
/// button (`camera.viewfinder`) so the icon reads as the same feature.
struct SmartAssistantBadge: View {
    var body: some View {
        Image(systemName: "camera.viewfinder")
            .font(.system(size: 14))
            .foregroundStyle(Color.ironAccent)
            .accessibilityLabel(
                String(
                    localized: "exercise.smart_assistant_badge",
                    defaultValue: "Smart assistant available",
                    bundle: AppLanguage.current.bundle,
                    locale: AppLanguage.current.locale
                )
            )
    }
}
