# Ícono de Smart Assistant en biblioteca y rutina Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mostrar un ícono chico (`camera.viewfinder`) junto a cada ejercicio que tiene cobertura de Smart Assistant, en la biblioteca de ejercicios, el detalle de un ejercicio, y las filas de la rutina.

**Architecture:** Un componente SwiftUI nuevo y chico (`SmartAssistantBadge`), sin lógica propia — cada call site decide si mostrarlo evaluando `MovementProfileCatalog.profile(forExerciseID: exercise.id) != nil`, la misma condición que ya usa `GuidedWorkoutView` para el botón del Smart Assistant. Cero cambios de datos/modelo.

**Tech Stack:** SwiftUI.

## Global Constraints

- Cero cambios en `MovementProfileCatalog`, `Exercise`, o cualquier lógica de negocio — esto es puramente presentacional.
- El texto de accesibilidad se agrega a `IronPulse/Localizable.xcstrings` con traducciones reales en `en`/`es`/`fr` (no solo `defaultValue`), mismo patrón que las claves `exercise.*` y `smart_assistant.*` ya existentes.
- "Smart Assistant" se traduce como "Asistente inteligente" (es) / "Smart assistant" (en) / "Assistant intelligent" (fr), igual que en `guided_session.smart_assistant`.

---

### Task 1: Componente `SmartAssistantBadge` + string localizado

**Files:**
- Create: `IronPulse/Components/SmartAssistantBadge.swift`
- Modify: `IronPulse/Localizable.xcstrings`

**Interfaces:**
- Produces: `SmartAssistantBadge: View` (sin parámetros — el call site decide si renderizarla con un `if`).

- [ ] **Step 1: Agregar la clave localizada**

En `IronPulse/Localizable.xcstrings`, encontrar:

```json
    "exercise.compound_badge" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Compound"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Compuesto"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Composé"
          }
        }
      }
    },
    "experience_level.advanced" : {
```

Reemplazar con:

```json
    "exercise.compound_badge" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Compound"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Compuesto"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Composé"
          }
        }
      }
    },
    "exercise.smart_assistant_badge" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Smart assistant available"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Asistente inteligente disponible"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Assistant intelligent disponible"
          }
        }
      }
    },
    "experience_level.advanced" : {
```

- [ ] **Step 2: Crear `SmartAssistantBadge.swift`**

Crear `IronPulse/Components/SmartAssistantBadge.swift` con:

```swift
import SwiftUI

/// Small icon shown next to an exercise wherever it's listed (library,
/// exercise detail, routine rows) to indicate it has Smart Assistant
/// coverage. Carries no logic of its own — each call site decides
/// whether to show it via `MovementProfileCatalog.profile(forExerciseID:) != nil`,
/// the same condition `GuidedWorkoutView` already uses to show the
/// Smart Assistant button itself. Uses the same SF Symbol as that
/// button (`camera.viewfinder`) so the icon reads as the same feature.
struct SmartAssistantBadge: View {
    var body: some View {
        Image(systemName: "camera.viewfinder")
            .font(.system(size: 14))
            .foregroundStyle(Color.ironAccent)
            .accessibilityLabel(
                String(
                    localized: "exercise.smart_assistant_badge",
                    defaultValue: "Smart assistant available",
                    bundle: AppLanguage.current.bundle,
                    locale: AppLanguage.current.locale
                )
            )
    }
}
```

- [ ] **Step 3: Build para verificar que compila**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add IronPulse/Components/SmartAssistantBadge.swift IronPulse/Localizable.xcstrings
git commit -m "Agrega el componente SmartAssistantBadge y su string localizado"
```

---

### Task 2: Integrar el ícono en biblioteca, detalle y rutina

**Files:**
- Modify: `IronPulse/Views/Exercises/ExerciseListView.swift`
- Modify: `IronPulse/Views/Workouts/RoutineTabView.swift`

**Interfaces:**
- Consumes: `SmartAssistantBadge` (de Task 1), `MovementProfileCatalog.profile(forExerciseID:) -> MovementProfile?` (ya existente).

Sin tests nuevos — es integración de vistas SwiftUI puras, mismo criterio que el resto de este archivo/proyecto (no se testean automáticamente cambios de layout/vista). Se verifica manualmente en simulador (Task 3).

- [ ] **Step 1: `ExerciseListView` — fila de la biblioteca**

En `IronPulse/Views/Exercises/ExerciseListView.swift`, encontrar:

```swift
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(exercise.name).font(.wwTitle3).lineLimit(2)
                            Spacer()
                            if exercise.isCompound {
                                TagBadge(text: String(localized: "exercise.compound_badge", defaultValue: "Compound", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale))
                            }
                        }
