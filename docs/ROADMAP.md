# Hoja de ruta

Cada fase termina con: ejecutar/revisar el proyecto, corregir errores, documentar,
hacer commit y explicar qué se hizo, qué archivos cambiaron y cuál es el siguiente paso.

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Arquitectura base | ✅ Completada |
| 2 | Jugador 1 (pingüino azul): movimiento, estados, animaciones | ✅ Completada |
| 3 | Jugador 2 (pingüino rosa) y cooperativo local | Siguiente |
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

## Fase 2 – Jugador 1 (completada)

- 17 fotogramas del pingüino azul extraídos de la hoja de referencia a `assets/characters/blue_penguin/`
  (herramienta `tools/sprites/extract_penguin.py`, reutilizable para el rosa) y su `SpriteFrames`
  generado con `tools/build_sprite_frames.gd`.
- 10 estados: Idle, Move (caminar/correr), Jump, Fall, Land, Crouch (con gateo), Slide, Climb, Hurt, Dead.
- Coyote time, jump buffering, salto variable, giros ágiles, plataformas atravesables, escaleras,
  cuerpo agachado con comprobación de techo, daño con empuje e invulnerabilidad, muerte por vacío,
  vidas y reaparición.
- `Ladder` reutilizable (`scenes/objects/Ladder.tscn`).
- Nivel de prueba con panel de depuración, accesible desde la pantalla de arranque.
- Prueba automática ampliada a 92 comprobaciones (36 de movimiento).

## Fase 3 – Jugador 2 (siguiente)

1. Extraer el pingüino rosa: `python3 tools/sprites/extract_penguin.py pink` (misma herramienta)
   y generar su `SpriteFrames`.
2. Asignarlo al `PlayerAnimator` (`pink_penguin_frames`).
3. Cooperativo local: aparición de 2 jugadores, cada uno con sus controles; cámara que encuadre a ambos.
4. Colisión/interacción básica entre jugadores (pararse encima del compañero) si encaja en el diseño.
5. Pruebas del modo cooperativo.

## Pendientes conocidos

- **Audio**: no hay archivos todavía; `AudioManager` ya tiene las claves registradas.
- **Animaciones sin arte**: `hurt`, `death` y `victory` no están en la hoja de los pingüinos
  (se usan respaldos). Conviene generar esos fotogramas.
- **Mundos 7–10**: sin hoja de escenario; solo conceptos de enemigos.
- **iOS**: la exportación final requiere una Mac con Xcode.
