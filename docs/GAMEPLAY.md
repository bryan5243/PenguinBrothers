# Jugabilidad

## Controles

Los comandos son iguales en todas las plataformas; el Input Map los asigna a cada dispositivo.
Se configuran en `tools/setup_project.gd`.

| Comando | Jugador 1 (teclado) | Jugador 2 (teclado) | Mando (A/B/X/Y tipo Xbox) |
|---|---|---|---|
| Izquierda / derecha | A / D | ← / → | Stick izquierdo o cruceta |
| Arriba (escaleras) | W | ↑ | Stick arriba o cruceta ↑ |
| Agacharse / bajar | S | ↓ | Stick abajo o cruceta ↓ |
| Saltar | Espacio / W | ↑ | A |
| Bomba | Q | Ctrl derecho / Num 0 | B |
| Interactuar, recoger, lanzar | E | Shift derecho / Num 1 | X |
| Cambiar bomba | R | Enter / Num 2 | Y |
| Pausa | Esc / P | Esc / P | Start |

- **Mandos** (`InputManager.refresh_gamepads()`, se recalcula al conectar o desconectar):

  | Mandos conectados | Individual | Cooperativo |
  |---|---|---|
  | 0 | J1 con teclado (WASD o flechas) | J1 WASD, J2 flechas |
  | 1 | J1 con teclado o mando | **J1 teclado, J2 mando** |
  | 2 o más | J1 con cualquiera | Mando 1 → J1, mando 2 → J2 (el teclado sigue funcionando) |
- **Modo individual**: el Jugador 1 acepta también los controles del Jugador 2
  (flechas, segundo mando). Así se puede jugar solo con las flechas, como pide el diseño.
- **Pantalla táctil** (Fase 11): joystick virtual + botones Saltar, Bomba, Interactuar,
  Cambiar bomba y Pausa. Solo aparecen en dispositivos táctiles y se anclan a los bordes
  (sin posiciones absolutas). Inyectan comandos con `InputManager.press_command()`.

Acciones del Input Map: `p1_move_left`, `p1_move_right`, `p1_up`, `p1_crouch`, `p1_jump`,
`p1_interact`, `p1_bomb`, `p1_switch_bomb` (igual con `p2_`) y `pause`.

## Movimiento del jugador (ajuste arcade)

Parámetros en `PlayerConfig` (`data/player/default_player_config.tres` usa los valores por defecto).
Ajuste arcade: velocidad constante, respuesta inmediata al joystick y salto de un piso de la arena.

| Parámetro | Valor | Descripción |
|---|---|---|
| `move_speed` | 240 | Velocidad arcade constante |
| `run_enabled` / `run_speed` / `run_delay` | **false** / 340 / 0,55 s | Correr desactivado en el arcade (deslizarse no depende de correr) |
| `acceleration` / `air_acceleration` | 6000 / 3600 | Casi instantáneo: velocidad máxima en ~3 frames |
| `friction` / `air_friction` | 6000 / 2400 | Frena al instante al soltar |
| `jump_force` / `gravity` / `max_fall_speed` | 680 / 1750 / 950 | Salto completo ≈ 132 px (los pisos de la arena están a 112 px) |
| `jump_cut_speed` | 400 | Salto variable: al soltar pronto ≈ 42 px |
| `coyote_time` / `jump_buffer_time` | 0,10 / 0,12 s | Tolerancias de salto |
| `land_duration` / `land_min_fall_speed` | 0,08 s / 380 | Aterrizaje tras caída fuerte (no bloquea el control) |
| `slide_speed` / `slide_duration` / `slide_friction` | 520 / 0,5 s / 700 | Deslizamiento sobre el vientre |
| `slide_enabled` | true | Agacharse caminando (dirección pulsada, manos libres) inicia el deslizamiento |
| `slide_trigger_ratio` | 0,85 | Velocidad mínima: 85 % de `move_speed` (o de `run_speed` si se corre) |
| `crawl_speed` | 110 | Gatear agachado bajo un techo bajo |
| `climb_speed` | 180 | Escaleras |
| `drop_through_time` | 0,25 s | Tiempo que se ignoran las plataformas al bajar |
| `body_radius` / `body_height` / `crouch_height` / `slide_height` | 16 / 60 / 38 / 32 | Cápsula de colisión de pie, agachado y deslizándose |
| `push_speed` | 110 | Velocidad al empujar al compañero |
| `max_health` / `invulnerability_time` | 3 / 1,6 s | Vida por vida; parpadeo tras recibir daño |
| `knockback` / `hurt_duration` | (300, −420) / 0,45 s | Empuje y tiempo sin control al recibir daño |
| `fall_death_y` / `respawn_delay` | 1400 / 1,5 s | Caída al vacío (el nivel puede cambiar la altura) y espera antes de reaparecer |

