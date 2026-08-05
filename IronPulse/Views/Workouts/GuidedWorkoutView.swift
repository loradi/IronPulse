import SwiftUI
import SwiftData

struct GuidedWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var log: WorkoutLog
    let catalog: [Exercise]

    @State private var currentExerciseIndex: Int = 0
    @State private var activeSetID: SetLog.ID?
    @State private var setPhase: SetPhase = .idle
    // Anchor dates for the two running-timer displays below, rather than
    // per-second Int state - see `startSet`/`startRest` for why: writing
    // a new value into @State every second forces this whole view's body
    // (and everything attached to it, including the Smart Assistant's
    // fullScreenCover content closure) to re-evaluate every second while
    // a set or rest period is active. TimelineView ticks its own content
    // closure independently instead, without touching this view's state.
    @State private var setStartedAt: Date?
    @State private var restEndsAt: Date?
    @State private var timerTask: Task<(), Never>? = nil
    @State private var isShowingExerciseInfo = false
    @State private var isShowingSmartAssistant = false
    @FocusState private var focusedWeightSetID: SetLog.ID?

    private var groups: [(exerciseId: String, sets: [SetLog])] {
        GuidedSessionFlow.groupedSets(log.completedSets)
    }

    private var currentGroup: (exerciseId: String, sets: [SetLog])? {
        guard groups.indices.contains(currentExerciseIndex) else { return nil }
        return groups[currentExerciseIndex]
    }

    private var currentExercise: Exercise? {
        guard let currentGroup else { return nil }
        return catalog.first { $0.id == currentGroup.exerciseId }
    }

    private var activeSet: SetLog? {
        guard let currentGroup else { return nil }
        return currentGroup.sets.first { $0.id == activeSetID } ?? currentGroup.sets.first
    }

    var body: some View {
        VStack(spacing: 16) {
            if let currentGroup, let exercise = currentExercise {
                Text(exercise.name).font(.wwHeadline).padding(.top)

                List {
                    ForEach(Array(currentGroup.sets.enumerated()), id: \.element.id) { index, set in
                        setRow(set: set, index: index)
                    }
                    Button {
                        addSet(to: currentGroup.exerciseId)
                    } label: {
                        Label(addSetLabel, systemImage: "plus")
                    }
                }

                if let set = activeSet {
                    controls(for: set)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    noExercisesLabel,
                    systemImage: "checkmark.circle"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("wwLogoMark")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    Text("Entrenamiento").font(.wwHeadline)
                }
            }
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    goToPreviousExercise()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentExerciseIndex == 0)

                Button {
                    goToNextExercise()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentExerciseIndex >= groups.count - 1)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShowingExerciseInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                Button(finishLabel) {
                    finishSession()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(doneLabel) {
                    focusedWeightSetID = nil
                }
            }
        }
        .sheet(isPresented: $isShowingExerciseInfo) {
            if let exercise = currentExercise {
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(closeLabel) {
                                    isShowingExerciseInfo = false
                                }
                            }
                        }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingSmartAssistant) {
            if let set = activeSet, let exercise = currentExercise {
                SmartAssistantSheet(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    // repsCompleted, not targetRepsMax: targetRepsMax is
                    // the profile-wide prescription ceiling (e.g. every
                    // hypertrophy-goal exercise gets 8-12 regardless of
                    // which exercise it is), not what the user just set
                    // in this set's stepper. The assistant should count
                    // toward what the user configured for THIS set.
                    targetReps: set.repsCompleted,
                    onFinish: { count in
                        handleSmartAssistantFinish(set: set, repCount: count)
                    }
                )
            }
        }
        .task {
            await RestNotificationScheduler.requestAuthorizationIfNeeded()
        }
        .onAppear {
            selectFirstIncompleteSet()
        }
        .onDisappear {
            stopTimers()
        }
    }

    private func setRow(set: SetLog, index: Int) -> some View {
        let isActive = set.id == activeSetID
        let weightMissing = isActive && set.weightKg <= 0
        let repsMissing = isActive && set.repsCompleted <= 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Set \(index + 1)").font(.wwHeadline)
                Spacer()
                Text("Meta: \(set.targetRepsMin)-\(set.targetRepsMax)")
                    .font(.wwCaption)
                    .foregroundStyle(Color.ironTextSecondary)
                if set.isCompleted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ironAccent)
                }
            }

            HStack {
                HStack(spacing: 4) {
                    WeightTextField(
                        value: bindingForWeight(set),
                        isInvalid: weightMissing,
                        setID: set.id,
                        focus: $focusedWeightSetID
                    )
                    Text(UnitSystem.current == .metric ? "kg" : "lbs")
                        .font(.wwCaption)
                        .foregroundStyle(weightMissing ? Color.red : Color.ironTextSecondary)
                }
                Spacer()
                Stepper(value: bindingForReps(set), in: 0...50) {
                    Text("\(set.repsCompleted) reps")
                        .foregroundStyle(repsMissing ? Color.red : Color.ironTextPrimary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background {
            if set.id == activeSetID {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.ironAccent.opacity(0.12))
            }
        }
        .overlay {
            if set.id == activeSetID {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.ironAccent, lineWidth: 2)
            }
        }
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing) {
            if canDeleteSet(set) {
                Button(role: .destructive) {
                    removeSet(set)
                } label: {
                    Label(removeSetLabel, systemImage: "trash")
                }
            }
        }
    }

    private func canDeleteSet(_ set: SetLog) -> Bool {
        !set.isCompleted && (currentGroup?.sets.count ?? 0) > 1
    }

    @ViewBuilder
    private func controls(for set: SetLog) -> some View {
        switch setPhase {
        case .idle:
            if currentGroup?.sets.allSatisfy(\.isCompleted) == true {
                if currentExerciseIndex < groups.count - 1 {
                    Button(nextExerciseLabel) {
                        advanceToNextExercise()
                    }
                    .buttonStyle(PrimarySportButtonStyle())
                }
            } else {
                Button(startSetLabel) {
                    startSet()
                }
                .buttonStyle(PrimarySportButtonStyle())
                .disabled(!GuidedSessionFlow.canCompleteSet(weightKg: set.weightKg, repsCompleted: set.repsCompleted))
            }
        case .runningSet:
            VStack(spacing: 8) {
                if let setStartedAt {
                    TimelineView(.periodic(from: setStartedAt, by: 1)) { _ in
                        Text(elapsedLabel(GuidedSessionFlow.elapsedSeconds(since: setStartedAt)))
                            .font(.wwHeadline).foregroundStyle(Color.ironAccent)
                    }
                }

                if currentExercise.flatMap({ MovementProfileCatalog.profile(forExerciseID: $0.id) }) != nil {
                    Button {
                        isShowingSmartAssistant = true
                    } label: {
                        Label(smartAssistantLabel, systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.ironAccent)
                }

                Button(finishSetLabel) {
                    finishSet(set)
                }
                .buttonStyle(PrimarySportButtonStyle())
                .disabled(!GuidedSessionFlow.canCompleteSet(weightKg: set.weightKg, repsCompleted: set.repsCompleted))
            }
        case .resting:
            HStack(spacing: 12) {
                if let restEndsAt {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(restLabel(max(0, GuidedSessionFlow.remainingSeconds(until: restEndsAt))))
                            .font(.wwHeadline).foregroundStyle(Color.ironAccent)
                    }
                }
                Spacer()
                Button(isLastSetInGroup(set) ? nextExerciseLabel : startSetLabel) {
                    startNextSet()
                }
                .buttonStyle(PrimarySportButtonStyle())
            }
        }
    }

    private func isLastSetInGroup(_ set: SetLog) -> Bool {
        guard let currentGroup else { return false }
        return GuidedSessionFlow.nextSetID(after: set.id, in: currentGroup.sets) == nil
    }

    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(
            get: { UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg) },
            set: { newValue in
                let weightKg = UnitSystem.current == .metric ? newValue : UnitSystem.lbsToKg(newValue)
                set.weightKg = weightKg
                if let currentGroup {
                    GuidedSessionFlow.fillEmptyWeights(weightKg, in: currentGroup.sets, editedSetID: set.id)
                }
            }
        )
    }

    private func bindingForReps(_ set: SetLog) -> Binding<Int> {
        Binding(get: { set.repsCompleted }, set: { set.repsCompleted = $0 })
    }

    private func startSet() {
        timerTask?.cancel()
        setPhase = .runningSet
        setStartedAt = Date()
    }

    private func finishSet(_ set: SetLog) {
        set.isCompleted = true
        set.timestamp = Date()
        try? modelContext.save()
        HapticFeedback.setCompleted()

        let isCompound = currentExercise?.isCompound ?? false
        let seconds = GuidedSessionFlow.restSeconds(isCompound: isCompound)
        RestNotificationScheduler.scheduleRestFinished(in: seconds)
        startRest(seconds: seconds)
    }

    private func startRest(seconds: Int) {
        timerTask?.cancel()
        setPhase = .resting
        let endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        restEndsAt = endsAt

        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                let remaining = GuidedSessionFlow.remainingSeconds(until: endsAt)
                guard remaining > 0 else { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if !Task.isCancelled {
                HapticFeedback.restFinished()
                RestNotificationScheduler.cancelPending()
                startNextSet()
            }
        }
    }

    private func startNextSet() {
        timerTask?.cancel()
        RestNotificationScheduler.cancelPending()

        guard let currentGroup, let activeSet else { return }
        if let nextID = GuidedSessionFlow.nextSetID(after: activeSet.id, in: currentGroup.sets) {
            activeSetID = nextID
            setPhase = .idle
        } else {
            advanceToNextExercise()
        }
    }

    private func advanceToNextExercise() {
        guard currentExerciseIndex < groups.count - 1 else {
            setPhase = .idle
            return
        }
        currentExerciseIndex += 1
        selectFirstIncompleteSet()
    }

    private func goToPreviousExercise() {
        guard currentExerciseIndex > 0 else { return }
        currentExerciseIndex -= 1
        selectFirstIncompleteSet()
    }

    private func goToNextExercise() {
        guard currentExerciseIndex < groups.count - 1 else { return }
        currentExerciseIndex += 1
        selectFirstIncompleteSet()
    }

    private func finishSession() {
        stopTimers()
        log.endDate = Date()
        try? modelContext.save()
        dismiss()
    }

    private func addSet(to exerciseId: String) {
        let exerciseSets = log.completedSets.filter { $0.exerciseId == exerciseId }
        guard let template = exerciseSets.max(by: { $0.setIndex < $1.setIndex }) else { return }
        let newSet = SetLog(
            exerciseId: exerciseId,
            setIndex: (log.completedSets.map(\.setIndex).max() ?? 0) + 1,
            weightKg: GuidedSessionFlow.commonWeight(of: exerciseSets) ?? 0,
            repsCompleted: template.targetRepsMin,
            restSeconds: template.restSeconds,
            targetRepsMin: template.targetRepsMin,
            targetRepsMax: template.targetRepsMax
        )
        log.completedSets.append(newSet)
        renumberSets()
        try? modelContext.save()
    }

    private func removeSet(_ set: SetLog) {
        guard canDeleteSet(set) else { return }
        log.completedSets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        if activeSetID == set.id {
            selectFirstIncompleteSet()
        }
        renumberSets()
        try? modelContext.save()
    }

    private func renumberSets() {
        let order = GuidedSessionFlow.groupedSets(log.completedSets).map(\.exerciseId)
        GuidedSessionFlow.renumbered(log.completedSets, groupedBy: order)
    }

    private func stopTimers() {
        timerTask?.cancel()
        RestNotificationScheduler.cancelPending()
    }

    private func handleSmartAssistantFinish(set: SetLog, repCount: Int) {
        guard repCount > 0 else { return }
        set.repsCompleted = repCount
        try? modelContext.save()
        if GuidedSessionFlow.canCompleteSet(weightKg: set.weightKg, repsCompleted: set.repsCompleted) {
            finishSet(set)
        }
    }

    private func selectFirstIncompleteSet() {
        stopTimers()
        setPhase = .idle
        setStartedAt = nil
        restEndsAt = nil
        guard let currentGroup else { return }
        activeSetID = currentGroup.sets.first { !$0.isCompleted }?.id ?? currentGroup.sets.last?.id
    }

    private var startSetLabel: String {
        String(localized: "guided_session.start_set", defaultValue: "Empezar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var nextExerciseLabel: String {
        String(localized: "guided_session.next_exercise", defaultValue: "Siguiente", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var finishSetLabel: String {
        String(localized: "guided_session.finish_set", defaultValue: "Terminar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var noExercisesLabel: String {
        String(localized: "guided_session.no_exercises", defaultValue: "Sin ejercicios", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func restLabel(_ seconds: Int) -> String {
        String(localized: "guided_session.rest_seconds", defaultValue: "Descanso: \(seconds) s", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        String(localized: "guided_session.elapsed_seconds", defaultValue: "\(seconds) s", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var finishLabel: String {
        String(localized: "guided_session.finish", defaultValue: "Terminar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var closeLabel: String {
        String(localized: "guided_session.close_info", defaultValue: "Cerrar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var addSetLabel: String {
        String(localized: "guided_session.add_set", defaultValue: "Agregar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var removeSetLabel: String {
        String(localized: "guided_session.remove_set", defaultValue: "Eliminar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var doneLabel: String {
        String(localized: "guided_session.done", defaultValue: "Listo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var smartAssistantLabel: String {
        String(localized: "guided_session.smart_assistant", defaultValue: "Asistente inteligente", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
}

/// TextField propio para el peso de un set: el buffer de texto vive en
/// @State local y solo se reformatea al perder el foco. Un TextField
/// atado directamente a un Double via `format:` reformatea el texto en
/// cada tecla, lo que hacia el campo dificil de editar (efecto
/// "autocompletado"). Aca el texto se sincroniza desde el modelo solo
/// cuando el campo NO tiene el foco.
private struct WeightTextField: View {
    @Binding var value: Double
    let isInvalid: Bool
    let setID: SetLog.ID
    var focus: FocusState<SetLog.ID?>.Binding

    @State private var text: String = ""

    var body: some View {
        TextField("Peso", text: $text)
            .keyboardType(.decimalPad)
            .frame(width: 60)
            .foregroundStyle(isInvalid ? Color.red : Color.ironTextPrimary)
            .focused(focus, equals: setID)
            .onAppear {
                text = Self.format(value)
            }
            .onChange(of: focus.wrappedValue) { _, newFocus in
                guard newFocus != setID else { return }
                text = Self.format(value)
            }
            .onChange(of: text) { _, newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                guard let parsed = Double(normalized) else { return }
                value = parsed
            }
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private enum SetPhase: Equatable {
    case idle
    case runningSet
    case resting
}

struct GuidedWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Guided Workout")
            .preferredColorScheme(.dark)
    }
}
