# Enemigos y jefes

## Arquitectura de IA

Todos los enemigos usan la `StateMachine` genérica con estados reutilizables:

`IDLE` · `PATROL` · `CHASE` · `ATTACK` · `HURT` · `DEAD`

Cada enemigo usa solo los estados que necesita. Sus números viven en un `EnemyData`
(`data/enemies/`), así ajustar dificultad no requiere tocar código. Cada enemigo tiene
su propia escena en `scenes/enemies/world_XX/`.

Campos de `EnemyData`: `health`, `speed`, `damage`, `attack_range`, `detection_range`,
`attack_cooldown`, `score`, `behavior` (WALKER, SHELL, FLYER, SWIMMER, HOPPER, TURRET),
`flying`, `sprite_frames`, `drops`.

## Mundo 1 – Isla Palmera (Fase 8)

| Enemigo | Escena | Comportamiento | Estados | Referencia |
|---|---|---|---|---|
| Cangrejo pequeño | `small_crab.tscn` | Camina, gira al detectar pared o borde, ataca con pinza | PATROL, ATTACK, HURT, DEAD | `world_01_small_crab.png` |
| Gaviota | `seagull.tscn` | Vuela en línea horizontal y se lanza en picado | PATROL, ATTACK (picado), HURT, DEAD | `world_01_seagull.png` |
| Cangrejo ermitaño | `hermit_crab.tscn` | Camina, se protege en el caparazón al recibir golpe, ataca con pinza | PATROL, ATTACK, HURT (caparazón), DEAD | `world_01_hermit_crab.png` |
| Pulpo pequeño | `small_octopus.tscn` | Nada de forma ondulante y lanza tinta a distancia | PATROL, ATTACK (tinta), HURT, DEAD | `world_01_small_octopus.png` |

Las referencias están en `assets/references/enemies/` e incluyen, para cada enemigo,
idle, movimiento, ataque, daño, muerte y partículas.

## Jefes

Arquitectura común (`BossData` extiende `EnemyData`): barra de vida, fases por porcentaje de
vida (`phase_thresholds`), velocidad por fase, animaciones, ataques, daño, muerte y recompensa.

### Orca Ninja (Mundo 1, Fase 9)

| Fase | Vida | Comportamiento |
|---|---|---|
| 1 | 100–66 % | Movimiento y embestida |
| 2 | 66–33 % | Ataque especial (onda de agua) y cambio de patrón |
| 3 | 33–0 % | Mayor velocidad y ataque combinado |

La primera implementación será deliberadamente simple.
Referencia: `assets/references/bosses/worlds_01_to_06_bosses.png`.

### Jefes restantes

| Mundo | Jefe |
|---|---|
| 2 | Águila Real |
| 3 | Leopardo de las Nieves |
| 4 | Tiburón blanco |
| 5 | Oso polar |
| 6 | Pingüino robótico |
| 7 | Tigre de Amur |
| 8 | Dragón de fuego |
| 9 | Mega dron |
| 10 | Dragón celestial |