### Estados (`scripts/player/states/`)

```
Idle ⇄ Move ──(abajo caminando)──> Slide ──> Crouch / Idle
  │      │                          (bajo techo: sigue agachado y gatea)
  │      └──(abajo)──> Crouch ──(abajo+saltar en plataforma)──> Fall
  ├──(saltar)──> Jump ──(v ≥ 0)──> Fall ──(suelo)──> Land / Idle / Move
  ├──(arriba en escalera)──> Climb ──(arriba del todo)──> Idle
  │                          (saltar)──> Jump
  └── cualquier estado: daño ──> Hurt ;  vida 0 o vacío ──> Dead ──> reaparece / fin
```

- Orden por frame: `PlayerInput.update()` → temporizadores (coyote, buffer) → estado actual → `move_and_slide()`.
- Coyote time y jump buffering están en `Player` y los comparten todos los estados.
- Plataformas atravesables: capa 6; se colisiona desde arriba (`one_way_collision`).
  Abajo + saltar las atraviesa; al trepar escaleras se ignoran.
- Escaleras: `scenes/objects/Ladder.tscn` (Area2D, capa 5). La parte superior va a la altura de la
  plataforma a la que lleva. Arriba para subir, abajo desde lo alto para bajar, saltar para soltarse.
- Muerte: salto y giro arcade; tras `respawn_delay` se descuenta una vida en `GameManager` y
  reaparece en `spawn_position` (los checkpoints la actualizarán en la Fase 7). Sin vidas: `EventBus.game_over`.

### Laboratorio de movimiento (legado)

`scenes/worlds/test_level/PlayerTestLevel.tscn` (Título → CONTROLES → «Laboratorio 1J/2J»). Es un
nivel largo con cámara que sigue: **no es el formato del juego**, solo sirve para probar mecánicas. Incluye plataformas, escalón, escalera, túnel bajo, vacío y panel de
depuración (estado, vida, vidas y velocidad de cada jugador, zoom de cámara). Se genera con
`tools/build_player_test_level.gd`; su geometría usa placeholders de color hasta tener los
tiles del Mundo 1 (Fase 7).

## Dos jugadores en la arena (arcade, Fase 2)

- **1 PLAYER / 2 PLAYERS** desde el título. P1 = pingüino azul (teclado izquierdo / mando 1),
  P2 = pingüino rosa (flechas / mando 2). Ambos son jugadores reales, con controles independientes.
- **Arena cerrada**: paredes, techo y suelo; nadie sale de la pantalla y la cámara no se mueve.
- **Se bloquean y se empujan**: la `Arena` activa `players_collide`; al caminar contra el compañero
  se le empuja a `push_speed`. Siguen pudiendo subirse uno encima del otro (`HeadPlatform`).
- **Fuego amigo**: las explosiones afectan a todos (`BombData.hurts_players = true`).
- **Reaparición arcade**: en el propio punto de inicio (`respawn_near_partner = false` en la arena),
  con invulnerabilidad. Sin vidas: eliminado; sin nadie: GAME OVER → CONTINUE.
