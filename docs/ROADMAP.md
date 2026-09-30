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
| 5 | Enemigos (base con IDLE/PATROL/CHASE/ATTACK/HURT/DEAD, `EnemySpawner`) | ✅ Completada |
| 6 | Plataformas giratorias (`RotatingPlatform.tscn`, giro de 180°) | ✅ Completada |
| 7 | Llave y puerta (`KeyItem.tscn`, `ExitDoor.tscn`) | ✅ Completada |
| 8 | Pantalla 1 (World01_Stage01_A completa) | Siguiente |
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

### Fase 5 (arcade) – Enemigos del Mundo 1 (completada)

- `Enemy.tscn` única + `EnemyData` + comportamiento (`EnemyBehavior`): cangrejo (WALKER), ermitaño
  (SHELL), gaviota (FLYER) y pulpo (SWIMMER, dispara tinta). Estados IDLE, PATROL, CHASE, ATTACK,
  HURT, DEAD y SPECIAL. Usan plataformas: bajan de las atravesables y saltan al piso de arriba.
- `EnemySpawner` (tipo, entrada izquierda/derecha/arriba/punto, retraso, intervalo, cantidad,
  máximo vivos, oleada) y oleadas en `EnemyManager`; pantalla limpia al acabar con todos.
- Derrotas con puntos y **combo**, botín (`enemy_drops`), daño por contacto y por ataque.
- Sprites de los 4 enemigos extraídos de sus hojas (`tools/sprites/extract_enemies.py`).
- Pruebas: 293 comprobaciones (25 nuevas).

### Ajustes tras la Fase 5 + arte de las arenas

- Enemigos: ya no tiemblan girándose de lado a lado (zona muerta y retardo de giro, persiguen el
  último piso del jugador cuando salta) ni se amontonan (patrullando se dan la vuelta entre ellos).
- Bombas: la colocada se queda donde se puso (las patadas pasan a ser opcionales,
  `PlayerConfig.kick_enabled`, desactivadas); el lanzamiento es corto (~70–100 px) y saltando cae
  solo un poco más lejos; al tocar el suelo casi no rueda.
- Pantallas A y B de la 1-1 con el arte de la hoja de tiles del Mundo 1 (`docs/WORLDS.md`).
- Pruebas: 296 comprobaciones.

### Llevar barriles con sprites propios + fondo animado

- Pingüino azul: animaciones `carry_barrel_*` (levantar, quieto, caminar, correr, saltar,
  agacharse, lanzar, soltar) extraídas de `blue_penguin_carry_barrel.png`. Mientras las usa, el
  sprite del barril se oculta (el barril va dibujado en los fotogramas). El rosa, sin esa hoja,
  sigue mostrando el barril real encima de `carry`.
- Fondo del Mundo 1 animado (`AnimatedBackdrop`): base fija + franja del mar que funde entre los
  fotogramas de `world_01_background_frames.png`.
- Pruebas: 300 comprobaciones.

### Barril al instante, fondo FHD y deslizarse

- Lanzar/soltar el barril: el pingüino deja de dibujarlo en el mismo fotograma en que el barril
  real sale (antes se veían los dos unos instantes).
- Fondo del Mundo 1 con los 10 fotogramas FHD (`world_01_background_fhd/`), a 960×672 sin
  re-escalar en juego; la máscara del mar sale del movimiento real entre fotogramas.
- Deslizarse activado en el arcade: abajo mientras se camina (no requiere correr).
- Pruebas: 303 comprobaciones.

### Fase 6 – Plataformas giratorias

- `RotatingPlatform` (`scripts/platforms/`, `scenes/platforms/RotatingPlatform.tscn`): disco de
  madera con superficie atravesable. Un jugador encima pulsa **arriba** → tiembla (`windup_time`),
  gira (`flip_time`) y lo lanza hacia arriba (`launch_height`, ajustable por plataforma);
  **abajo** → se abre y los de encima caen al piso inferior (`can_flip_down` = falso en las que
  están a ras de suelo). Sale con ella todo lo que va encima: los dos jugadores y las bombas o
  barriles en reposo (despedidos). Tras girar espera `cooldown`; mientras gira no se puede pisar.
- Ajustes en `RotatingPlatformData` (`data/platforms/rotating_platform.tres`).
- `Player.launch(velocity)` (lanzamiento externo: pasa a caer/saltar sin romper los estados) y
  `PlayerInput.up_pressed` / `crouch_pressed` (flancos de pulsación).
- `tools/build_arenas.gd`: clave `rotators` por pantalla (posición de la superficie, altura de
  lanzamiento, ¿abre hacia abajo?) y poste de madera debajo. Pantalla A: 560→448 y 448→224;
  pantalla B: dos desde el suelo hasta los tablones de 448. La pantalla A acorta su tablón de 448
  y la B mueve los puntos de inicio para dejar sitio.
- Clave de sonido `platform_flip` registrada (sin archivo de audio todavía).
- Pruebas: 326 comprobaciones (23 nuevas, `tests/rotating_platform_test.gd`).

### Fase 7 – Llave y puerta

- `KeyItem` (`scripts/objects/key_item.gd`, `scenes/items/KeyItem.tscn`): al limpiar la pantalla A
  (`EnemyManager.cleared`) la `Arena` la hace aparecer en `key_position` y cae hasta el suelo o
  plataforma; se recoge al tocarla (puntos `ScoreTable.key`), flota sobre la cabeza del portador
  y, si este muere, cae donde murió y cualquiera puede cogerla (espera de 1 s). El portador se
  guarda en `StageManager.carry_over` (`key`, `key_owner`), así pasa de la A a la B y sobrevive a
  repetir la pantalla por el tiempo.
- Pantalla A: 0,9 s después de recoger la llave se pasa a la B (`StageManager.next_screen()`);
  si el portador muere en ese margen, no hay transición.
- `ExitDoor` (`scripts/objects/exit_door.gd`, `scenes/objects/ExitDoor.tscn`): cerrada hasta que
  el portador de la llave llega a ella; entonces se abre (portal azul), gasta la llave y 0,8 s
  después completa la pantalla B, y con ella la fase (bonificación de tiempo y de fase).
  Sin llave no hace nada (se sacude si alguien pulsa arriba delante).
- `ObjectiveData` (`data/items/objective.tres`): tamaños, tiempos y alcance de llave y puerta.
- `tools/build_arenas.gd`: `key_position` (A) y `door` (B, arriba a la izquierda).
- Pruebas: 351 comprobaciones (25 nuevas, `tests/objective_test.gd`).

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
- **Fondo animado**: los 10 fotogramas FHD están alineados pero generados por separado, así que
  solo se anima el mar (fuera de él «hervirían»). Nubes, gaviotas o palmeras en movimiento
  necesitarían capas separadas.
- **Pingüino rosa**: sin hoja de llevar barril; usa el barril visible como respaldo.
- **Correr**: sigue en el código (`run_enabled`) pero desactivado en el ajuste arcade.
