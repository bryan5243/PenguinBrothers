# Hoja de ruta

Cada fase termina con: ejecutar/revisar el proyecto, corregir errores, documentar,
hacer commit y explicar qué se hizo, qué archivos cambiaron y cuál es el siguiente paso.

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Arquitectura base | ✅ Completada |
| 2 | Jugador 1 (pingüino azul): movimiento, estados, animaciones | ✅ Completada |
| 3 | Jugador 2 (pingüino rosa) y cooperativo local | ✅ Completada |
| 4 | Sistema de bombas (azul, verde, negra) con pooling | Siguiente |
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

## Fase 3 – Jugador 2 y cooperativo (completada)

- 17 fotogramas del pingüino rosa (misma herramienta; se mejoró la limpieza de nieve para ambos)
  y su `SpriteFrames`, asignado al J2.
- `PlayerSpawner`: 1 o 2 jugadores según el modo, con marcadores de aparición.
- `CoopCamera`: encuadra a ambos, se aleja al separarse y los retiene en pantalla.
- Asignación automática de mandos (1 mando en cooperativo: J1 teclado, J2 mando).
- Plataforma sobre la cabeza: un pingüino puede subirse encima del otro y ser transportado.
- Reaparición junto al compañero, eliminación por jugador y fin de partida solo sin jugadores.
- Etiquetas P1/P2 y botón «Probar cooperativo» en la pantalla de arranque.
- Pruebas: 117 comprobaciones (25 nuevas de cooperativo).

### Corrección: normalización del Pingüino Azul (tras la Fase 3)

- Nuevo diseño del azul desde `blue_penguin_full_animations.png` con
  `tools/sprites/extract_character_sheet.py`: 18 animaciones en un lienzo común, pies en la base,
  sin objetos ni efectos incrustados; originales en `source/`, normalizados en `processed/`.
- Jugador con `VisualRoot` (escala global única: `visual_height` + `visual_scale`), `GroundPoint`,
  colisión por estado (`slide_height` propio) y superposición de depuración (F1).
- Escena de validación `scenes/player/BluePenguinAnimationTest.tscn`.
- Pruebas: 140 comprobaciones (21 nuevas de normalización).

## Fase 4 – Sistema de bombas (completada)

- `Bomb` (RigidBody2D) única para todos los tipos, configurada por `BombData`: mecha con aviso
  de parpadeo, radio, daño, empuje, peso, gravedad, rebote, fricción, sprite, tinte y sonido.
- Tipos como datos (`data/bombs/*.tres`, generados por `tools/setup_project.gd`):
  azul (1 daño, radio 72), verde (2, 112), negra (3, 152). Tipo nuevo = `.tres` nuevo.
- `PlayerBombs`: lanzar (Q / B), lanzamiento alto (arriba + bomba), colocar (abajo + bomba),
  recoger / llevar / lanzar (E / X), soltar (abajo + E), cambiar tipo (R / Y) saltando los que no
  tienen munición, límite de bombas propias en juego y munición por tipo.
- Patadas: caminar contra una bomba libre en el suelo la lanza rodando.
- `Explosion`: consulta de área (jugadores, enemigos, bombas, objetos), daño vía `take_damage`,
  empuje a jugadores (daño solo si el tipo tiene `hurts_players`), impulso a cuerpos rígidos y
  reacción en cadena con retraso; temblor de cámara; `EventBus.bomb_exploded`.
- `BombPool`: bombas y explosiones reutilizables, precargadas por nivel.
- Sprites de bombas y de la explosión extraídos de la hoja general (`tools/sprites/extract_bombs.py`).
- Animaciones de acción superpuestas (`throw`, `place_bomb`, `lift`) y `carry` al llevar la bomba.
- Nivel de prueba con dianas (`TestTarget`) para comprobar daño y radio.
- Pruebas: 173 comprobaciones (31 nuevas de bombas).

## Fase 5 – Objetos interactivos (siguiente)

1. Clase base de objeto cargable (reutiliza recoger/llevar/lanzar de `PlayerBombs` generalizado
   a `carried_object`): barriles y cajas.
2. Barriles: se lanzan contra enemigos o interruptores; cajas rompibles con explosiones.
3. Plataformas móviles (AnimatableBody2D), interruptores y puertas.
4. Objetos destruibles que reaccionan a `apply_explosion`.
5. Extraer sprites de barril, caja, plataformas y escaleras de las hojas de referencia.

## Pendientes conocidos

- **Audio**: no hay archivos todavía; `AudioManager` ya tiene las claves registradas
  (incluidas `explosion`, `bomb_throw`, `bomb_place`, `bomb_kick`, `bomb_switch`).
- **Pingüino rosa y bombas**: sin poses de lanzar/colocar/llevar; usa respaldos.
- **Pingüino rosa**: sigue con el diseño anterior (9 animaciones; `hurt`, `death`, `victory`,
  `lift`, `carry`, `throw`, `place_bomb` usan respaldos). Falta una hoja completa como la del azul.
- **Nadar** (azul): el agua de la hoja está fundida con el dibujo; hace falta arte sin fondo.
- **Mundos 7–10**: sin hoja de escenario; solo conceptos de enemigos.
- **iOS**: la exportación final requiere una Mac con Xcode.