- **Tiempo**: cada pantalla tiene TIME (90 s en la 1-1); con poco tiempo parpadea en rojo; a cero,
  todos pierden una vida y la pantalla se repite.
- **Pausa**: Esc / P / Start; en pausa, Bomba vuelve al título.

## Cooperativo local (etapa 1 · laboratorio de movimiento)

- **Aparición**: `PlayerSpawner` (`scripts/worlds/player_spawner.gd`) crea 1 o 2 jugadores según
  `GameManager.game_mode`, en sus marcadores `P1` y `P2`. J1 = pingüino azul, J2 = pingüino rosa.
- **Etiquetas**: «P1» / «P2» sobre cada pingüino, solo en cooperativo.
- **Cámara compartida**: `CoopCamera` (`scripts/utilities/coop_camera.gd`) sigue el centro de los
  jugadores vivos, se aleja hasta `min_zoom` (0,72) si se separan y, si aun así no caben, no deja
  que ninguno salga de la pantalla. Respeta los límites del nivel. Parámetros exportados:
  `max_zoom`, `min_zoom`, `zoom_speed`, `margin`, `view_offset`, `screen_edge_padding`.
- **Pararse sobre el compañero**: cada pingüino tiene una plataforma atravesable sobre la cabeza
  (`HeadPlatform`, capa 6, `head_platform_offset` = 12 px sobre la colisión). El de arriba es
  transportado si el de abajo camina o salta, y baja con abajo + saltar. Útil para llegar más alto.
- En el laboratorio **los jugadores no chocan entre sí** de lado (en la arena sí).
- **Vidas por jugador**: en el laboratorio cada uno reaparece **junto a su compañero** si está vivo y en el
  suelo (si no, en el punto de inicio). Sin vidas queda **eliminado** (`EventBus.player_eliminated`);
  la partida termina (`EventBus.game_over`) solo cuando no queda ningún jugador activo.
- Preparado para después: revivir al compañero, compartir objetos, ataques combinados,
  puntuación individual y de equipo (`ScoreManager.scores` es por jugador).

## Animaciones

Nombres estándar (una `SpriteFrames` por personaje; nunca una animación gigante compartida):

| Jugador | Enemigos y jefes |
|---|---|
| `idle`, `walk`, `run`, `jump`, `fall`, `land`, `crouch`, `slide`, `climb`, `lift`, `carry`, `throw`, `place_bomb`, `hurt`, `death`, `victory` | `idle`, `walk`, `run`, `attack`, `hurt`, `death`, `special` |

`PlayerAnimator` usa respaldos si falta una animación (por ejemplo `run` → `walk`), así un
personaje incompleto no rompe el juego. También gestiona efectos visuales sin afectar la
jugabilidad: estirar/aplastar al saltar y aterrizar, destello rojo al recibir daño y parpadeo
durante la invulnerabilidad. Poderes y transformaciones añadirán `SpriteFrames` alternativos.

### Sprites de los pingüinos

#### Estructura del jugador (visual separado de la física)

```
Player (CharacterBody2D)        ← la física y la cámara siguen a este nodo
├── CollisionShape2D            ← cuerpo físico; su forma la cambia el ESTADO, nunca la animación
├── VisualRoot (Node2D)         ← única escala visual global, anclada al GroundPoint
│   └── Animator (AnimatedSprite2D, PlayerAnimator)  ← animaciones + flip_h + efectos
├── GroundPoint (Marker2D)      ← punto de apoyo (pies) = origen del jugador (0, 0)
└── DebugOverlay                ← F1: colisión, GroundPoint, centro y caja visual
```

`scenes/player/Player.tscn` con `character = BLUE_PENGUIN` **es** la escena del Pingüino Azul
(y con `PINK_PENGUIN` la del rosa): no hay `BluePenguin.tscn` aparte para no duplicar lógica.

