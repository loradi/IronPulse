import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    private let healthImporter = HealthKitProfileImporter()

    var body: some View {
        NavigationStack {
            List {
                Section("Perfiles") {
                    if profiles.isEmpty {
                        ContentUnavailableView(
                            "Sin perfiles",
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text("Crea un perfil para generar rutinas y registrar progreso.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(profiles) { profile in
                            NavigationLink {
                                DashboardView(profile: profile, healthImporter: healthImporter)
                            } label: {
                                ProfileRow(profile: profile)
                            }
                            .listRowBackground(Color.ironCard)
                        }
                        .onDelete(perform: deleteProfiles)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.ironBackground)
            .navigationTitle("IronPulse")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addProfile) {
                        Label("Nuevo perfil", systemImage: "plus")
                    }
                }
            }
        }
        .tint(Color.ironAccent)
    }

    private func addProfile() {
        withAnimation {
            let profile = UserProfile(
                name: "Perfil \(profiles.count + 1)",
                age: 30,
                weightKg: 70,
                heightCm: 170
            )

            modelContext.insert(profile)
        }
    }

    private func deleteProfiles(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(profiles[index])
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(profile.name)
                .font(.headline)

            Text("\(profile.experienceLevel.displayName) • \(profile.primaryGoal.displayName) • \(profile.workoutDaysPerWeek) dias/semana")
                .font(.subheadline)
                .foregroundStyle(Color.ironTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct ProfileDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    let healthImporter: HealthKitProfileImporter

    @State private var isImportingHealthData = false
    @State private var healthImportMessage: String?

    private var latestSnapshot: HealthSnapshot? {
        profile.healthSnapshots.max { $0.capturedAt < $1.capturedAt }
    }

    var body: some View {
        Form {
            Section("Perfil") {
                TextField("Nombre", text: $profile.name)

                Picker("Nivel", selection: $profile.experienceLevel) {
                    ForEach(ExperienceLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }

                Picker("Objetivo", selection: $profile.primaryGoal) {
                    ForEach(PrimaryGoal.allCases) { goal in
                        Text(goal.displayName).tag(goal)
                    }
                }

                Stepper("\(profile.workoutDaysPerWeek) dias por semana", value: $profile.workoutDaysPerWeek, in: 1...7)
            }

            Section("Datos fisicos") {
                Stepper("\(profile.age) anos", value: $profile.age, in: 14...99)
                LabeledContent("Sexo", value: latestSnapshot?.biologicalSex.displayName ?? BiologicalSex.notSet.displayName)
                LabeledContent("Altura", value: formatted(profile.heightCm, suffix: "cm"))
                LabeledContent("Peso", value: formatted(profile.weightKg, suffix: "kg"))
            }

            Section("Salud") {
                Button {
                    importHealthData()
                } label: {
                    if isImportingHealthData {
                        ProgressView()
                    } else {
                        Label("Importar datos de Salud", systemImage: "heart.text.square")
                    }
                }
                .disabled(isImportingHealthData)

                if let healthImportMessage {
                    Text(healthImportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(profile.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func importHealthData() {
        isImportingHealthData = true
        healthImportMessage = nil

        Task {
            do {
                try await healthImporter.requestAuthorization()
                let snapshot = try await healthImporter.makeSnapshot(for: profile)
                modelContext.insert(snapshot)
                try modelContext.save()
                healthImportMessage = "Datos importados desde Salud."
            } catch {
                healthImportMessage = error.localizedDescription
            }

            isImportingHealthData = false
        }
    }

    private func formatted(_ value: Double?, suffix: String) -> String {
        guard let value else { return "Sin dato" }
        return value.formatted(.number.precision(.fractionLength(0...1))) + " " + suffix
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            UserProfile.self,
            HealthSnapshot.self,
            Exercise.self,
            WorkoutRoutine.self,
            RoutineDay.self,
            RoutineExercise.self,
            WorkoutLog.self,
            SetLog.self,
        ], inMemory: true)
}
