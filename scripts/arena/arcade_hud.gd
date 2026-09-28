class_name ArcadeHUD
extends CanvasLayer
## Marcador arcade en la franja superior de la arena:
##   1P  SCORE 1 · vidas            TIME            2P  SCORE 2 · vidas
## Escucha EventBus (puntuación, vidas, tiempo, combos, puntos flotantes, pausa).
## La cámara de la arena es fija, así que las coordenadas del mundo coinciden con las de
## pantalla y los puntos flotantes se dibujan aquí mismo.

const P_COLORS: Array[Color] = [Color(0.45, 0.75, 1.0), Color(1.0, 0.55, 0.85)]
const TEXT := Color(1, 1, 1)
const DIM := Color(0.55, 0.62, 0.75)
const WARN := Color(1.0, 0.3, 0.25)
const BAR_HEIGHT := 48.0

var _score_labels: Array[Label] = []
var _lives_labels: Array[Label] = []
var _time_label: Label
var _combo_labels: Array[Label] = []
var _pause_label: Label
var _warning := false
var _blink := 0.0


func _ready() -> void:
	layer = 10
	# Sigue activo en pausa para poder reanudar o salir.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	EventBus.score_changed.connect(_on_score)
	EventBus.lives_changed.connect(_on_lives)
	EventBus.time_changed.connect(_on_time)
	EventBus.time_warning.connect(func() -> void: _warning = true)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.points_awarded.connect(_on_points)
	EventBus.pause_changed.connect(func(p: bool) -> void: _pause_label.visible = p)
	EventBus.player_eliminated.connect(func(i: int) -> void: _on_lives(i, 0))
	refresh()


## Vuelve a leer todo del estado global (al entrar en una pantalla).
func refresh() -> void:
	for i in 2:
		var playing := i < GameManager.player_count()
		_score_labels[i].text = "%06d" % ScoreManager.scores[i] if playing else "------"
		_on_lives(i, GameManager.lives[i])
	_on_time(int(ceilf(StageManager.time_left)) if StageManager.arena else 0)


func get_time_text() -> String:
	return _time_label.text


func get_score_text(player_index: int) -> String:
	return _score_labels[player_index].text


func _build() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.03, 0.06, 0.14, 0.92)
	bar.position = Vector2.ZERO
	bar.size = Vector2(960, BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	for i in 2:
		var x := 16.0 if i == 0 else 960.0 - 16.0 - 300.0
		var align := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var tag := _label("%dP" % (i + 1), 22, P_COLORS[i], Vector2(x, 2), Vector2(300, 24), align)
		tag.name = "Tag%d" % (i + 1)
		_score_labels.append(_label("000000", 22, TEXT, Vector2(x + (48.0 if i == 0 else 0.0), 2),
			Vector2(252 if i == 0 else 252, 24), align))
		_lives_labels.append(_label("", 16, P_COLORS[i], Vector2(x, 25), Vector2(300, 20), align))
		_combo_labels.append(_label("", 20, Color(1, 0.85, 0.3), Vector2(x, BAR_HEIGHT + 4), Vector2(300, 24), align))
	# El número del 2P va a la izquierda de su etiqueta.
	_score_labels[1].position.x = 960.0 - 16.0 - 300.0 - 48.0
	_time_label = _label("TIME 00", 26, TEXT, Vector2(380, 8), Vector2(200, 32), HORIZONTAL_ALIGNMENT_CENTER)
	_pause_label = _label("PAUSA\nStart / Esc: continuar · Bomba: salir al título", 30, TEXT,
		Vector2(0, 300), Vector2(960, 100), HORIZONTAL_ALIGNMENT_CENTER)
	_pause_label.visible = false


func _label(text: String, size: int, color: Color, pos: Vector2, box: Vector2,
		align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = box
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.1))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _on_score(i: int, score: int) -> void:
	if i < _score_labels.size() and i < GameManager.player_count():
		_score_labels[i].text = "%06d" % score


func _on_lives(i: int, lives: int) -> void:
	if i >= _lives_labels.size():
		return
	if i >= GameManager.player_count():
		_lives_labels[i].text = "—"
		_lives_labels[i].add_theme_color_override("font_color", DIM)
	elif GameManager.eliminated[i]:
		_lives_labels[i].text = "GAME OVER"
	else:
		_lives_labels[i].text = "VIDAS x%d" % lives


func _on_time(seconds: int) -> void:
	_time_label.text = "TIME %02d" % seconds


func _on_combo(i: int, combo: int) -> void:
	_combo_labels[i].text = "COMBO x%d" % combo if combo > 1 else ""


func _on_points(_i: int, amount: int, at: Vector2) -> void:
	var l := _label(str(amount), 18, Color(1, 0.95, 0.5), at - Vector2(40, 30), Vector2(80, 24),
		HORIZONTAL_ALIGNMENT_CENTER)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 36.0, 0.7)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	t.tween_callback(l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.PAUSE_ACTION):
		GameManager.set_paused(not GameManager.is_paused)
		get_viewport().set_input_as_handled()
	elif GameManager.is_paused and (event.is_action_pressed(&"p1_bomb") or event.is_action_pressed(&"p2_bomb")):
		get_viewport().set_input_as_handled()
		GameManager.set_paused(false)
		StageManager.go_to_title()


func _process(delta: float) -> void:
	if _warning:
		_blink += delta * 4.0
		_time_label.add_theme_color_override("font_color", WARN if int(_blink) % 2 == 0 else TEXT)
