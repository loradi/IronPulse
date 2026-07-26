# Fase 4 — Filtros de biblioteca de ejercicios

## Contexto

`ExerciseListView` ya tiene búsqueda por texto sobre el catálogo local de
150 ejercicios. Falta lo único que quedaba pendiente de la Fase 4:
filtrar por `MuscleGroup` y `EquipmentType`, como muestra el mockup de
`MOCKUPS/biblioteca_de_ejercicios` (fila de chips "ALL / CHEST / BACK /
LEGS...").

## Diseño

Dos filas de chips horizontales con scroll lateral, selección única cada
una (no multi-select), combinan en AND con el buscador de texto existente:

- **Grupo muscular**: "Todos" + un chip por cada `MuscleGroup` presente en
  el catálogo real — `chest`, `back`, `legs`, `shoulders`, `biceps`,
  `triceps`, `core`, `glutes` (8 de los 11 casos del enum; `arms`,
  `calves`, `fullBody` no los usa ningún ejercicio hoy, no se muestran
  como chip porque siempre darían 0 resultados).
- **Equipo**: "Todos" + un chip por cada `EquipmentType` —
  `dumbbells`, `barbell`, `machines`, `cableMachine`, `bodyweight`
  (`fullGym` no está en el catálogo sembrado, tampoco se muestra).

Estado local en la vista: `@State private var selectedMuscleGroup:
MuscleGroup?` y `@State private var selectedEquipment: EquipmentType?`
(`nil` = "Todos"). El `filtered` computed existente se extiende para
aplicar los tres criterios (texto + grupo + equipo).

Componente nuevo, privado al archivo: `FilterChip` (label + estado
seleccionado + acción), reusado en ambas filas — evita duplicar el
`Button` + estilo de pill dos veces.

## Archivos afectados

Solo `IronPulse/Views/Exercises/ExerciseListView.swift` — sin modelo
nuevo, sin archivos nuevos.

## Testing

Sin lógica de negocio no trivial (es filtrado de un array en memoria por
igualdad de enum) — se verifica en simulador: cada chip filtra
correctamente y combina con el buscador de texto.