- **Escala única**: `PlayerConfig.visual_height` (PLAYER_HEIGHT, 74 px: el idle mide eso en
  pantalla) y `PlayerConfig.visual_scale` (PLAYER_VISUAL_SCALE, 1.0). `VisualRoot.scale =
  visual_height / reference_height × visual_scale`, calculado una vez; ninguna animación la cambia.
  Así el azul (arte nuevo) y el rosa (arte anterior) se ven del mismo tamaño.
- **Pies estables**: todos los fotogramas de un personaje comparten lienzo, con los pies en el borde
  inferior y el centro del cuerpo en el centro horizontal; `offset = (0, -alto/2)` pone el origen
  del sprite en el GroundPoint en todas las animaciones.
- **Colisión**: cápsula de pie (`body_height` 60), agachado (`crouch_height` 38) y deslizándose
  (`slide_height` 32), elegidas por los estados `Crouch`/`Slide`. El tamaño del dibujo no influye.
- **flip_h** para mirar a la izquierda: como el lienzo está centrado en el cuerpo, los pies y la
  colisión no se mueven.
- Efectos pasajeros (estirar/aplastar al saltar y aterrizar, destello, parpadeo) actúan sobre el
  `Animator` y vuelven solos a su valor normal; no cambian la escala global.
- La cámara sigue al `CharacterBody2D`, no al sprite.

#### Pingüino azul (`assets/characters/blue_penguin/`)

Fuente: `assets/references/characters/blue_penguin_full_animations.png` (diseño con casco de
aviador y gafas). Lienzo común 154×111, altura de referencia 98 px.

| Animación (estándar) | Nombre en la especificación | Fotogramas | Nota |
|---|---|---|---|
| `idle` | blue_penguin_idle | 2 (1-2-1-2) | Las poses 3–4 de la hoja giran el cuerpo; quedan en `processed/` |
| `walk` | blue_penguin_walk | 3 (1-2-3-2) | |
| `run` | blue_penguin_run | 4 | Sin polvo |
| `jump` | blue_penguin_jump | 3 | |
| `fall` | blue_penguin_fall | 1 | La 2.ª pose de la hoja es de espaldas |
| `land` | blue_penguin_land | 3 | |
| `crouch` | blue_penguin_crouch | 2 | |
| `slide` | blue_penguin_slide | 3 | Sin nieve |
| `climb` | blue_penguin_ladder | 4 | Sin la escalera dibujada (la pone el nivel) |
| `lift` | blue_penguin_pickup | 2 | Sin barril |
| `carry` | blue_penguin_carry | 2 | Sin barril |
| `throw` | blue_penguin_throw | 2 | Sin barril |
| `place_bomb` | blue_penguin_place_bomb | 3 | Sin bomba |
| `hurt` | blue_penguin_hurt | 4 | Sin estrellas |
| `death` | blue_penguin_death | 3 | Tumbado |
| `victory` | blue_penguin_victory | 4 | |
| `attack` | blue_penguin_attack | 4 | Sin el destello del golpe |
| `fire_attack` | blue_penguin_fire_attack | 1 | Sin la llama (será un proyectil/efecto aparte) |
| `swim` | blue_penguin_swim | — | **No extraída**: el agua está fundida con el dibujo. Respaldo: `fall` |

Los objetos (barril, bomba, escalera) y efectos se borran del fotograma porque en el juego son
nodos independientes: el objeto llevado se dibuja delante del pingüino, en su propia escena. Donde
el objeto tapaba el cuerpo, el hueco se rellena por inpainting; lo cubre el objeto llevado.
No se extraen (motivo en el `manifest.json`): nadar, 2.º fotograma del ataque de fuego, espera de
bomba, reacción a explosión y especiales/poderes (auras fundidas con el cuerpo).

