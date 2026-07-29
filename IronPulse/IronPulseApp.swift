//
//  IronPulseApp.swift
//  IronPulse
//
//  Created by Diego on 2026-07-21.
//

import SwiftUI
import SwiftData

@main
struct IronPulseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            HealthSnapshot.self,
            Exercise.self,
            WorkoutRoutine.self,
            RoutineDay.self,
            RoutineExercise.self,
            WorkoutLog.self,
            SetLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            ExerciseDatabaseSeeder.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.current.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(appLanguageRaw)
                .environment(\.locale, (AppLanguage(rawValue: appLanguageRaw) ?? .spanish).locale)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
