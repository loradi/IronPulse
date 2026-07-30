import SwiftUI
import SwiftData

struct RoutineTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var catalog: [Exercise]
    @Bindable var profile: UserProfile
    @State private var activeLog: WorkoutLog?
    @State private var pendingAction: PendingRoutineAction?
    @State private var isShowingManualBuilder = false

    private enum PendingRoutineAction {
        case smart
        case manual
    }

    private var todaysCompletedLog: WorkoutLog? {
        WorkoutStatsService.todaysCompletedLog(logs: profile.workoutLogs)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let active = profile.activeRoutine {
                    RoutineCard(routine: active, todaysCompletedLog: todaysCompletedLog, onStartDay: startWorkout)
                } else {
                    ContentUnavailableView(
                        "Sin rutina activa",
                        systemImage: "bolt.slash",
                        description: Text("Genera una rutina automatica o arma la tuya ejercicio por ejercicio.")
                    )
                }

                VStack(spacing: 12) {
                    Button("Rutina inteligente") { requestNewRoutine(.smart) }
                        .buttonStyle(PrimarySportButtonStyle())

                    Button {
                        requestNewRoutine(.manual)
                    } label: {
                        Text("Crear rutina manual")
                            .font(.wwHeadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.ironAccent)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.ironAccent, lineWidth: 1.5)
                            }
                    }
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Rutina")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $activeLog) { log in
            ActiveWorkoutView(log: log)
        }
        .navigationDestination(isPresented: $isShowingManualBuilder) {
            RoutineBuilderView(profile: profile)
        }
        .confirmationDialog(
            replaceRoutineTitle,
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(replaceRoutineConfirm, role: .destructive) {
                confirmPendingAction()
            }
            Button(cancelLabel, role: .cancel) {
                pendingAction = nil
            }
        } message: {
            Text(replaceRoutineMessage)
        }
    }

    private func requestNewRoutine(_ action: PendingRoutineAction) {
        guard profile.activeRoutine != nil else {
            perform(action)
            return
        }
        pendingAction = action
    }

    private func confirmPendingAction() {
        guard let pendingAction else { return }
        perform(pendingAction)
        self.pendingAction = nil
    }

    private func perform(_ action: PendingRoutineAction) {
        switch action {
        case .smart:
            generateRoutine()
        case .manual:
            isShowingManualBuilder = true
        }
    }

    private func generateRoutine() {
        guard !catalog.isEmpty else { return }
        let routine = WorkoutGeneratorService.generateRoutine(for: profile, catalog: catalog)
        profile.activate(routine, in: modelContext)
    }

    private var replaceRoutineTitle: String {
        String(localized: "routine_tab.replace_title", defaultValue: "Reemplazar tu rutina actual?", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var replaceRoutineMessage: String {
        String(localized: "routine_tab.replace_message", defaultValue: "Ya tienes una rutina activa. Si continuas, se reemplazara por la nueva.", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var replaceRoutineConfirm: String {
        String(localized: "routine_tab.replace_confirm", defaultValue: "Reemplazar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var cancelLabel: String {
        String(localized: "routine_tab.cancel", defaultValue: "Cancelar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func startWorkout(_ day: RoutineDay) {
        guard let routine = profile.activeRoutine else { return }
        if day.weekday == Weekday.today(), let completedLog = todaysCompletedLog {
            activeLog = completedLog
            return
        }
        activeLog = WorkoutLogGenerator.startSession(for: day, routineName: routine.name, profile: profile, in: modelContext)
    }
}

private struct RoutineCard: View {
    let routine: WorkoutRoutine
    let todaysCompletedLog: WorkoutLog?
    let onStartDay: (RoutineDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text(routine.name).font(.wwHeadline)
                Text("\(diasLabel(routine.days.count)) · \(routine.splitType.displayName)")
                    .font(.wwCaption)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            ForEach(routine.days.sorted { $0.dayNumber < $1.dayNumber }) { day in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(day.title).font(.wwBody).bold()
                        Spacer()
                        Button(isTodayCompleted(day) ? viewSummaryLabel : "Empezar") { onStartDay(day) }
                            .font(.wwLabelCaps)
                            .foregroundStyle(Color.ironAccent)
                    }
                    ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex.exercise)
                        } label: {
                            HStack {
                                Text(ex.exercise.name).font(.wwCaption)
                                Spacer()
                                Text("\(ex.targetSets)x\(ex.targetRepsMin)-\(ex.targetRepsMax)")
                                    .font(.wwCaption)
                                    .foregroundStyle(Color.ironTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .ironCard()
    }

    private func isTodayCompleted(_ day: RoutineDay) -> Bool {
        day.weekday == Weekday.today() && todaysCompletedLog != nil
    }

    private var viewSummaryLabel: String {
        String(localized: "dashboard.view_summary", defaultValue: "Ver resumen", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
}

struct RoutineTabView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Rutina")
            .preferredColorScheme(.dark)
    }
}
