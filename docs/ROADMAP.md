# Hoja de ruta

Cada fase termina con: ejecutar/revisar el proyecto, corregir errores, documentar,
hacer commit y explicar qué se hizo, qué archivos cambiaron y cuál es el siguiente paso.

## Plan actual: reconstrucción arcade de pantalla fija

Desde la versión 0.2 el juego es un **arcade de pantalla fija** (tipo Penguin Brothers de Subsino):
arenas cerradas que se ven completas, 1 o 2 jugadores, bombas, enemigos, barriles, plataformas
giratorias, llave y puerta, fases cortas con tiempo límite y puntuación. **Nada de scroll ni cámara
que siga al jugador.** Referencia de diseño: `docs/GAME_DESIGN.md`.

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Arquitectura arcade (4:3, StageManager, ScoreManager, Arena, cámara fija, HUD, título, GAME OVER/CONTINUE, victoria) | ✅ Completada |
| 2 | Player 1 y Player 2 en la arena (movimiento arcade, bloqueo/empuje, fuego amigo, reaparición) | ✅ Completada |
| 3 | Bombas arcade (física controlada, área visible, niveles de poder 1–4) | ✅ Completada |
| 4 | Barriles y destrucción del escenario (`Barrel.tscn`, destructibles con drop_table) | ✅ Completada |
| 5 | Enemigos (base con IDLE/PATROL/CHASE/ATTACK/HURT/DEAD, `EnemySpawner`) | Siguiente |
| 6 | Plataformas giratorias (`RotatingPlatform.tscn`, giro de 180°) | Pendiente |
| 7 | Llave y puerta (`KeyItem.tscn`, `ExitDoor.tscn`) | Pendiente |
| 8 | Pantalla 1 (World01_Stage01_A completa) | Pendiente |
| 9 | Pantalla 2 (World01_Stage01_B completa) | Pendiente |
| 10 | Puntuación (combos, puntos flotantes, bonificaciones, récord) | Pendiente |
| 11 | Mundo 1 – Isla Palmera (resto de fases) | Pendiente |
| 12 | Jefe Orca Ninja (arena fija, varias fases) | Pendiente |

### Fase 1 (arcade) – Arquitectura (completada)

- Resolución lógica **960×720 (4:3)** = 640×480 ×1,5; escala exacta a 1280×960 y 1920×1440.
  `stretch/aspect = keep`: en 16:9 aparecen barras laterales y el área jugable no se deforma.
  (Opción 16:9 con paneles decorativos: pendiente para más adelante.)
- Autoloads nuevos: `ScoreManager` (SCORE 1/2, combos, bonificaciones; valores en
  `data/score_table.tres`) y `StageManager` (pantallas A→B, tiempo límite, aviso, TIME 00 = pantalla
  perdida, GAME OVER, CONTINUE, fase completada). `GameManager` delega la puntuación y gestiona continues.
- `StageData` (`data/stages/world_01_stage_01.tres`): pantallas, tiempos y siguiente fase.
- `Arena` (una pantalla fija): `ArcadeCamera` fija, `EnemyManager` (enemigos restantes → `cleared`),
  `BombPool`, `PlayerSpawner`, `ArcadeHUD` (1P/2P SCORE, vidas, TIME, combo, puntos flotantes, pausa).
- Pantallas `World01_Stage01_A` y `_B` generadas por `tools/build_arenas.gd` (geometría provisional).
- `Main` con transiciones arcade (fundido, destello, cortina) y pantallas: título (PULSA START →
  1 PLAYER / 2 PLAYERS / OPCIONES / CONTROLES / SALIR), GAME OVER con CONTINUE y fase completada.
- Sonidos preparados por clave: explosión, bomba, salto, golpe, enemigo derrotado, barril, power-up,
  llave, puerta, transición, aviso de tiempo, muerte, victoria, jefe.

### Fase 2 (arcade) – Player 1 y Player 2 (completada)

