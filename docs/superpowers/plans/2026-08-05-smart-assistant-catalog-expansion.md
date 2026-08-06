# Smart Assistant: Expansión del catálogo de ejercicios Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expandir la cobertura del Smart Assistant de 64 a 84 de los 146 ejercicios del catálogo, agregando 18 entradas que reusan perfiles de movimiento existentes y 2 perfiles nuevos (`straightArmPulldown`, `hangingLegRaise`).

**Architecture:** Todo el cambio vive en `MovementProfileCatalog` (`IronPulse/Services/MovementProfile.swift`) — 18 líneas nuevas en el diccionario `profiles` apuntando a los 10 `MovementProfile` ya existentes, más 2 constantes `MovementProfile` nuevas siguiendo exactamente el mismo patrón que las 10 actuales. Cero cambios en `RepCounterEngine`, `SkeletonOverlay`, `SmartAssistantModel` o cualquier vista — la UI ya decide mostrar el Smart Assistant únicamente en base a `MovementProfileCatalog.profile(forExerciseID:) != nil` (`GuidedWorkoutView.swift:264`).

**Tech Stack:** Swift, Swift Testing.

## Global Constraints

- No se agregan casos nuevos a `BodyJoint` — todos los `JointAngle` de los perfiles nuevos reusan las 12 articulaciones ya existentes.
- Cero cambio en los 10 `MovementProfile` existentes ni en las 64 entradas de catálogo ya presentes — solo adiciones.
- Todo ID de ejercicio agregado debe existir literalmente en `IronPulse/Resources/ExercisesSeed.json` (verificado por test, mismo patrón que `everyCuratedIDExistsInTheRealExerciseCatalog`).
- Tests usan Swift Testing (`@Test`/`#expect`), igual que todos los archivos existentes en `IronPulseTests/`.
- Los test runs deben pasar `-parallel-testing-enabled NO`.
- Los rangos angulares de los 2 perfiles nuevos son un punto de partida basado en biomecánica estándar (igual que los 10 existentes) — se espera reajustarlos contra Vision real en dispositivo durante la verificación manual.

---

### Task 1: Catálogo — 18 entradas reusando perfiles existentes + 2 perfiles nuevos

**Files:**
- Modify: `IronPulse/Services/MovementProfile.swift`
- Test: `IronPulseTests/MovementProfileCatalogTests.swift`

**Interfaces:**
- Produces: 20 entradas nuevas en `MovementProfileCatalog.profile(forExerciseID:)`; dos nuevas constantes privadas `straightArmPulldown` y `hangingLegRaise` de tipo `MovementProfile`.

- [ ] **Step 1: Agregar las 20 entradas nuevas al diccionario `profiles`**

En `IronPulse/Services/MovementProfile.swift`, encontrar el final del diccionario `profiles`:

```swift
        "ex_054_extension_de_piernas_en_maquina": legExtension,
        "ex_056_curl_femoral_sentado": legCurl,
    ]
```

Reemplazar con:

```swift
        "ex_054_extension_de_piernas_en_maquina": legExtension,
        "ex_056_curl_femoral_sentado": legCurl,

        // Grupo 1 — reusan un perfil existente (ver spec del
        // 2026-08-05 "smart-assistant-catalog-expansion-design" para
        // el razonamiento de cada mapeo).
        "ex_016_press_pecho_polea_de_pie": pushUp,
        "ex_026_remo_barra_inclinado": row,
        // Single-arm exercise - only counts correctly if the user
        // works with their LEFT arm toward the camera, since every
        // profile tracks left-side joints exclusively.
        "ex_030_remo_mancuerna_un_brazo": row,
        "ex_036_remo_t_manija": row,
        // Single-arm exercise - same left-side-only caveat as ex_030.
        "ex_041_remo_kettlebell_un_brazo": row,
        "ex_044_remo_alto_maquina_palanca": row,
        "ex_047_jalon_tras_nuca_agarre_ancho": row,
        "ex_059_zancada_con_barra": squat,
        "ex_077_peso_muerto_a_una_pierna_con_mancuerna": hinge,
        "ex_086_elevaciones_laterales_polea": lateralRaise,
        "ex_088_elevaciones_frontales_polea": lateralRaise,
        "ex_089_aperturas_posteriores_mancuernas": lateralRaise,
        "ex_090_aperturas_posteriores_polea": lateralRaise,
        "ex_091_aperturas_posteriores_maquina": lateralRaise,
        "ex_115_curl_cruzado_martillo": curl,
        // Lowest-confidence mapping in this batch: the forearm swings
        // backward from a bent-over torso, some of the same
        // depth-from-camera concern that excluded glute kickback -
        // included since the arc is mostly vertical, not pure depth,
        // but flag for extra attention during on-device verification.
        "ex_121_patada_triceps_mancuerna": tricepsExtension,
        "ex_125_extension_polea_una_mano": tricepsExtension,
        // Single-arm exercise - same left-side-only caveat as ex_030.
        "ex_127_extension_mancuerna_una_mano_sobre_cabeza": tricepsExtension,

        // Grupo 2 — perfiles nuevos, definidos más abajo.
        "ex_040_jalon_brazos_rectos_polea": straightArmPulldown,
        "ex_135_elevacion_piernas_colgado": hangingLegRaise,
    ]
```

- [ ] **Step 2: Agregar los 2 perfiles nuevos**

Encontrar el final del archivo (después de la definición de `legCurl`):

```swift
    private static let legCurl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 160...180,
        upRange: 70...90,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )
}
```

Reemplazar con:

```swift
    private static let legCurl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 160...180,
        upRange: 70...90,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Shoulder angle (hip-shoulder-elbow) - same triangle as
    // overheadPress, passing through the SAME "arm extended overhead"
    // position but as opposite phase labels: ~150-180 degrees with the
    // arm extended up toward the high pulley (the pulldown's "down" -
    // the rest position before pulling; numerically identical to
    // overheadPress's own "up"/lockout range, since it's the same arm
    // position), ~0-30 degrees with the arm pulled down to the side
    // (the pulldown's "up" - peak contraction, close to lateralRaise's
    // "arm at side" range). Secondary check: torso (shoulder-hip-knee)
    // stays near wherever it started - leaning back to help pull down
    // is the most common cheat, same concern as overheadPress.
    private static let straightArmPulldown = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 150...180,
        upRange: 0...30,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Hip angle (shoulder-hip-knee) - same triangle as squat/hinge's
    // secondary check, but here it's the PRIMARY signal: hanging from
    // a bar, ~160-180 degrees with legs straight down (the raise's
    // "down" - rest position), ~60-110 degrees with the legs lifted
    // (the raise's "up" - the wide range covers both straight-leg and
    // bent-knee technique without forcing one). No secondary check:
    // unlike every other profile, there's no comparable "should stay
    // put" reference joint when the torso itself is hanging from a
    // fixed grip.
    private static let hangingLegRaise = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
        downRange: 160...180,
        upRange: 60...110,
        secondaryCheck: nil
    )
}
```

- [ ] **Step 3: Build para verificar que compila**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Actualizar `curatedIDs` en `MovementProfileCatalogTests.swift` con los 20 IDs nuevos**

En `IronPulseTests/MovementProfileCatalogTests.swift`, encontrar:

```swift
        // legExtension (1, new profile)
        "ex_054_extension_de_piernas_en_maquina",
        // legCurl (1, new profile)
        "ex_056_curl_femoral_sentado",
    ]
```

Reemplazar con:

