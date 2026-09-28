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

- Mando 1 controla al Jugador 1 y mando 2 al Jugador 2.
- **Modo individual**: el Jugador 1 acepta también los controles del Jugador 2
  (flechas, segundo mando). Así se puede jugar solo con las flechas, como pide el diseño.
- **Pantalla táctil** (Fase 11): joystick virtual + botones Saltar, Bomba, Interactuar,
  Cambiar bomba y Pausa. Solo aparecen en dispositivos táctiles y se anclan a los bordes
  (sin posiciones absolutas). Inyectan comandos con `InputManager.press_command()`.

Acciones del Input Map: `p1_move_left`, `p1_move_right`, `p1_up`, `p1_crouch`, `p1_jump`,
`p1_interact`, `p1_bomb`, `p1_switch_bomb` (igual con `p2_`) y `pause`.

## Movimiento del jugador (Fase 2)

Parámetros en `data/player/default_player_config.tres` (`PlayerConfig`):

| Parámetro | Valor inicial | Descripción |
|---|---|---|
| `move_speed` | 240 | Velocidad caminando (px/s) |
| `run_speed` | 340 | Velocidad corriendo tras `run_delay` s |
| `acceleration` / `air_acceleration` | 2200 / 1400 | Aceleración en suelo / aire |
| `friction` / `air_friction` | 2600 / 600 | Frenado en suelo / aire |
| `jump_force` | 640 | Impulso de salto |
| `gravity` / `max_fall_speed` | 1750 / 950 | Gravedad y caída máxima |
| `jump_cut_speed` | 240 | Salto variable al soltar el botón |
| `coyote_time` / `jump_buffer_time` | 0.10 / 0.12 s | Tolerancias de salto |
| `slide_speed` / `slide_duration` | 520 / 0.5 s | Deslizamiento sobre el vientre |
| `climb_speed` | 180 | Escaleras |
| `max_health` / `invulnerability_time` | 3 / 1.6 s | Vida por vida y tiempo invulnerable tras daño |

Mecánicas previstas: aceleración y frenado, salto variable, coyote time, jump buffering,
agacharse, deslizarse corriendo + abajo, bajar de plataformas (abajo + saltar), escaleras,
recoger/transportar/lanzar/soltar barriles y bombas.

## Animaciones

Nombres estándar (una `SpriteFrames` por personaje; nunca una animación gigante compartida):

| Jugador | Enemigos y jefes |
|---|---|
| `idle`, `walk`, `run`, `jump`, `fall`, `land`, `crouch`, `slide`, `climb`, `lift`, `carry`, `throw`, `place_bomb`, `hurt`, `death`, `victory` | `idle`, `walk`, `run`, `attack`, `hurt`, `death`, `special` |

`PlayerAnimator` usa respaldos si falta una animación (por ejemplo `run` → `walk`), así un
personaje incompleto no rompe el juego. Poderes y transformaciones añadirán conjuntos de
`SpriteFrames` alternativos.

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

## Cámara (Fase 7)

`Camera2D` con seguimiento, límites del mapa, suavizado configurable y encuadre de ambos
jugadores en cooperativo cuando sea posible.
