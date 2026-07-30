import SwiftUI

struct MainTabView: View {
    @Bindable var profile: UserProfile
    let healthImporter: HealthKitProfileImporter
    var onSwitchProfile: () -> Void

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(profile: profile)
            }
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            NavigationStack {
                RoutineTabView(profile: profile)
            }
            .tabItem { Label("Rutina", systemImage: "list.bullet.clipboard") }

            NavigationStack {
                ExerciseListView()
            }
            .tabItem { Label("Ejercicios", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack {
                ProfileDetailView(profile: profile, healthImporter: healthImporter, onSwitchProfile: onSwitchProfile)
            }
            .tabItem { Label("Perfil", systemImage: "gearshape") }
        }
        .tint(Color.ironAccent)
    }
}
