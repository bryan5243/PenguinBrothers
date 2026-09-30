class_name Arena
extends Node2D
## Una pantalla arcade FIJA (unidad principal del juego): arena cerrada de 960x720 que se
## ve completa, sin cámara que siga a nadie ni desplazamiento.
##
## Estructura esperada (la genera tools/build_arenas.gd):
##   Arena
##   ├── Background / Geometry / Platforms / Ladders ...   (escenario)
##   ├── BombPool        (BombManager de la pantalla: bombas y explosiones reutilizables)
##   ├── Enemies         (EnemyManager: cuenta enemigos y oleadas; `cleared` -> llave en la A)
##   ├── Spawners        (EnemySpawner: tipo, entrada, retraso, cantidad, máximo, oleada)
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
## Dónde aparece la llave al limpiar la pantalla A (cae hasta el suelo o plataforma de debajo).
@export var key_position := Vector2(560, 130)
## Los pingüinos chocan entre sí: se bloquean y se empujan (pueden subirse encima).
@export var players_collide := true

var players: Array[Player] = []
var key: KeyItem = null
var _key_token := 0

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
	var list: Array[EnemySpawner] = []
	if has_node("Spawners"):
		for node in $Spawners.get_children():
			if node is EnemySpawner:
				list.append(node)
	enemies.register_spawners(list)
	StageManager.register_arena(self, time_limit)
	hud.refresh()
	if screen_role == "B":
		_restore_key.call_deferred()


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


## Pantalla limpia: bonificación a los jugadores activos. En la pantalla A aparece la llave.
func _on_enemies_cleared() -> void:
	for i in GameManager.player_count():
		if GameManager.is_player_active(i):
			ScoreManager.add_points(i, ScoreManager.table.screen_clear)
	if screen_role == "A":
		spawn_key()


## La llave de la fase aparece (una sola) en `key_position`.
func spawn_key() -> KeyItem:
	if key != null and is_instance_valid(key):
		return key
	var items: Node = get_node_or_null("Items")
	key = KeyItem.spawn(key_position, items if items else self)
	key.collected.connect(_on_key_collected)
	key.dropped.connect(func(_k: KeyItem) -> void: _key_token += 1)
	AudioManager.play_sfx("power_up")
	return key


## En la pantalla A, recoger la llave lleva a la B tras una pausa corta (si el portador
## muere antes de que acabe, la llave cae y no hay transición).
func _on_key_collected(_key: KeyItem, _player: Player) -> void:
	_key_token += 1
	var token := _key_token
	await get_tree().create_timer(key.data.pickup_to_transition).timeout
	if token == _key_token and is_inside_tree() and key != null and is_instance_valid(key) and key.is_carried():
		StageManager.next_screen()


## Pantalla B: la llave que se trajo de la A vuelve a su portador (o al primero vivo).
func _restore_key() -> void:
	if not StageManager.carry_over.get("key", false) or not is_inside_tree():
		return
	var owner_index: int = StageManager.carry_over.get("key_owner", -1)
	var target: Player = null
	for p in players:
		if p.is_alive() and (p.player_index == owner_index or target == null):
			target = p
			if p.player_index == owner_index:
				break
	if target == null:
		return
	var items: Node = get_node_or_null("Items")
	key = KeyItem.spawn(target.global_position + Vector2(0, -60), items if items else self)
	key.attach_to(target)
