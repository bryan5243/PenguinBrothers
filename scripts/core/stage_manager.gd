extends Node
## Flujo arcade de una fase: pantallas fijas encadenadas (A -> B), tiempo límite,
## bonificaciones, pantalla perdida por tiempo, GAME OVER / CONTINUE y fase completada.
##
##   start_stage()   -> carga la pantalla 0 (A)
##   next_screen()   -> transición a la siguiente pantalla (B) o completa la fase
##   complete_stage()-> bonificación + pantalla de victoria
##   fail_screen()   -> tiempo agotado: todos pierden una vida y se repite la pantalla
##   restart_screen()/restart_stage()
##
## Cada pantalla es una escena Arena; al entrar al árbol se registra con register_arena()
## y entonces empieza a correr el tiempo.

const TITLE_SCREEN := "res://scenes/ui/TitleScreen.tscn"
const GAME_OVER_SCREEN := "res://scenes/ui/GameOverScreen.tscn"
const VICTORY_SCREEN := "res://scenes/ui/VictoryScreen.tscn"
const FIRST_STAGE := "res://data/stages/world_01_stage_01.tres"

enum Phase { IDLE, PLAYING, TRANSITION, CLEARED, GAME_OVER }

var stage: StageData
var screen_index := 0
var time_left := 0.0
var phase := Phase.IDLE
var arena: Node = null
## Datos que pasan de una pantalla a la siguiente (p. ej. quién lleva la llave, Fase 7).
var carry_over := {}

var _last_second := -1
var _warned := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.game_over.connect(_on_game_over)


func start_new_game(mode: GameManager.GameMode, stage_path := FIRST_STAGE) -> void:
	GameManager.start_new_game(mode)
	start_stage(load(stage_path) as StageData)


func start_stage(data: StageData) -> void:
	if data == null or data.screen_count() == 0:
		push_error("StageManager: fase sin pantallas")
		return
	stage = data
	screen_index = 0
	carry_over.clear()
	GameManager.current_world = data.world
	GameManager.current_level = data.stage
	EventBus.stage_started.emit(data.id)
	_load_screen(&"fade")


func next_screen() -> void:
	if stage == null or phase == Phase.TRANSITION:
		return
	EventBus.screen_completed.emit(screen_index)
	_award_time_bonus()
	if screen_index + 1 < stage.screen_count():
		screen_index += 1
		_load_screen(&"wipe")
	else:
		complete_stage()


func complete_stage() -> void:
	phase = Phase.CLEARED
	for i in GameManager.player_count():
		if GameManager.is_player_active(i):
			ScoreManager.add_points(i, ScoreManager.table.stage_clear)
	EventBus.stage_completed.emit(stage.id if stage else &"")
	GameManager.request_scene(VICTORY_SCREEN, &"flash")


## Tiempo agotado: cada jugador activo pierde una vida y la pantalla empieza de nuevo.
func fail_screen() -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.TRANSITION
	EventBus.time_up.emit()
	var anyone_left := false
	for i in GameManager.player_count():
		if not GameManager.is_player_active(i):
			continue
		if GameManager.change_lives(i, -1) > 0:
			anyone_left = true
		else:
			GameManager.eliminate_player(i)
	if anyone_left:
		restart_screen()


func restart_screen() -> void:
	if stage:
		_load_screen(&"fade")


func restart_stage() -> void:
	if stage:
		start_stage(stage)


## CONTINUE desde GAME OVER: vuelve a la pantalla donde se perdió.
func continue_game() -> bool:
	if not GameManager.continue_game():
		return false
	restart_screen()
	return true


func go_to_title() -> void:
	phase = Phase.IDLE
	stage = null
	arena = null
	GameManager.request_scene(TITLE_SCREEN, &"fade")


## La Arena de la pantalla actual avisa de que está lista: empieza el tiempo.
func register_arena(new_arena: Node, time_override := -1.0) -> void:
	arena = new_arena
	var limit := time_override
	if limit <= 0.0:
		limit = stage.time_limit_for(screen_index) if stage else 99.0
	time_left = limit
	_last_second = -1
	_warned = false
	phase = Phase.PLAYING
	EventBus.screen_started.emit(screen_index, stage.screen_count() if stage else 1)
	_emit_time()


func unregister_arena(old_arena: Node) -> void:
	if arena == old_arena:
		arena = null
		if phase == Phase.PLAYING:
			phase = Phase.IDLE


func current_screen_path() -> String:
	return stage.screens[screen_index] if stage and screen_index < stage.screen_count() else ""


func warning_time() -> float:
	return stage.time_warning if stage else 15.0


func _process(delta: float) -> void:
	if phase != Phase.PLAYING or arena == null:
		return
	time_left = maxf(0.0, time_left - delta)
	_emit_time()
	if not _warned and time_left <= warning_time():
		_warned = true
		EventBus.time_warning.emit()
		AudioManager.play_sfx("time_warning")
	if time_left <= 0.0:
		fail_screen()


func _emit_time() -> void:
	var s := int(ceilf(time_left))
	if s != _last_second:
		_last_second = s
		EventBus.time_changed.emit(s)


func _load_screen(transition: StringName) -> void:
	phase = Phase.TRANSITION
	arena = null
	GameManager.request_scene(current_screen_path(), transition)


func _award_time_bonus() -> void:
	for i in GameManager.player_count():
		if GameManager.is_player_active(i):
			ScoreManager.award_time_bonus(i, time_left)


func _on_game_over() -> void:
	if stage == null:
		return
	phase = Phase.GAME_OVER
	GameManager.request_scene(GAME_OVER_SCREEN, &"fade")
