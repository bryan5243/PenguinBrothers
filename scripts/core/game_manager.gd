extends Node
## Estado global de la partida: modo de juego, mundo/nivel actual, puntuaciones y vidas.
## No contiene lógica de nivel; los niveles leen y actualizan este estado.

enum GameMode { SOLO, COOP }

const MAX_PLAYERS := 2
const STARTING_LIVES := 3
const MAIN_SCENE := "res://scenes/main/Main.tscn"
const WORLD_DATA_PATH := "res://data/worlds/world_%02d.tres"
const WORLD_COUNT := 10

var game_mode: GameMode = GameMode.SOLO
var current_world := 1
var current_level := 1
var scores: Array[int] = [0, 0]
var lives: Array[int] = [STARTING_LIVES, STARTING_LIVES]
var is_paused := false


func start_new_game(mode: GameMode, world := 1, level := 1) -> void:
	game_mode = mode
	current_world = world
	current_level = level
	for i in MAX_PLAYERS:
		scores[i] = 0
		lives[i] = STARTING_LIVES
		EventBus.score_changed.emit(i, 0)
		EventBus.lives_changed.emit(i, lives[i])
	InputManager.set_coop(mode == GameMode.COOP)


func player_count() -> int:
	return 2 if game_mode == GameMode.COOP else 1


func is_coop() -> bool:
	return game_mode == GameMode.COOP


func add_score(player_index: int, amount: int) -> void:
	if not _valid_player(player_index):
		return
	scores[player_index] += amount
	EventBus.score_changed.emit(player_index, scores[player_index])


func total_score() -> int:
	var total := 0
	for s in scores:
		total += s
	return total


func change_lives(player_index: int, delta: int) -> int:
	if not _valid_player(player_index):
		return 0
	lives[player_index] = maxi(0, lives[player_index] + delta)
	EventBus.lives_changed.emit(player_index, lives[player_index])
	return lives[player_index]


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


func request_scene(scene_path: String) -> void:
	EventBus.scene_change_requested.emit(scene_path)


func _valid_player(player_index: int) -> bool:
	return player_index >= 0 and player_index < MAX_PLAYERS
