extends Node
## Estado global de la partida: modo de juego (1 o 2 jugadores), mundo/fase actual, vidas,
## continues y pausa. La puntuación vive en ScoreManager y el flujo de pantallas en
## StageManager. No contiene lógica de nivel.

enum GameMode { SOLO, COOP }

const MAX_PLAYERS := 2
const STARTING_LIVES := 3
## Continues por partida (-1 = ilimitados, como con créditos infinitos).
const MAX_CONTINUES := -1
const MAIN_SCENE := "res://scenes/main/Main.tscn"
const WORLD_DATA_PATH := "res://data/worlds/world_%02d.tres"
const WORLD_COUNT := 10

var game_mode: GameMode = GameMode.SOLO
var current_world := 1
var current_level := 1
var lives: Array[int] = [STARTING_LIVES, STARTING_LIVES]
var eliminated: Array[bool] = [false, false]
var is_paused := false
var continues_used := 0


func start_new_game(mode: GameMode, world := 1, level := 1) -> void:
	game_mode = mode
	current_world = world
	current_level = level
	continues_used = 0
	ScoreManager.reset()
	_reset_lives()
	InputManager.set_coop(mode == GameMode.COOP)


## CONTINUE tras GAME OVER: vidas completas y puntuación a cero (estilo arcade).
func continue_game() -> bool:
	if MAX_CONTINUES >= 0 and continues_used >= MAX_CONTINUES:
		return false
	continues_used += 1
	ScoreManager.reset()
	_reset_lives()
	return true


func can_continue() -> bool:
	return MAX_CONTINUES < 0 or continues_used < MAX_CONTINUES


func _reset_lives() -> void:
	for i in MAX_PLAYERS:
		lives[i] = STARTING_LIVES
		eliminated[i] = false
		EventBus.lives_changed.emit(i, lives[i])


func player_count() -> int:
	return 2 if game_mode == GameMode.COOP else 1


func is_coop() -> bool:
	return game_mode == GameMode.COOP


## Atajo de compatibilidad: la puntuación la gestiona ScoreManager.
func add_score(player_index: int, amount: int) -> void:
	ScoreManager.add_points(player_index, amount)


func total_score() -> int:
	return ScoreManager.total()


func change_lives(player_index: int, delta: int) -> int:
	if not _valid_player(player_index):
		return 0
	lives[player_index] = maxi(0, lives[player_index] + delta)
	EventBus.lives_changed.emit(player_index, lives[player_index])
	return lives[player_index]


## ¿El jugador participa en la partida y aún tiene vidas?
func is_player_active(player_index: int) -> bool:
	return _valid_player(player_index) and player_index < player_count() and not eliminated[player_index]


## Un jugador se quedó sin vidas. La partida termina cuando no queda ninguno activo.
func eliminate_player(player_index: int) -> void:
	if not _valid_player(player_index) or eliminated[player_index]:
		return
	eliminated[player_index] = true
	EventBus.player_eliminated.emit(player_index)
	for i in player_count():
		if not eliminated[i]:
			return
	EventBus.game_over.emit()


func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	get_tree().paused = paused
	EventBus.pause_changed.emit(paused)


func get_world_data(world_number: int) -> WorldData:
	var path := WORLD_DATA_PATH % world_number
	if not ResourceLoader.exists(path):
		return null
	return load(path) as WorldData


func request_scene(scene_path: String, transition: StringName = &"fade") -> void:
	EventBus.scene_change_requested.emit(scene_path, transition)


func _valid_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < MAX_PLAYERS