Carpetas: `source/` = recortes originales de cada celda, sin tocar (Godot los ignora);
`processed/` = fotogramas normalizados que usa el juego; `legacy/` = fotogramas del diseño anterior
(archivados, Godot los ignora); `manifest.json` = animaciones, lienzo, altura de referencia y caja
visible de cada fotograma.

#### Pingüino rosa (`assets/characters/pink_penguin/`)

Sigue con el diseño anterior (`penguins_blue_pink_animations.png`, lienzo 108×82, 9 animaciones:
`idle, walk, run, jump, fall, land, crouch, slide, climb`; el resto usa respaldos). Ya cumple las
mismas reglas (lienzo común, pies en la base) y se muestra a la misma altura que el azul. Cuando
haya una hoja completa del rosa con el mismo formato, basta con añadir su perfil a
`extract_character_sheet.py`.

#### Regenerar

```bash
# Azul (hoja completa con transparencia): numpy, opencv-python-headless, pillow
python3 tools/sprites/extract_character_sheet.py blue_penguin
# Rosa (hoja anterior, segmentación con rembg)
python3 tools/sprites/extract_penguin.py pink
godot --headless --path . --import
godot --headless --path . -s tools/build_sprite_frames.gd   # comprueba que el lienzo sea común
```

#### Validación visual

`scenes/player/BluePenguinAnimationTest.tscn` (solo pruebas): suelo, pingüino, nombre de la
animación y datos de escala/colisión/GroundPoint. Teclas: 1 idle · 2 caminar · 3 correr · 4 saltar
· 5 caída · 6 aterrizaje · 7 agacharse · 8 deslizarse · 9 recoger · 0 lanzar · ←/→ anterior/siguiente
· F voltear · Espacio pausa · `,` `.` fotograma a fotograma · F1 depuración · Esc salir.
Las pruebas automáticas (`tests/sprite_normalization_test.gd`) comprueban lienzo común, pies en la
línea base, escala/offset/colisión/posición constantes al cambiar de animación y flip_h.

## Bombas arcade (Fase 3)

Controles iguales que antes (Bomba lanza, abajo + Bomba coloca, Interactuar recoge/lanza, abajo +
Interactuar suelta, Cambiar bomba cambia de tipo). Cambios del formato arcade:

- **Física controlada** (`CarryableBody`, parámetros en `BombData`): gravedad fija, `max_bounces`
  botes con `bounce` fijo, `ground_friction` al rodar, `wall_bounce` en paredes. Siempre igual.
- **Colocar y lanzar**: la bomba colocada se queda quieta donde se puso (pasar por encima no la
  mueve: las patadas están desactivadas, `kick_enabled`). Lanzada de pie cae a ~70–100 px y se
  queda; lanzada saltando, solo un poco más lejos (`throw_force` (260, −300), `throw_inherit` 0,25).
- **Tipos** (`data/bombs/`):

  | Tipo | Daño | Radio base | Mecha |
  |---|---|---|---|
  | Negra (normal) | 2 | 80 | 2,4 s |
  | Azul (pequeña) | 1 | 60 | 1,8 s |
  | Verde (grande) | 3 | 104 | 2,8 s |

- **Área visible**: al explotar se dibuja el círculo del alcance real (color del tipo) y la animación de
  la explosión escalada a ese radio.
- **BOMB LEVEL 1–4**: el alcance se multiplica por ×1 / ×1,35 / ×1,7 / ×2 (`bomb_power_radius`). El
  nivel 4 es el **poder especial**: anillo dorado, daño y poder de destrucción extra
  (`special_damage_bonus`, `special_break_bonus`). Sube con el power-up de fuego y se pierde al morir.
- **Fuego amigo**: afecta a todos (`hurts_players`), también a quien la puso.
- Lo alcanzado reacciona con `apply_explosion(info: ExplosionInfo)` o `take_damage()`.

## Barriles, destrucción y power-ups (Fase 4)

