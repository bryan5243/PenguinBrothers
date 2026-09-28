# Guía para agentes de IA (Codex, Claude, etc.)

Lee esto antes de modificar el proyecto.

## Reglas principales

- Motor: **Godot 4.7**, lenguaje **GDScript**. Juego **2D side-scrolling** (nunca 3D). Sin pixel art salvo que se pida.
- Trabaja **por fases** (ver `docs/ROADMAP.md`). No avances a la siguiente fase sin explicar el resultado de la actual.
- Rama de trabajo: `develop` (o una rama por funcionalidad). No hagas commits directos a `main`.
- Commits pequeños y claros: `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`, `test: ...`.
- No elimines trabajo existente para simplificar. No reemplaces el proyecto por una implementación nueva.
- No escribas código ficticio que no funcione. Si algo falta, dilo explícitamente.

## Antes de terminar una tarea

1. `godot --headless --path . --import` sin errores.
2. `godot --headless --path . res://tests/SmokeTest.tscn` termina con código 0.
3. Revisa rutas, nodos, señales y escenas afectadas.
4. Actualiza la documentación de `docs/` si cambió el diseño.

## Arquitectura (resumen)

- **Autoloads** (`scripts/core/`): `EventBus` (señales globales), `SaveManager` (JSON),
  `AudioManager` (música/efectos por clave), `InputManager` (abstracción de controles),
  `GameManager` (modo, mundo, puntuación, vidas). Orden definido en `tools/setup_project.gd`.
- **Entrada**: el gameplay nunca lee teclas. Usa `PlayerInput` / `InputManager` con comandos
  (`move_left`, `move_right`, `up`, `crouch`, `jump`, `interact`, `bomb`, `switch_bomb`).
  Las acciones del Input Map son `p1_<comando>` y `p2_<comando>`, más `pause`.
- **Datos**: clases `Resource` en `scripts/core/data/` (`PlayerConfig`, `BombData`, `EnemyData`,
  `BossData`, `PowerUpData`, `WorldData`). El contenido nuevo es un `.tres` en `data/`.
- **Estados**: `StateMachine` + `State` genéricos (`scripts/utilities/`) para jugador, enemigos y jefes.
  El jugador llama a `state_machine.physics_update()` él mismo (`auto_process = false`) para
  garantizar el orden entrada → estado → `move_and_slide()`. Estados en `scripts/player/states/`.
- **Vida**: `HealthComponent` reutilizable.
- **Animación**: separada de la lógica (`PlayerAnimator`). Nombres estándar: `idle, walk, run, jump,
  fall, land, crouch, slide, climb, lift, carry, throw, place_bomb, hurt, death, victory`
  (enemigos: `idle, walk, attack, hurt, death, special`).
- No pongas valores de ajuste sueltos en el código: van en un Resource de datos.
- El Input Map y los ajustes del proyecto se editan en `tools/setup_project.gd` y se regeneran.

## Sprites y assets

1. Busca primero en `assets/` y en `assets/references/` (ver su `README.md`).
2. Usa los sprites existentes; no los reemplaces ni crees duplicados.
3. `assets/references/` contiene hojas de diseño completas (Godot las ignora con `.gdignore`).
   Para usarlas en el juego, extrae los fotogramas a `assets/characters/`, `assets/enemies/`, etc.
4. Crea placeholders solo si son indispensables para probar una mecánica, y que sean fáciles de reemplazar.
   Extracción de sprites: `tools/sprites/extract_penguin.py` (Python + rembg) → `--import` →
   `tools/build_sprite_frames.gd`. No edites a mano los PNG de `frames/`: regenera.
5. Los poderes inspirados en anime usan nombres, diseños y efectos **originales**.