```swift
        // legExtension (1, new profile)
        "ex_054_extension_de_piernas_en_maquina",
        // legCurl (1, new profile)
        "ex_056_curl_femoral_sentado",
        // Grupo 1 — reusan un perfil existente (18)
        "ex_016_press_pecho_polea_de_pie",
        "ex_026_remo_barra_inclinado",
        "ex_030_remo_mancuerna_un_brazo",
        "ex_036_remo_t_manija",
        "ex_041_remo_kettlebell_un_brazo",
        "ex_044_remo_alto_maquina_palanca",
        "ex_047_jalon_tras_nuca_agarre_ancho",
        "ex_059_zancada_con_barra",
        "ex_077_peso_muerto_a_una_pierna_con_mancuerna",
        "ex_086_elevaciones_laterales_polea",
        "ex_088_elevaciones_frontales_polea",
        "ex_089_aperturas_posteriores_mancuernas",
        "ex_090_aperturas_posteriores_polea",
        "ex_091_aperturas_posteriores_maquina",
        "ex_115_curl_cruzado_martillo",
        "ex_121_patada_triceps_mancuerna",
        "ex_125_extension_polea_una_mano",
        "ex_127_extension_mancuerna_una_mano_sobre_cabeza",
        // Grupo 2 — perfiles nuevos (2)
        "ex_040_jalon_brazos_rectos_polea",
        "ex_135_elevacion_piernas_colgado",
    ]
```

- [ ] **Step 5: Actualizar el test de conteo total**

Encontrar:

```swift
    @Test func curatedListHasExactlySixtyFourExercises() {
        #expect(Self.curatedIDs.count == 64)
    }
```

Reemplazar con:

```swift
    @Test func curatedListHasExactlyEightyFourExercises() {
        #expect(Self.curatedIDs.count == 84)
    }
```

- [ ] **Step 6: Actualizar el test de "todo perfil tiene chequeo secundario" para reflejar la única excepción**

`hangingLegRaise` es el primer perfil de los 12 sin `secondaryCheck`, así que el test existente (que asume que todos lo tienen) deja de ser cierto. Se separa en dos tests: uno con los 11 perfiles que sí tienen chequeo (agregando `straightArmPulldown` a la lista), y uno explícito confirmando que `hangingLegRaise` es la única excepción.

Encontrar:

```swift
    /// Loops over one representative exercise ID per distinct movement
    /// profile (unlike the individual tests above, each hardcoded to a
    /// single profile) so that an 11th profile ever added without a
    /// secondary check fails this loop, instead of silently passing.
    @Test func everyMovementProfileHasANonNilSecondaryCheck() {
        let representativeIDByProfile: [String: String] = [
            "squat": "ex_048_sentadilla_trasera_con_barra",
            "pushUp": "ex_021_flexiones_pecho",
            "curl": "ex_098_curl_barra_recta",
            "overheadPress": "ex_078_press_militar_barra",
            "hinge": "ex_031_peso_muerto_convencional",
            "row": "ex_027_remo_sentado_polea",
            "tricepsExtension": "ex_117_pushdown_polea_cuerda",
            "lateralRaise": "ex_085_elevaciones_laterales_mancuernas",
            "legExtension": "ex_054_extension_de_piernas_en_maquina",
            "legCurl": "ex_056_curl_femoral_sentado",
        ]
        for (profileName, id) in representativeIDByProfile {
            let profile = MovementProfileCatalog.profile(forExerciseID: id)!
            #expect(profile.secondaryCheck != nil, "\(profileName) (via \(id)) has no secondary check")
        }
    }
}
```

Reemplazar con:

```swift
    /// Loops over one representative exercise ID per distinct movement
    /// profile that HAS a secondary check (unlike the individual tests
    /// above, each hardcoded to a single profile) so that a 12th
    /// profile ever added without a secondary check, that isn't the
    /// documented `hangingLegRaise` exception, fails this loop instead
    /// of silently passing. `hangingLegRaise` is excluded here and
    /// covered separately by `hangingLegRaiseHasNoSecondaryCheck`.
    @Test func everyMovementProfileWithASecondaryCheckHasANonNilCheck() {
        let representativeIDByProfile: [String: String] = [
            "squat": "ex_048_sentadilla_trasera_con_barra",
            "pushUp": "ex_021_flexiones_pecho",
            "curl": "ex_098_curl_barra_recta",
            "overheadPress": "ex_078_press_militar_barra",
            "hinge": "ex_031_peso_muerto_convencional",
            "row": "ex_027_remo_sentado_polea",
            "tricepsExtension": "ex_117_pushdown_polea_cuerda",
            "lateralRaise": "ex_085_elevaciones_laterales_mancuernas",
            "legExtension": "ex_054_extension_de_piernas_en_maquina",
            "legCurl": "ex_056_curl_femoral_sentado",
            "straightArmPulldown": "ex_040_jalon_brazos_rectos_polea",
        ]
        for (profileName, id) in representativeIDByProfile {
            let profile = MovementProfileCatalog.profile(forExerciseID: id)!
            #expect(profile.secondaryCheck != nil, "\(profileName) (via \(id)) has no secondary check")
        }
    }

    /// `hangingLegRaise` is the sole documented exception: there's no
    /// "should stay put" reference joint comparable to the other
    /// profiles' torso/shoulder stability checks when the body is
    /// hanging from a fixed grip.
    @Test func hangingLegRaiseHasNoSecondaryCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_135_elevacion_piernas_colgado")!
        #expect(profile.secondaryCheck == nil)
    }
}
```