| Objeto | Cómo se usa | Se rompe con | Botín |
|---|---|---|---|
| Barril (`Barrel.tscn`) | Interactuar para recoger, lanzar rasante: rueda y golpea (daño 2) | Explosiones, golpear a un enemigo, estrellarse fuerte contra una pared | `barrel_drops` (90 %) |
| Caja (`Destructible`, `crate`) | Obstáculo sólido | Cualquier explosión | `crate_drops` (60 %, frutas) |
| Bloque de piedra (`stone_block`) | Obstáculo sólido, dureza 2 | Solo BOMB LEVEL 4 | — |

Power-ups (`data/powerups/`): cereza 100, banana 200, naranja 300, manzana 500, uva 800, sandía
1000, piña 1500, melón 2000 (puntos) · pastel y 1UP (+1 vida) · armadura (absorbe un golpe, aura
visible) · botas (×1,4 de velocidad 10 s) · fuego (+1 nivel de bomba). Aparecen, caen al suelo y
parpadean antes de desaparecer (10 s).

## Enemigos (Fase 5)

Ver `docs/ENEMIES.md`: cangrejo, ermitaño, gaviota y pulpo, con oleadas por pantalla. Tocar a un
enemigo o recibir su ataque quita vida; bombas y barriles lanzados los derrotan (con combos).

<details><summary>Sistema de bombas de la etapa 1 (referencia)</summary>

### Bombas (etapa 1)

| Acción | Cómo |
|---|---|
| Lanzar una bomba nueva | Bomba (Q / Ctrl der. / B) |
| Lanzamiento alto | Arriba + Bomba |
| Colocarla delante de los pies | Abajo + Bomba (en el suelo) |
| Recoger una bomba libre (propia o del compañero) | Interactuar (E / Shift der. / X) cerca de ella |
| Lanzar la que lleva | Interactuar o Bomba |
| Soltarla suavemente | Abajo + Interactuar (o Abajo + Bomba) |
| Patear | Caminar contra una bomba libre en el suelo |
| Cambiar de tipo | Cambiar bomba (R / Enter / Y); salta los tipos sin munición |

- Se pueden usar en `Idle`, `Move`, `Jump`, `Fall`, `Land` y `Crouch` (no escalando, deslizándose,
  herido ni muerto). Al recibir daño, subir a una escalera o morir se suelta la bomba.
- Llevar una bomba reduce la velocidad (`carry_speed_multiplier`) y muestra `carry`; la bomba va
  en las manos (`bomb_hold_offset`) y su mecha sigue ardiendo: si explota en las manos se pierde.
- **Llevar con estilo propio**: cada `CarryableBody` tiene `carry_style` (el barril usa `barrel`).
  Si el personaje tiene animaciones `carry_<estilo>_<anim>` (`idle, walk, run, jump, land, crouch,
  lift, throw, drop`), `PlayerAnimator` las usa (con respaldo a `walk`/`idle` si falta alguna) y
  el objeto oculta su sprite (`set_art_visible(false)`) porque ya va dibujado en el fotograma; al
  lanzarlo o soltarlo vuelve a verse en el mismo fotograma: `carry_barrel_throw`/`drop` solo usan
  poses con las manos ya vacías, para que no se vean dos barriles. Sin esas animaciones se usa `carry` con el objeto visible.
- Límite de bombas propias en juego: `max_active_bombs` (3). Munición por tipo: `BombData.ammo`
  (-1 = infinita).

### Tipos (`data/bombs/`)

| Tipo | Daño | Radio | Mecha | Empuje | Peso | Rebote |
|---|---|---|---|---|---|---|
| Azul | 1 | 72 | 2,2 s | 380 | 0,9 | 0,40 |
| Verde | 2 | 112 | 2,5 s | 460 | 1,0 | 0,35 |
| Negra | 3 | 152 | 2,8 s | 560 | 1,4 | 0,25 |

