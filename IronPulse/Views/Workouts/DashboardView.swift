import SwiftUI
import SwiftData

struct DashboardView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if let active = profile.activeRoutine {
                    Text("\(active.name) · \(active.days.count) dias")
                        .font(.subheadline)
                        .foregroundStyle(Color.ironTextSecondary)
                }

                NavigationLink {
                    WorkoutHistoryView(profile: profile)
                } label: {
                    HStack {
                        Text("Ver historial de entrenamientos")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ironAccent)
                    .padding()
                    .background(Color.ironCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle(profile.name)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name).font(.ironTitle)
                Text("\(profile.experienceLevel.displayName) • \(profile.primaryGoal.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            Spacer()

            Circle().fill(Color.ironAccent).frame(width: 56, height: 56).neonGlow()
        }
        .ironCard()
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Dashboard")
            .preferredColorScheme(.dark)
    }
}
