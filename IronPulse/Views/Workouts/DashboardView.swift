import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @Query private var catalog: [Exercise]

    @State private var activeLog: WorkoutLog?

    private var todaysDay: RoutineDay? {
        profile.activeRoutine?.days.first { $0.weekday == Weekday.today() }
    }

    private var trainedExercises: [Exercise] {
        let trainedIds = Set(
            profile.workoutLogs
                .filter { $0.endDate != nil }
                .flatMap { $0.completedSets.filter(\.isCompleted).map(\.exerciseId) }
        )
        return catalog.filter { trainedIds.contains($0.id) }.sorted { $0.name < $1.name }
    }

    private var leanMassEntries: [HealthSnapshot] {
        profile.healthSnapshots
            .filter { $0.leanBodyMassKg != nil }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    private var currentStreak: Int {
        guard let routine = profile.activeRoutine else { return 0 }
        let scheduledWeekdays = Set(routine.days.map(\.weekday))
        return WorkoutStatsService.currentStreak(scheduledWeekdays: scheduledWeekdays, logs: profile.workoutLogs)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                weekStrip
                todaysCard
                metricsRow
                progressChart
                leanMassCard
                exerciseProgressSection
                historyLink
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle(profile.name)
        .navigationDestination(item: $activeLog) { log in
            ActiveWorkoutView(log: log)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name).font(.wwHeadline)
                Text("\(profile.experienceLevel.displayName) • \(profile.primaryGoal.displayName)")
                    .font(.wwBody)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            Spacer()

            Circle().fill(Color.ironAccent).frame(width: 56, height: 56)
                .overlay(Circle().stroke(Color.ironTextPrimary.opacity(0.3), lineWidth: 2))
        }
        .ironCard()
    }

    private var weekStrip: some View {
        let statuses = WorkoutStatsService.weekStrip(
            scheduledWeekdays: Set((profile.activeRoutine?.days ?? []).map(\.weekday)),
            logs: profile.workoutLogs
        )

        return HStack(spacing: Spacing.xs) {
            ForEach(statuses, id: \.weekday) { entry in
                VStack(spacing: 4) {
                    Text(entry.weekday.shortDisplayName)
                        .font(.wwLabelCaps)
                        .foregroundStyle(Color.ironTextSecondary)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(entry.status == .completed ? Color.ironAccent : Color.ironCard)
                            .frame(height: 44)

                        if entry.status == .completed {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.ironBackground)
                        } else if entry.status == .pending {
                            Circle()
                                .fill(Color.ironTextSecondary)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .overlay {
                        if entry.isToday {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.ironAccent, lineWidth: 2)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var todaysCard: some View {
        if profile.activeRoutine == nil {
            ContentUnavailableView(
                "Sin rutina activa",
                systemImage: "bolt.slash",
                description: Text("Genera una rutina automatica o arma la tuya desde la tab Rutina.")
            )
        } else if let day = todaysDay {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hoy: \(day.title)").font(.wwHeadline)
                ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                    Text(ex.exercise.name)
                        .font(.wwBody)
                        .foregroundStyle(Color.ironTextSecondary)
                }
                Button("Iniciar ejercicios", action: startTodaysSession)
                    .buttonStyle(PrimarySportButtonStyle())
            }
            .ironCard()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Descanso hoy").font(.wwHeadline)
                Text("Hoy no hay ningun dia de la rutina asignado.")
                    .font(.wwBody)
                    .foregroundStyle(Color.ironTextSecondary)
            }
            .ironCard()
        }
    }

    private var metricsRow: some View {
        HStack {
            metric("Volumen", "\(Int(WorkoutStatsService.totalVolumeKg(profile.workoutLogs))) kg")
            Spacer()
            metric("Entrenamientos", "\(WorkoutStatsService.workoutCount(profile.workoutLogs))")
            Spacer()
            metric("Racha", diasLabel(currentStreak))
        }
        .ironCard()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.wwDataMono(22))
            Text(title).font(.wwCaption).foregroundStyle(Color.ironTextSecondary)
        }
    }

    private var progressChart: some View {
        let points = WorkoutStatsService.dailyVolume(profile.workoutLogs)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Progreso (30 dias)").font(.wwHeadline)
            Chart(points, id: \.date) { point in
                AreaMark(x: .value("Dia", point.date), y: .value("Volumen", point.volumeKg))
                    .foregroundStyle(Color.ironAccent.opacity(0.2))
                LineMark(x: .value("Dia", point.date), y: .value("Volumen", point.volumeKg))
                    .foregroundStyle(Color.ironAccent)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 15))
            }
            .frame(height: 140)
            // Sin esto el Chart se traga TODOS los toques de la pantalla (botones y
            // NavigationLinks incluidos), no solo los suyos. El grafico es decorativo.
            .allowsHitTesting(false)
        }
        .ironCard()
    }

    @ViewBuilder
    private var leanMassCard: some View {
        if leanMassEntries.count >= 2,
           let firstValue = leanMassEntries.first?.leanBodyMassKg,
           let lastValue = leanMassEntries.last?.leanBodyMassKg {
            let delta = lastValue - firstValue
            VStack(alignment: .leading, spacing: 4) {
                Text("Masa magra").font(.wwHeadline)
                Text(String(format: "%.1f kg (%@%.1fkg desde que empezaste)", lastValue, delta >= 0 ? "+" : "", delta))
                    .font(.wwBody)
                    .foregroundStyle(Color.ironTextSecondary)
            }
            .ironCard()
        }
    }

    @ViewBuilder
    private var exerciseProgressSection: some View {
        if !trainedExercises.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Progreso por ejercicio").font(.wwHeadline)
                ForEach(trainedExercises) { exercise in
                    NavigationLink {
                        ExerciseProgressView(profile: profile, exercise: exercise)
                    } label: {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.wwBody)
                        .foregroundStyle(Color.ironTextSecondary)
                    }
                }
            }
            .ironCard()
        }
    }

    private var historyLink: some View {
        NavigationLink {
            WorkoutHistoryView(profile: profile)
        } label: {
            HStack {
                Text("Ver historial de entrenamientos")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.wwCaption)
            .foregroundStyle(Color.ironAccent)
            .padding()
            .background(Color.ironCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func startTodaysSession() {
        guard let routine = profile.activeRoutine, let day = todaysDay else { return }
        activeLog = WorkoutLogGenerator.startSession(for: day, routineName: routine.name, profile: profile, in: modelContext)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Dashboard")
            .preferredColorScheme(.dark)
    }
}
