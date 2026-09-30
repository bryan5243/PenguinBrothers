# Enemigos y jefes

## Arquitectura (Fase 5 arcade · implementado)

Diseñados para **pantalla fija**: patrullan su piso, usan las plataformas para cambiar de piso
y van a por el jugador más cercano. Nada de IA de scroll.

```
Enemy.tscn (una escena para todos)          scripts/enemies/enemy.gd
├── CollisionShape2D  cuerpo (EnemyData.body_size), capa 3, choca con mundo y plataformas
├── VisualRoot/Animator  SpriteFrames del enemigo, escala = visual_height / altura de referencia
├── Hitbox (Area2D)   daño por contacto a los jugadores
├── Health            HealthComponent
└── StateMachine      Idle · Patrol · Chase · Attack · Hurt · Dead · Special
                      (scripts/enemies/states/, genéricos)
Comportamiento (EnemyBehavior, scripts/enemies/behaviors/) elegido por EnemyData.behavior:
  WALKER  WalkerBehavior  · SHELL ShellBehavior · FLYER FlyerBehavior · SWIMMER ShooterBehavior
```

- Los estados son comunes; cada comportamiento responde a `patrol`, `chase`, `can_attack`,
  `start_attack`/`attack`, `wants_special`/`special`, `modify_damage` y `deals_contact_damage`.
- **Daño recibido**: bombas (`apply_explosion`, con empuje) y barriles lanzados (`take_damage`).
  Invulnerabilidad breve entre golpes. Al morir: puntos con **combo** para quien lo derrotó
  (`ScoreManager.register_kill`), botín (`drop_table`), `EventBus.enemy_defeated` y `defeated`.
- **Daño hecho**: por contacto (Hitbox) y con su ataque. Al aparecer parpadea 0,6 s sin hacer daño.
- Un enemigo nuevo = un `EnemyData` (`.tres`) más, generado en `tools/setup_project.gd` (`ENEMIES`).

### EnemySpawner (`scripts/enemies/enemy_spawner.gd`)

Nodos del grupo «Spawners» de cada Arena. Configurables: `enemy_type` (EnemyData), `entry`
(POINT, LEFT, RIGHT, TOP), `spawn_delay`, `interval`, `count`, `max_enemies` (vivos a la vez) y
`wave`. El `EnemyManager` reserva todos los enemigos al empezar (la pantalla no se «limpia» antes
de tiempo), activa la oleada más baja y pasa a la siguiente cuando la actual ya soltó a todos y no
queda ninguno vivo. Sin enemigos ni oleadas pendientes: `cleared` (→ llave en la Fase 7).

## Mundo 1 – Isla Palmera

| Enemigo | Datos | Comportamiento | Vida · daño · puntos |
|---|---|---|---|
| Cangrejo pequeño | `small_crab.tres` (WALKER) | Patrulla su plataforma y da la vuelta en bordes y paredes; persigue corriendo; baja de las plataformas atravesables y **salta al piso de arriba**; pinza a corta distancia | 1 · 1 · 100 |
| Cangrejo ermitaño | `hermit_crab.tres` (SHELL) | Como el cangrejo (sin saltar), pero se **esconde en el caparazón** si hay una bomba encendida cerca o tras un golpe: escondido no daña por contacto y absorbe 1 de daño (la bomba azul no le hace nada) | 2 · 1 · 200 |
| Gaviota | `seagull.tres` (FLYER) | Vuela de pared a pared a su altura con vaivén; con un jugador debajo **cae en picado** hacia él y vuelve a subir | 1 · 1 · 150 |
| Pulpo pequeño | `small_octopus.tres` (SWIMMER) | Avanza despacio y guarda distancia; con un jugador en su piso se gira y **lanza tinta** en línea recta (`InkProjectile`, choca con paredes y rocas) | 1 · 1 · 150 |

Sprites extraídos con `python3 tools/sprites/extract_enemies.py` de `assets/references/enemies/`
(lienzo común por enemigo, base en el borde inferior; la gaviota, centrada) a
`assets/enemies/<id>/processed/` → `tools/build_sprite_frames.gd` → `<id>_frames.tres`.
Animaciones: `idle, walk, run, attack, hurt, death` (+ `special` = caparazón del ermitaño).

Pantallas de la 1-1: **A** — oleada 1: cangrejo por la izquierda y por la derecha (2 cada uno, de
uno en uno) y una gaviota; oleada 2: ermitaño desde arriba y pulpo en la plataforma derecha.
**B** — cangrejos desde arriba, gaviota y pulpo.

## Jefes

Arquitectura común (`BossData` extiende `EnemyData`): barra de vida, fases por porcentaje de
vida (`phase_thresholds`), velocidad por fase, animaciones, ataques, daño, muerte y recompensa.

### Orca Ninja (Mundo 1, fase arcade 12)

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
