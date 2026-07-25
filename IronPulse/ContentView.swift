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
                    } else {
                        ForEach(profiles) { profile in
                            NavigationLink {
                                ProfileDetailView(profile: profile, healthImporter: healthImporter)
                            } label: {
                                ProfileRow(profile: profile)
                            }
                        }
                        .onDelete(perform: deleteProfiles)
                    }
                }
            }
            .navigationTitle("IronPulse")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addProfile) {
                        Label("Nuevo perfil", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addProfile() {
        withAnimation {
            let shouldBeActive = profiles.isEmpty
            let profile = UserProfile(
                name: "Perfil \(profiles.count + 1)",
                experienceLevel: .beginner,
                fitnessGoal: .maintenance,
                trainingDaysPerWeek: 3,
                sessionDurationMinutes: 60,
                isActive: shouldBeActive
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
            HStack {
                Text(profile.name)
                    .font(.headline)

                if profile.isActive {
                    Text("Activo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(profile.experienceLevel.displayName) • \(profile.fitnessGoal.displayName) • \(profile.trainingDaysPerWeek) dias/semana")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ProfileDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    let healthImporter: HealthKitProfileImporter

    @State private var isImportingHealthData = false
    @State private var healthImportMessage: String?

    var body: some View {
        Form {
            Section("Perfil") {
                TextField("Nombre", text: $profile.name)

                Picker("Nivel", selection: $profile.experienceLevel) {
                    ForEach(ExperienceLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }

                Picker("Objetivo", selection: $profile.fitnessGoal) {
                    ForEach(FitnessGoal.allCases) { goal in
                        Text(goal.displayName).tag(goal)
                    }
                }

                Stepper("\(profile.trainingDaysPerWeek) dias por semana", value: $profile.trainingDaysPerWeek, in: 1...7)
                Stepper("\(profile.sessionDurationMinutes) min por sesion", value: $profile.sessionDurationMinutes, in: 30...120, step: 15)
            }

            Section("Datos fisicos") {
                LabeledContent("Edad", value: profile.age.map(String.init) ?? "Sin dato")
                LabeledContent("Sexo", value: profile.biologicalSex.displayName)
                LabeledContent("Altura", value: formatted(profile.heightCm, suffix: "cm"))
                LabeledContent("Peso", value: formatted(profile.weightKg, suffix: "kg"))
            }

            Section("Salud") {
                Toggle("Sincronizar con Salud", isOn: $profile.syncsWithHealth)

                Button {
                    importHealthData()
                } label: {
                    if isImportingHealthData {
                        ProgressView()
                    } else {
                        Label("Importar datos de Salud", systemImage: "heart.text.square")
                    }
                }
                .disabled(isImportingHealthData || !profile.syncsWithHealth)

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
            WorkoutRoutine.self,
            RoutineDay.self,
            RoutineExercise.self,
            WorkoutSession.self,
            WorkoutLogSet.self,
        ], inMemory: true)
}