```

Reemplazar con:

```swift
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(exercise.name).font(.wwTitle3).lineLimit(2)
                            Spacer()
                            if MovementProfileCatalog.profile(forExerciseID: exercise.id) != nil {
                                SmartAssistantBadge()
                            }
                            if exercise.isCompound {
                                TagBadge(text: String(localized: "exercise.compound_badge", defaultValue: "Compound", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale))
                            }
                        }
```

- [ ] **Step 2: `ExerciseDetailView` — pantalla de detalle**

En el mismo archivo, encontrar:

```swift
                if exercise.isCompound {
                    TagBadge(text: String(localized: "exercise.compound_badge", defaultValue: "Compound", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale))
                }

                MuscleDiagramView(primary: exercise.muscleGroup, secondary: exercise.secondaryMuscles)
```

Reemplazar con:

```swift
                HStack(spacing: 8) {
                    if MovementProfileCatalog.profile(forExerciseID: exercise.id) != nil {
                        SmartAssistantBadge()
                    }
                    if exercise.isCompound {
                        TagBadge(text: String(localized: "exercise.compound_badge", defaultValue: "Compound", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale))
                    }
                }

                MuscleDiagramView(primary: exercise.muscleGroup, secondary: exercise.secondaryMuscles)
```

- [ ] **Step 3: `RoutineTabView.RoutineCard` — fila de ejercicio en la rutina**

En `IronPulse/Views/Workouts/RoutineTabView.swift`, encontrar:

```swift
                    ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex.exercise)
                        } label: {
                            HStack {
                                Text(ex.exercise.name).font(.wwCaption)
                                Spacer()
                                Text("\(ex.targetSets)x\(ex.targetRepsMin)-\(ex.targetRepsMax)")
                                    .font(.wwCaption)
                                    .foregroundStyle(Color.ironTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
```

Reemplazar con:

```swift
                    ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex.exercise)
                        } label: {
                            HStack {
                                Text(ex.exercise.name).font(.wwCaption)
                                if MovementProfileCatalog.profile(forExerciseID: ex.exercise.id) != nil {
                                    SmartAssistantBadge()
                                }
                                Spacer()
                                Text("\(ex.targetSets)x\(ex.targetRepsMin)-\(ex.targetRepsMax)")
                                    .font(.wwCaption)
                                    .foregroundStyle(Color.ironTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
```

- [ ] **Step 4: Build para verificar que compila**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

Luego correr el suite completo una vez para confirmar que nada se rompió:

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Views/Exercises/ExerciseListView.swift IronPulse/Views/Workouts/RoutineTabView.swift
git commit -m "Muestra el icono de Smart Assistant en la biblioteca, el detalle y las filas de la rutina"
```

---

### Task 3: Verificación completa

**Files:** ninguno (solo verificación)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2: Build para dispositivo real**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Nota de verificación manual**

Documentar (en el reporte, no en código) que lo siguiente necesita probarse en simulador/dispositivo:

- El ícono aparece junto a un ejercicio conocido con cobertura (ej. `ex_048_sentadilla_trasera_con_barra`) y NO aparece junto a uno sin cobertura (ej. `ex_001_press_plano_barra`), en los 3 lugares: biblioteca, detalle, rutina.
- En la fila de la biblioteca y en el detalle, cuando un ejercicio es compuesto Y tiene Smart Assistant, ambos indicadores (ícono + badge "Compound") se muestran juntos sin solaparse ni verse apretados.
- El ícono no rompe el layout de la fila de rutina cuando el nombre del ejercicio es largo (ej. "Elevación de talones en prensa de piernas").
