# Hoja de ruta

Cada fase termina con: ejecutar/revisar el proyecto, corregir errores, documentar,
hacer commit y explicar qué se hizo, qué archivos cambiaron y cuál es el siguiente paso.

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Arquitectura base | ✅ Completada |
| 2 | Jugador 1 (pingüino azul): movimiento, estados, animaciones | Siguiente |
| 3 | Jugador 2 (pingüino rosa) y cooperativo local | Pendiente |
| 4 | Sistema de bombas (azul, verde, negra) con pooling | Pendiente |
| 5 | Objetos interactivos (barriles, cajas, plataformas, puertas, escaleras) y power-ups | Pendiente |
| 6 | HUD | Pendiente |
| 7 | Mundo 1 – Isla Palmera: nivel jugable, cámara, checkpoints, meta | Pendiente |
| 8 | Enemigos del Mundo 1 | Pendiente |
| 9 | Jefe Orca Ninja | Pendiente |
| 10 | Menú principal, pausa y guardado integrados | Pendiente |
| 11 | Controles móviles | Pendiente |
| 12 | Mundo 2 – Templo Oriental | Pendiente |
| 13 | Mundos 3–10 | Pendiente |
| 14 | Optimización | Pendiente |
| 15 | Exportación multiplataforma | Pendiente |

## Fase 1 – Arquitectura base (completada)

- Proyecto Godot 4.7: 1280×720 adaptable, renderizador Compatibility, orientación horizontal.
- Estructura de carpetas completa (`scenes/`, `scripts/`, `assets/`, `audio/`, `data/`, `docs/`).
- Autoloads: `EventBus`, `SaveManager`, `AudioManager`, `InputManager`, `GameManager`.
- Input Map para 2 jugadores: teclado, mando por dispositivo y pausa.
- Capa de abstracción de entrada (`InputManager` + `PlayerInput`).
- Clases de datos: `PlayerConfig`, `BombData`, `EnemyData`, `BossData`, `PowerUpData`, `WorldData`.
- Datos de los 10 mundos y configuración por defecto del jugador.
- Utilidades reutilizables: `StateMachine`, `State`, `HealthComponent`.
- Escena `Main` con cambio de pantallas y `BootScreen` (probador de controles).
- Esqueleto del jugador: `Player.tscn` con entrada, máquina de estados, animador y vida.
- Hojas de referencia en `assets/references/`.
- Prueba de humo automatizada (`tests/SmokeTest.tscn`, 54 comprobaciones).

## Fase 2 – Jugador 1 (siguiente)

1. Extraer los fotogramas del pingüino azul desde
   `assets/references/characters/penguins_blue_pink_animations.png` a `assets/characters/blue_penguin/`.
2. Crear su `SpriteFrames` con los nombres estándar de animación.
3. Implementar los estados: Idle, Walk/Run, Jump, Fall, Land, Crouch, Slide, Climb, Hurt, Dead.
4. Escena de prueba con suelo, plataformas y escalera para validar el movimiento.
5. Ampliar la prueba de humo con comprobaciones de movimiento.

## Pendientes conocidos

- **Audio**: no hay archivos todavía; `AudioManager` ya tiene las claves registradas.
- **Mundos 7–10**: sin hoja de escenario; solo conceptos de enemigos.
- **iOS**: la exportación final requiere una Mac con Xcode.
