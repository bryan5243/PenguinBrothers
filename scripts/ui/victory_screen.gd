extends Control
## Fase completada: muestra la puntuación, guarda el récord y, con Start (o tras unos
## segundos), sigue a la siguiente fase o vuelve al título si no hay más.

const AUTO_CONTINUE := 6.0

var time_left := AUTO_CONTINUE
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.14, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stage := StageManager.stage
	_label("¡FASE COMPLETADA!", 64, Color(1.0, 0.82, 0.25), 170)
	_label(stage.display_name if stage else "", 30, Color.WHITE, 270)
	_label("1P %06d" % ScoreManager.scores[0], 30, Color(0.45, 0.75, 1.0), 360)
	if GameManager.is_coop():
		_label("2P %06d" % ScoreManager.scores[1], 30, Color(1.0, 0.55, 0.85), 410)
	_label("Pulsa Start", 22, Color(0.6, 0.72, 0.88), 540)
	AudioManager.play_sfx("victory")
	SaveManager.set_value("progress", "high_score",
		maxi(int(SaveManager.get_value("progress", "high_score", 0)), ScoreManager.total()))
	SaveManager.save_game()


func _process(delta: float) -> void:
	if _done:
		return
	time_left -= delta
	if time_left <= 0.0 or (time_left < AUTO_CONTINUE - 0.5 and MenuInput.confirm()):
		_done = true
		var stage := StageManager.stage
		if stage and stage.next_stage != "" and ResourceLoader.exists(stage.next_stage):
			StageManager.start_stage(load(stage.next_stage) as StageData)
		else:
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
