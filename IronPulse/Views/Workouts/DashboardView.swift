import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile

    @State private var isGenerating = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if let active = profile.activeRoutine {
                    RoutineCard(routine: active)
                } else {
                    ContentUnavailableView("Sin rutina activa", systemImage: "bolt.slash", description: Text("Genera una rutina con IA o crea una manualmente."))
                }

                Button {
                    Task { await generateRoutine() }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(isGenerating ? "Generando..." : "Generar Rutina con IA")
                    }
                }
                .buttonStyle(PrimarySportButtonStyle())
                .disabled(isGenerating)

                if let message {
                    Text(message).font(.footnote).foregroundStyle(.ironTextSecondary)
                }
            }
            .padding()
        }
        .navigationTitle(profile.name)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name).font(.system(.title, design: .rounded)).weight(.black)
                Text("\(profile.experienceLevel.displayName) • \(profile.fitnessGoal.displayName)").foregroundStyle(.ironTextSecondary).font(.subheadline)
            }

            Spacer()

            Circle().fill(Color.ironPrimary).frame(width: 56, height: 56).redGlow()
        }
        .padding()
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func generateRoutine() async {
        isGenerating = true
        message = nil

        let generator = AIRoutineGenerator()
        do {
            let routine = try await generator.generateRoutine(for: profile, in: modelContext)
            message = "Rutina \(routine.name) creada"
        } catch {
            message = "Error generando rutina: \(error.localizedDescription)"
        }

        isGenerating = false
    }
}

private struct RoutineCard: View {
    let routine: WorkoutRoutine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(routine.name).font(.headline)
                    Text("\(routine.days.count) días · \(routine.experienceLevel.displayName)").font(.caption).foregroundStyle(.ironTextSecondary)
                }
                Spacer()
                Label("Abrir", systemImage: "chevron.right")
            }

            ForEach(routine.days.sorted { $0.dayIndex < $1.dayIndex }) { day in
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.title).font(.subheadline).bold()
                    ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                        HStack {
                            Text(ex.name).font(.caption)
                            Spacer()
                            Text("\(ex.sets)x\(ex.repRange)").font(.caption2).foregroundStyle(.ironTextSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ironBorder))
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Dashboard")
            .preferredColorScheme(.dark)
    }
}
