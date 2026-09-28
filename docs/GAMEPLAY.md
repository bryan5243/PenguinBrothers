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

## Movimiento del jugador (Fase 2 · implementado)

Parámetros en `PlayerConfig` (`data/player/default_player_config.tres` usa los valores por defecto):

| Parámetro | Valor | Descripción |
|---|---|---|
| `move_speed` / `run_speed` | 240 / 340 | Caminar; correr tras `run_delay` (0,55 s) de movimiento continuo |
| `acceleration` / `air_acceleration` | 2200 / 1400 | Aceleración en suelo / aire |
| `friction` / `air_friction` | 2600 / 600 | Frenado en suelo / aire (girar usa el mayor valor: giros ágiles) |
| `jump_force` / `gravity` / `max_fall_speed` | 640 / 1750 / 950 | Salto completo ≈ 122 px |
| `jump_cut_speed` | 400 | Salto variable: al soltar pronto ≈ 42 px |
| `coyote_time` / `jump_buffer_time` | 0,10 / 0,12 s | Tolerancias de salto |
| `land_duration` / `land_min_fall_speed` | 0,08 s / 380 | Aterrizaje tras caída fuerte (no bloquea el control) |
| `slide_speed` / `slide_duration` / `slide_friction` | 520 / 0,5 s / 700 | Deslizamiento sobre el vientre |
| `slide_trigger_ratio` | 0,85 | Agacharse a ≥ 85 % de `run_speed` inicia el deslizamiento |
| `crawl_speed` | 110 | Gatear agachado bajo un techo bajo |
| `climb_speed` | 180 | Escaleras |
| `drop_through_time` | 0,25 s | Tiempo que se ignoran las plataformas al bajar |
| `body_radius` / `body_height` / `crouch_height` | 16 / 60 / 38 | Cápsula de colisión de pie y agachado |
| `max_health` / `invulnerability_time` | 3 / 1,6 s | Vida por vida; parpadeo tras recibir daño |
| `knockback` / `hurt_duration` | (300, −420) / 0,45 s | Empuje y tiempo sin control al recibir daño |
| `fall_death_y` / `respawn_delay` | 1400 / 1,5 s | Caída al vacío (el nivel puede cambiar la altura) y espera antes de reaparecer |

### Estados (`scripts/player/states/`)

```
Idle ⇄ Move ──(abajo corriendo)──> Slide ──> Crouch / Idle
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

### Nivel de prueba

`scenes/worlds/test_level/PlayerTestLevel.tscn` (pantalla de arranque: «Probar en solitario» o
«Probar cooperativo»). Incluye plataformas, escalón, escalera, túnel bajo, vacío y panel de
depuración (estado, vida, vidas y velocidad de cada jugador, zoom de cámara). Se genera con
`tools/build_player_test_level.gd`; su geometría usa placeholders de color hasta tener los
tiles del Mundo 1 (Fase 7).

## Cooperativo local (Fase 3 · implementado)

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
- **Los jugadores no chocan entre sí** de lado: pueden cruzarse libremente.
- **Vidas por jugador**: al morir, cada uno reaparece **junto a su compañero** si está vivo y en el
  suelo (si no, en el punto de inicio). Sin vidas queda **eliminado** (`EventBus.player_eliminated`);
  la partida termina (`EventBus.game_over`) solo cuando no queda ningún jugador activo.
- Preparado para después: revivir al compañero, compartir objetos, ataques combinados,
  puntuación individual y de equipo (`GameManager.scores` ya es por jugador).

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

`assets/characters/blue_penguin/` y `assets/characters/pink_penguin/` (extraídos de la hoja de
referencia con la misma herramienta; ambos tienen las mismas animaciones):

| Animación | Fotogramas | Nota |
|---|---|---|
| `idle` | 1 | |
| `walk` | 3 (ciclo 1-2-3-2) | |
| `run` | 2 | |
| `jump` | 2 | Subida y punto alto |
| `fall` | 1 | |
| `land` | 1 | |
| `crouch` | 1 | |
| `slide` | 2 | Lanzarse y deslizarse |
| `climb` | 4 | Vista de espalda; el 3 es el 1 reflejado (la celda original no se pudo recortar limpia) |
| `hurt`, `death`, `victory` | — | **No existen en la hoja.** Se usan respaldos (`fall`/`idle`) con efectos. Pendiente de arte |
| `lift`, `carry`, `throw`, `place_bomb` | — | Están en la hoja; se extraerán en las Fases 4–5 |

Los fotogramas de cada personaje comparten un lienzo (108×85 el azul, 108×82 el rosa) con los pies
en el borde inferior, para que la animación no "salte". El sprite se muestra al 90 %. En `slide`
queda una línea fina de nieve bajo el cuerpo: recortarla más dañaba el vientre blanco.

Para regenerarlos (requiere Python con `rembg`, `opencv-python-headless`, `pillow`):
```bash
python3 tools/sprites/extract_penguin.py blue   # o pink
godot --headless --path . --import
godot --headless --path . -s tools/build_sprite_frames.gd
```

## Bombas (Fase 4)

Clase base reutilizable + datos (`BombData`). Tipos iniciales:

| Tipo | Daño | Explosión |
|---|---|---|
| Azul | Bajo | Pequeña |
| Verde | Medio | Mayor |
| Negra | Alto | Grande |

Cada bomba define sprite, animación, mecha, radio, daño, empuje, efecto, sonido y partículas.
Tipos nuevos = nuevo `.tres`, sin duplicar código. Las bombas usarán pooling.

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

`CoopCamera` (Fase 3) ya sigue a los jugadores, respeta límites, suaviza y encuadra a ambos
en cooperativo. En la Fase 7 se ajustará a los niveles reales del Mundo 1 (límites por nivel,
zonas de cámara si hacen falta).
