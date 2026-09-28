class_name Arena
extends Node2D
## Una pantalla arcade FIJA (unidad principal del juego): arena cerrada de 960x720 que se
## ve completa, sin cámara que siga a nadie ni desplazamiento.
##
## Estructura esperada (la genera tools/build_arenas.gd):
##   Arena
##   ├── Background / Geometry / Platforms / Ladders ...   (escenario)
##   ├── BombPool        (BombManager de la pantalla: bombas y explosiones reutilizables)
##   ├── Enemies         (EnemyManager: cuenta enemigos; `cleared` -> llave en la pantalla A)
##   ├── Items           (llave, power-ups, barriles... Fases 4–7)
##   ├── PlayerSpawner   (PlayerManager: 1 o 2 pingüinos según el modo, marcadores P1/P2)
##   ├── ArcadeCamera    (fija)
##   └── HUD             (ArcadeHUD)
##
## Al entrar se registra en StageManager (empieza el tiempo). Pausa con Start/Esc (HUD).

## Papel de la pantalla dentro de la fase: A (enemigos -> llave) o B (puerta).
@export_enum("A", "B", "BOSS") var screen_role := "A"
@export var arena_size := Vector2(960, 720)
## Tiempo límite propio (-1 = el de StageData).
@export var time_limit := -1.0
## Los jugadores reaparecen en su marcador de inicio (arcade) en vez de junto al compañero.
@export var respawn_at_start := true
## Los pingüinos chocan entre sí: se bloquean y se empujan (pueden subirse encima).
@export var players_collide := true

var players: Array[Player] = []

@onready var spawner: PlayerSpawner = $PlayerSpawner
@onready var enemies: EnemyManager = $Enemies
@onready var bomb_pool: BombPool = $BombPool
@onready var camera: ArcadeCamera = $ArcadeCamera
@onready var hud: ArcadeHUD = $HUD


func _ready() -> void:
	players = spawner.players
	for p in players:
		p.fall_death_y = arena_size.y + 200.0
		p.respawn_near_partner = not respawn_at_start
		p.set_players_collide(players_collide)
	enemies.cleared.connect(_on_enemies_cleared)
	StageManager.register_arena(self, time_limit)
	hud.refresh()


func _exit_tree() -> void:
	StageManager.unregister_arena(self)


## La pausa la gestiona el HUD (sigue activo con el juego en pausa).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.DEBUG_OVERLAY_ACTION):
		PlayerDebugOverlay.toggle()
	elif OS.is_debug_build() and event.is_action_pressed(&"debug_next_screen"):
		# Solo desarrollo: pasa a la siguiente pantalla sin cumplir el objetivo.
		get_viewport().set_input_as_handled()
		StageManager.next_screen()


## Rectángulo jugable (dentro de las paredes).
func play_rect() -> Rect2:
	return Rect2(Vector2.ZERO, arena_size)


## Pantalla limpia: bonificación a los jugadores activos. En la Fase 7 la pantalla A hará
## aparecer aquí la llave (KeyItem).
func _on_enemies_cleared() -> void:
	for i in GameManager.player_count():
		if GameManager.is_player_active(i):
			ScoreManager.add_points(i, ScoreManager.table.screen_clear)
