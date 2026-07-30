import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    private let healthImporter = HealthKitProfileImporter()

    @State private var selectedProfile: UserProfile?

    var body: some View {
        // MainTabView aloja su propio NavigationStack por tab: si se empuja
        // como destino DENTRO de otro NavigationStack (el de esta lista),
        // quedan anidados y el boton "atras" de cualquier pantalla interna
        // siempre vuelve a esta lista en vez de a la pantalla anterior. Por
        // eso se intercambia la raiz completa en vez de usar NavigationLink.
        if let selectedProfile, profiles.contains(where: { $0.id == selectedProfile.id }) {
            MainTabView(
                profile: selectedProfile,
                healthImporter: healthImporter,
                onSwitchProfile: { self.selectedProfile = nil }
            )
            .tint(Color.ironAccent)
        } else {
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
                                Button {
                                    selectedProfile = profile
                                } label: {
                                    ProfileRow(profile: profile)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.ironCard)
                            }
                            .onDelete(perform: deleteProfiles)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.ironBackground)
                .navigationTitle("Watt + Weight")
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
    }

    private func addProfile() {
        withAnimation {
            let profile = UserProfile(
                name: "Perfil \(profiles.count + 1)",
                age: 0,
                weightKg: 0,
                heightCm: 0
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
                .font(.wwTitle3)

            Text("\(profile.experienceLevel.displayName) • \(profile.primaryGoal.displayName) • \(diasLabel(profile.workoutDaysPerWeek))/semana")
                .font(.wwBody)
                .foregroundStyle(Color.ironTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct ProfileDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    let healthImporter: HealthKitProfileImporter
    var onSwitchProfile: (() -> Void)? = nil

    @State private var isImportingHealthData = false
    @State private var healthImportMessage: String?
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.current.rawValue
    @AppStorage("unitSystem") private var unitSystemRaw: String = UnitSystem.metric.rawValue

    private var unitSystem: UnitSystem {
        UnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    EditableAvatarView(profile: profile, size: 72)
                    Spacer()
                }
            }

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

                VStack(alignment: .leading) {
                    Text(daysPerWeekSliderLabel(profile.workoutDaysPerWeek))
                        .font(.wwBody)
                    Slider(
                        value: Binding(
                            get: { Double(profile.workoutDaysPerWeek) },
                            set: { profile.workoutDaysPerWeek = Int($0.rounded()) }
                        ),
                        in: 1...7,
                        step: 1
                    )
                    .tint(Color.ironAccent)
                }
            }

            Section("Datos fisicos") {
                Stepper("\(profile.age) anos", value: $profile.age, in: 14...99)

                Picker(sexLabel, selection: $profile.biologicalSex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }

                heightField
                weightField
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
                        .font(.wwCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Ajustes") {
                Picker("Idioma", selection: $appLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }

                Picker(unitSystemLabel, selection: $unitSystemRaw) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.displayName).tag(system.rawValue)
                    }
                }
            }

            if let onSwitchProfile {
                Section {
                    Button(switchProfileLabel, action: onSwitchProfile)
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
                healthImportMessage = String(localized: "health_import.success", defaultValue: "Datos importados desde Salud.", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
            } catch {
                healthImportMessage = error.localizedDescription
            }

            isImportingHealthData = false
        }
    }

    private func daysPerWeekSliderLabel(_ count: Int) -> String {
        if count == 1 {
            return String(localized: "profile.days_per_week_slider.singular", defaultValue: "\(count) dia por semana", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        } else {
            return String(localized: "profile.days_per_week_slider.plural", defaultValue: "\(count) dias por semana", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }

    private var sexLabel: String {
        String(localized: "profile.field_sex", defaultValue: "Sexo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var heightLabel: String {
        String(localized: "profile.field_height", defaultValue: "Altura", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var weightLabel: String {
        String(localized: "profile.field_weight", defaultValue: "Peso", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var unitSystemLabel: String {
        String(localized: "profile.unit_system_label", defaultValue: "Sistema de unidades", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var switchProfileLabel: String {
        String(localized: "profile.switch_profile", defaultValue: "Cambiar de perfil", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func clampedHeight(_ cm: Double) -> Double { min(max(cm, 100), 250) }
    private func clampedWeight(_ kg: Double) -> Double { min(max(kg, 30), 300) }

    private var heightCmBinding: Binding<Double> {
        Binding(
            get: { profile.heightCm },
            set: { profile.heightCm = clampedHeight($0) }
        )
    }

    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { UnitSystem.cmToFeetInches(profile.heightCm).feet },
            set: { newFeet in
                let inches = UnitSystem.cmToFeetInches(profile.heightCm).inches
                profile.heightCm = clampedHeight(UnitSystem.feetInchesToCm(feet: newFeet, inches: inches))
            }
        )
    }

    private var heightInchesBinding: Binding<Int> {
        Binding(
            get: { UnitSystem.cmToFeetInches(profile.heightCm).inches },
            set: { newInches in
                let feet = UnitSystem.cmToFeetInches(profile.heightCm).feet
                profile.heightCm = clampedHeight(UnitSystem.feetInchesToCm(feet: feet, inches: newInches))
            }
        )
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { unitSystem == .metric ? profile.weightKg : UnitSystem.kgToLbs(profile.weightKg) },
            set: { newValue in
                let kg = unitSystem == .metric ? newValue : UnitSystem.lbsToKg(newValue)
                profile.weightKg = clampedWeight(kg)
            }
        )
    }

    @ViewBuilder
    private var heightField: some View {
        switch unitSystem {
        case .metric:
            HStack {
                Text(heightLabel)
                Spacer()
                TextField(heightLabel, value: heightCmBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("cm").foregroundStyle(Color.ironTextSecondary)
            }
        case .imperial:
            HStack {
                Text(heightLabel)
                Spacer()
                TextField("ft", value: heightFeetBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                Text("'").foregroundStyle(Color.ironTextSecondary)
                TextField("in", value: heightInchesBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                Text("\"").foregroundStyle(Color.ironTextSecondary)
            }
        }
    }

    private var weightField: some View {
        HStack {
            Text(weightLabel)
            Spacer()
            TextField(weightLabel, value: weightBinding, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unitSystem == .metric ? "kg" : "lbs").foregroundStyle(Color.ironTextSecondary)
        }
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