Un tipo nuevo es un `.tres` de `BombData` más (añádelo a `BOMBS` en `tools/setup_project.gd` para
que se genere y entre en `PlayerConfig.bomb_types`). La lógica es la misma escena `Bomb`.

### Arquitectura

```
PlayerBombs (en Player) ── pide ──> BombPool (uno por nivel, grupo "bomb_pool")
                                      ├── Bomb × N  (RigidBody2D, capa 4)
                                      └── Explosion × M
Bomb: POOLED -> ARMED (mecha) <-> HELD (en las manos) -> explota -> POOLED
Explosion.apply_to_area(): círculo de radio `explosion_radius` sobre capas 2–5
   ├── apply_explosion(center, data, owner, source)  → Player: empuje · Bomb: cadena
   ├── take_damage(damage, source)                   → enemigos / objetos / TestTarget
   └── RigidBody2D                                   → impulso hacia fuera
```

- Las bombas chocan con el mundo, las plataformas atravesables y otras bombas, pero no con los
  jugadores (se atraviesan; la patada la detecta el `KickArea` de la bomba).
- Enemigos, jefes y objetos de fases futuras solo tienen que implementar `take_damage()` o
  `apply_explosion()` para reaccionar a las bombas.
- La explosión avisa por `EventBus.bomb_exploded` (la cámara tiembla) y el cambio de tipo por
  `EventBus.bomb_type_changed` (para el HUD de la Fase 6).
- Sprites: `assets/bombs/` (esfera normalizada a 48 px en un lienzo de 96 px; la escena la escala a
  `body_radius`) y `assets/effects/explosion/` (5 fases), extraídos con
  `python3 tools/sprites/extract_bombs.py` de la hoja general. La bomba «normal» también se extrajo
  para un futuro tipo.


</details>

## Vida y daño (Fase 2+)

HP por vida, invulnerabilidad temporal, empuje (knockback), muerte, reaparición, vidas y
checkpoints. Fuentes de daño: enemigos, explosiones, entorno y caída al vacío.
Implementado de forma reutilizable en `HealthComponent`.

## Objetos (Fase 5)

Barriles, cajas, plataformas móviles, objetos destruibles, interruptores, puertas y escaleras.
Los barriles se pueden recoger, transportar, lanzar y soltar para atacar enemigos o activar
elementos del escenario.

## Power-ups (Fases 5+)

Frutas (puntos), armadura (resistencia), velocidad (temporal), fuego (ataque).
Arquitectura preparada para elementos: fuego, hielo, electricidad, viento, oscuridad,
fuerza, velocidad e invulnerabilidad, con nombres y diseños originales.

## HUD (Fase 6)

Por jugador: vida, vidas, puntuación, bomba equipada y cantidad, poder activo.
General: mundo, nivel, tiempo y botón de pausa. Adaptado a móvil.

## Cámara

`ArcadeCamera` (`scripts/arena/arcade_camera.gd`): **fija**, encuadra la arena completa (960×720) y
solo tiembla un poco con las explosiones. No sigue a nadie. `CoopCamera` queda solo para el
laboratorio de movimiento (legado).

## Plataformas giratorias

| Acción | Control |
|---|---|
| Subir al piso de arriba | Estar sobre la plataforma y pulsar **Arriba** |
| Bajar al piso de abajo | Estar sobre la plataforma quieto y pulsar **Abajo** |

- Los dos jugadores pueden ir encima y salen juntos. Las bombas y barriles en reposo encima salen
  despedidos. Los enemigos no la activan.
- Gira ~0,4 s (con un temblor previo de 0,15 s) y espera 0,6 s antes de poder usarse otra vez.
- Las que están en el suelo solo suben. Ajustes en `data/platforms/rotating_platform.tres`; la
  altura de lanzamiento de cada una se elige en `tools/build_arenas.gd` (`rotators`).
