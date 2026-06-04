# Ziito iOS — Clon exacto de la app web (conservando la montaña 3D)

## Objetivo

La app iOS debe verse y comportarse **absolutamente igual** que la app web (`web-ziito`),
conservando únicamente la montaña 3D nativa (carpeta `Views/Path`). Mismos colores,
mismo layout, mismas pantallas, mismos componentes.

## Identidad visual web a replicar

- Fondo menta `#F7FBF9`, tarjetas blancas con borde sutil `#E2E8F0`, esquinas redondeadas.
- Primario verde bosque `#186D4E`, acento ámbar `#F6A823`, secundario verde claro `#E4F0EB`.
- Títulos grandes extrabold dentro del scroll (no nav bars nativas).
- Tab bar inferior personalizada: Hoy (sol), Horario (calendario), Montaña, Más.

## Tareas

- [x] Theme compartido (colores web, estilo tarjeta, header, badges, helpers).
- [x] ContentView con tab bar personalizada + fondo menta.
- [x] Pantalla Hoy idéntica a la web.
- [x] Pantalla Horario idéntica a la web.
- [x] Pantalla Montaña (lista) con la montaña 3D nativa conservada.
- [x] Más + subpantallas (Tareas, Evaluaciones, Materias, Calendario, Estadísticas).
- [x] Barra de gamificación + hoja de recompensas, FOG MODE, ajustes Pomodoro, guía.
- [x] runChecks iOS en verde.

## Capa de datos

Se conserva intacta: SwiftData (Subject, Exam, StudyTask, ClassSession, StudySession,
FocusLog), PomodoroService, GamificationService, TourManager, ScheduleService,
ZiitonerService, PlannerViewModel. Solo se reescribe la capa de vistas.