- [ ] **Step 7: Agregar tests para los 2 perfiles nuevos**

Antes del cierre del `struct MovementProfileCatalogTests` (justo antes de las dos funciones agregadas en el Step 6, o en cualquier punto dentro del `struct` — el orden no importa para Swift Testing), agregar:

```swift
    @Test func straightArmPulldownSharesOverheadPressJointTriangleWithRolesReversed() {
        let straightArmPulldown = MovementProfileCatalog.profile(forExerciseID: "ex_040_jalon_brazos_rectos_polea")!
        let overheadPress = MovementProfileCatalog.profile(forExerciseID: "ex_078_press_militar_barra")!
        let sharedTriangle = JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow)

        #expect(straightArmPulldown.primaryAngle == sharedTriangle)
        #expect(overheadPress.primaryAngle == sharedTriangle)
        // Both exercises pass through the same "arm extended overhead"
        // position - it's straightArmPulldown's starting rest ("down")
        // and overheadPress's completed lockout ("up").
        #expect(straightArmPulldown.downRange == overheadPress.upRange)
    }

    @Test func straightArmPulldownHasATorsoStabilityCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_040_jalon_brazos_rectos_polea")!
        #expect(profile.secondaryCheck == .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        ))
    }

    @Test func hangingLegRaiseUsesSquatAndHingesSecondaryCheckTriangleAsItsOwnPrimaryAngle() {
        let hangingLegRaise = MovementProfileCatalog.profile(forExerciseID: "ex_135_elevacion_piernas_colgado")!
        let squat = MovementProfileCatalog.profile(forExerciseID: "ex_048_sentadilla_trasera_con_barra")!

        #expect(hangingLegRaise.primaryAngle == squat.secondaryCheck?.angle)
    }
```

- [ ] **Step 8: Run tests para verificar que todo pasa**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/MovementProfileCatalogTests`
Expected: PASS (todos los tests, incluyendo los renombrados/nuevos)

Luego el suite completo:

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add IronPulse/Services/MovementProfile.swift IronPulseTests/MovementProfileCatalogTests.swift
git commit -m "Expande el catalogo del Smart Assistant de 64 a 84 ejercicios"
```

---

### Task 2: Verificación completa

**Files:** ninguno (solo verificación)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2: Build para dispositivo real**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Nota de verificación manual**

Documentar (en el reporte, no en código) que lo siguiente necesita probarse en dispositivo real, en al menos un ejercicio de cada perfil nuevo/reusado del Grupo 2 y una muestra del Grupo 1:

- `ex_040_jalon_brazos_rectos_polea` y `ex_135_elevacion_piernas_colgado` (perfiles nuevos): el conteo de repeticiones responde al movimiento real, sin falsos positivos/negativos evidentes con los rangos angulares definidos.
- Al menos 2-3 ejercicios del Grupo 1 elegidos entre distintos perfiles reusados (ej. `ex_086_elevaciones_laterales_polea`, `ex_059_zancada_con_barra`, `ex_121_patada_triceps_mancuerna` — este último es el de menor confianza, prestarle atención especial).
- El botón de Smart Assistant aparece para los 20 ejercicios nuevos en `GuidedWorkoutView` (confirmando que no hace falta ningún cambio de UI, solo el catálogo).
