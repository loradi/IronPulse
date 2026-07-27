# Navegación por tabs (Dashboard / Rutina / Ejercicios / Perfil)

## Contexto

El usuario agregó `MOCKUPS/` con una referencia visual nueva ("Watt +
Weight" / sistema de diseño "Kinetic Onyx") que incluye una arquitectura
de navegación por tab bar, distinta del `NavigationStack` de push único
que tiene la app hoy. Se decidió separar el trabajo en dos partes:
adoptar la arquitectura de navegación ahora (este spec), dejar el reskin
visual completo para después.

## Alcance

**Sí**: reestructurar la navegación a un `TabView` de 4 tabs una vez el
usuario elige un perfil.

**No**: cambiar colores, tipografía, ni ningún componente visual — el
tema `Theme/CustomColor.swift` actual (verde/naranja) se mantiene intacto.
No se tocan `ExerciseListView`, `ProfileDetailView`, `RoutineBuilderView`,
`ExercisePickerSheet` — se reusan tal cual, solo cambia desde dónde se
montan.

## Decisiones (con el usuario, 2026-07-26)

- **Multi-perfil se mantiene**: `ContentView` sigue siendo la pantalla
  raíz (lista de perfiles, crear/elegir) — no se colapsa a un solo
  perfil como asume el mockup. Al tocar un perfil, se entra a un
  `TabView` con 4 tabs para ese perfil.
- **Tab "Rutina"** (sin mockup dedicado, se definió en la charla): la
  `RoutineCard` completa (todos los días y ejercicios, ya existe, no es
  un resumen) + los dos botones "Rutina inteligente"/"Crear rutina
  manual" — todo lo que hoy vive en `DashboardView` bajo el header se
  mueve acá.
- **Tab "Perfil"**: el contenido actual de `ProfileDetailView`
  (nombre/nivel/objetivo/días, datos físicos, import de Salud) sin
  cambios. Las métricas de volumen/racha del mockup de Perfil dependen
  de `WorkoutLog`/`SetLog` (Fase 5, no arrancada) — quedan afuera hasta
  que haya datos reales que mostrar.

## Diseño

### Archivos nuevos

**`Views/MainTabView.swift`** — el shell de navegación. Cada tab tiene su
propio `NavigationStack` (así cada uno mantiene su propio historial de
push, patrón estándar de iOS):

```swift
struct MainTabView: View {
    @Bindable var profile: UserProfile
    let healthImporter: HealthKitProfileImporter

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
                ProfileDetailView(profile: profile, healthImporter: healthImporter)
            }
            .tabItem { Label("Perfil", systemImage: "gearshape") }
        }
        .tint(Color.ironAccent)
    }
}
```

**`Views/Workouts/RoutineTabView.swift`** — contenido movido tal cual
desde `DashboardView` actual: `@Query` del catálogo, `generateRoutine()`,
la `RoutineCard` (struct movida entera, sin cambios), y los dos botones.
Mismo texto, mismos estilos, mismo comportamiento — solo cambia el
archivo donde vive.

### Archivos modificados

**`DashboardView.swift`** — se achica a header únicamente (nombre,
nivel/objetivo, círculo con glow — el `private var header` actual, sin
tocar) más una línea de resumen si hay rutina activa
(`"\(routine.name) · \(routine.days.count) dias"`, sin la lista de
ejercicios). Pierde: el `@Query` del catálogo, `generateRoutine()`, la
`RoutineCard`, el toolbar de 2 botones, el parámetro `healthImporter`
(ya no lo usa).

**`ContentView.swift`** — el `NavigationLink` de cada fila de perfil
cambia su destino de `DashboardView(profile:, healthImporter:)` a
`MainTabView(profile:, healthImporter:)`. Nada más cambia en este
archivo.

### Testing

Sin lógica de negocio nueva — es reorganización de vistas SwiftUI
existentes. Se verifica en simulador: los 4 tabs navegan, cada flujo
existente (rutina inteligente, armador manual, buscador de ejercicios,
edición de perfil, import de Salud) sigue funcionando igual que antes
desde su nueva ubicación.
