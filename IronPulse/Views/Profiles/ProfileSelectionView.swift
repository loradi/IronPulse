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
                            Text("\(profile.experienceLevel.displayName) • \(profile.primaryGoal.displayName)").font(.caption).foregroundStyle(Color.ironTextSecondary)
                        }
                        Spacer()
                        if profile.id == selection { Image(systemName: "star.fill").foregroundStyle(Color.ironAccent) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selection = profile.id }
                }
            }
            .navigationTitle("Perfiles")
            .toolbar {
                Button(action: addProfile) { Label("Nuevo", systemImage: "plus") }
            }
        }
    }

    private func addProfile() {
        let p = UserProfile(name: "Perfil \(profiles.count + 1)", age: 30, weightKg: 70, heightCm: 170)
        modelContext.insert(p)
        try? modelContext.save()
    }
}

struct ProfileSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSelectionView()
            .preferredColorScheme(.dark)
    }
}