- P1 pingüino azul, P2 pingüino rosa; 1 PLAYER o 2 PLAYERS desde el título; controles independientes.
- Movimiento arcade: velocidad constante (correr/deslizar desactivados con `run_enabled`), respuesta
  inmediata (aceleración y frenado casi instantáneos), salto de ~132 px (un piso de la arena).
- Los pingüinos se bloquean, se empujan despacio y pueden subirse uno encima del otro.
- Fuego amigo: las bombas dañan a cualquiera (`BombData.hurts_players`, activo por defecto).
- Reaparición arcade en el punto de inicio con invulnerabilidad.
- Pruebas: 224 comprobaciones (45 nuevas de arquitectura arcade y dos jugadores).

### Fase 3 (arcade) – Bombas (completada)

- Sprites nuevos de `blue_penguin_moves_and_bombs.png`: más fotogramas del pingüino azul (idle, caminar,
  correr, saltar, deslizarse, agacharse) y, por bomba (negra, azul, verde), mecha animada y explosión
  propia (`assets/bombs/<tipo>/`, `extract_bombs.py`).
- `CarryableBody`: física **controlada** (no realista): gravedad fija, botes limitados, frenado en el
  suelo, rebote en paredes. `Bomb` se apoya en él; cualquier objeto cargable se recoge igual.
- Tipos rehechos: negra = normal (daño 2, radio 80), azul = pequeña (1, 60), verde = grande (3, 104).
- `ExplosionInfo` + área **visible**: círculo del alcance real, animación del tipo escalada a ese radio,
  partículas y temblor. Las explosiones no distinguen jugador/enemigo/objeto.
- **BOMB LEVEL 1–4** (`PlayerConfig.bomb_power_radius` = ×1, ×1,35, ×1,7, ×2): el nivel 4 es el
  poder especial (anillo dorado, +daño y +poder de destrucción). Se ve en el HUD y se pierde al morir.
- Pruebas: 239 comprobaciones.

### Fase 4 (arcade) – Barriles, destrucción y power-ups (completada)

- `Barrel.tscn` (`BarrelData`): se recoge, se lleva, se lanza **rasante** para que ruede por el piso y
  golpee a los enemigos (se rompe al golpear), se rompe con explosiones o al estrellarse contra una pared.
- `Destructible.tscn` (`DestructibleData`: `max_health`, `destructible`, `hardness`, `points`,
  `drop_table`, efecto de restos): caja (se rompe con cualquier bomba) y bloque de piedra (dureza 2:
  solo BOMB LEVEL 4). No todo se destruye.
- `DropTable`: botín por pesos y probabilidad (reproducible con semilla).
- `PowerUp.tscn` (`PowerUpData`) con iconos de la hoja general: frutas (puntos), pastel/1UP (vida),
  armadura (protección visual que absorbe un golpe), botas (velocidad temporal), fuego (sube el nivel
  de bomba). Salen del botín, caen al suelo, parpadean y desaparecen si nadie los recoge.
- Pantallas A y B con barriles, cajas y bloques (`tools/build_arenas.gd`).
- Pruebas: 267 comprobaciones (28 nuevas).

## Historial: etapa 1 (formato plataformas con scroll, sustituido)

Se conserva todo lo construido; el nivel largo con cámara que sigue queda como «laboratorio de
movimiento» (Controles → Laboratorio) y no es el formato del juego.

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Arquitectura base | ✅ |
| 2 | Jugador 1: movimiento, estados, animaciones | ✅ |
| 3 | Jugador 2 y cooperativo local | ✅ |
| 4 | Sistema de bombas con pooling | ✅ (se adapta en la fase arcade 3) |

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

## (Sustituido) Fase 5 – Objetos interactivos — ver el plan arcade, fases 4 y 6

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
- **Opción 16:9** (paneles decorativos a los lados en vez de barras negras): prevista, no hecha.
- **Arte de las arenas**: la geometría de las pantallas es provisional (colores planos) hasta la
  fase del Mundo 1; los tiles saldrán de `worlds_01_to_06_sceneries.png`.
- **Correr/deslizarse**: siguen en el código (`run_enabled`) pero desactivados en el ajuste arcade.
