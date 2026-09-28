extends Control
## GAME OVER arcade con CONTINUE: cuenta atrás de 9 a 0; pulsar Start/Saltar/Bomba
## continúa en la pantalla donde se perdió (vidas completas, puntuación a cero). Si la
## cuenta llega a 0, guarda el récord y vuelve al título.

const COUNTDOWN := 9.99

var time_left := COUNTDOWN
var _count_label: Label
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_label("GAME OVER", 84, Color(1.0, 0.3, 0.3), 170)
	_label("1P %06d        2P %06d" % [ScoreManager.scores[0], ScoreManager.scores[1]], 26, Color.WHITE, 300)
	if GameManager.can_continue():
		_label("CONTINUE?", 44, Color(1.0, 0.82, 0.25), 380)
		_count_label = _label("9", 72, Color.WHITE, 440)
		_label("Pulsa Start para continuar", 20, Color(0.6, 0.72, 0.88), 560)
	else:
		time_left = 3.0
	SaveManager.set_value("progress", "high_score",
		maxi(int(SaveManager.get_value("progress", "high_score", 0)), ScoreManager.total()))
	SaveManager.save_game()


func _process(delta: float) -> void:
	if _done:
		return
	time_left -= delta
	if _count_label:
		_count_label.text = str(maxi(0, int(time_left)))
		if MenuInput.confirm():
			_done = true
			StageManager.continue_game()
			return
	if time_left <= 0.0:
		_done = true
		StageManager.go_to_title()


func _label(text: String, size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(960, size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l
