import SwiftUI
import SwiftData

struct ProfileSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @State private var selection: UUID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(profiles) { profile in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name).font(.headline)
                            Text("\(profile.experienceLevel.displayName) • \(profile.fitnessGoal.displayName)").font(.caption).foregroundStyle(.ironTextSecondary)
                        }
                        Spacer()
                        if profile.isActive { Image(systemName: "star.fill").foregroundStyle(.ironPrimary) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { activate(profile) }
                }
            }
            .navigationTitle("Perfiles")
            .toolbar {
                Button(action: addProfile) { Label("Nuevo", systemImage: "plus") }
            }
        }
    }

    private func addProfile() {
        let p = UserProfile(name: "Perfil \(profiles.count + 1)", experienceLevel: .beginner, fitnessGoal: .maintenance, trainingDaysPerWeek: 3, sessionDurationMinutes: 60)
        modelContext.insert(p)
        try? modelContext.save()
    }

    private func activate(_ profile: UserProfile) {
        for p in profiles { p.isActive = false }
        profile.isActive = true
        try? modelContext.save()
    }
}

struct ProfileSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSelectionView()
            .preferredColorScheme(.dark)
    }
}
