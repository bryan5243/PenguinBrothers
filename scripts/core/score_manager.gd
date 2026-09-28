extends Node
## Puntuación arcade por jugador (SCORE 1 / SCORE 2), combos y bonificaciones.
## Los valores están en data/score_table.tres (ScoreTable). Avisa por EventBus:
##   score_changed    -> HUD
##   points_awarded   -> números flotantes en el lugar del derribo
##   combo_changed    -> «combo x2», «x3»...

const TABLE_PATH := "res://data/score_table.tres"
const MAX_PLAYERS := 2

var table: ScoreTable
var scores: Array[int] = [0, 0]
var combos: Array[int] = [0, 0]
var _combo_timers: Array[float] = [0.0, 0.0]


func _ready() -> void:
	table = load(TABLE_PATH) as ScoreTable if ResourceLoader.exists(TABLE_PATH) else null
	if table == null:
		table = ScoreTable.new()


func reset() -> void:
	for i in MAX_PLAYERS:
		scores[i] = 0
		combos[i] = 0
		_combo_timers[i] = 0.0
		EventBus.score_changed.emit(i, 0)


## Suma puntos a un jugador. `at` es la posición en el mundo para el número flotante.
func add_points(player_index: int, amount: int, at: Variant = null) -> int:
	if player_index < 0 or player_index >= MAX_PLAYERS or amount == 0:
		return 0
	scores[player_index] = maxi(0, scores[player_index] + amount)
	EventBus.score_changed.emit(player_index, scores[player_index])
	if at is Vector2:
		EventBus.points_awarded.emit(player_index, amount, at)
	return amount


## Derribo que cuenta para el combo: dentro de `combo_window` el multiplicador sube
## (x2, x3... hasta max_combo). Devuelve los puntos concedidos.
func register_kill(player_index: int, base_points: int, at: Variant = null) -> int:
	if player_index < 0 or player_index >= MAX_PLAYERS:
		return 0
	combos[player_index] = mini(combos[player_index] + 1, table.max_combo) if _combo_timers[player_index] > 0.0 else 1
	_combo_timers[player_index] = table.combo_window
	if combos[player_index] > 1:
		EventBus.combo_changed.emit(player_index, combos[player_index])
	return add_points(player_index, base_points * combos[player_index], at)


## Bonificación por tiempo restante al completar una pantalla.
func award_time_bonus(player_index: int, seconds_left: float) -> int:
	return add_points(player_index, int(seconds_left) * table.time_bonus_per_second)


func total() -> int:
	var t := 0
	for s in scores:
		t += s
	return t


func _process(delta: float) -> void:
	for i in MAX_PLAYERS:
		if _combo_timers[i] > 0.0:
			_combo_timers[i] -= delta
			if _combo_timers[i] <= 0.0 and combos[i] > 1:
				combos[i] = 0
				EventBus.combo_changed.emit(i, 0)
