extends Control
## Pantalla de título arcade: «PULSA START» (equivalente moderno a INSERT COIN) y menú
## 1 PLAYER · 2 PLAYERS · OPCIONES · CONTROLES · SALIR. Se navega con cualquier jugador
## (arriba/abajo y Saltar/Bomba/Interactuar/Start).

const CONTROLS_SCREEN := "res://scenes/ui/BootScreen.tscn"
const ITEMS := ["1 PLAYER", "2 PLAYERS", "OPCIONES", "CONTROLES", "SALIR"]
const GOLD := Color(1.0, 0.82, 0.25)
const DIM := Color(0.6, 0.72, 0.88)

enum Mode { PRESS_START, MENU, OPTIONS }

var mode := Mode.PRESS_START
var selected := 0
var option_selected := 0
var _blink := 0.0
var _press_label: Label
var _menu: VBoxContainer
var _menu_labels: Array[Label] = []
var _options: VBoxContainer
var _option_labels: Array[Label] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.set_paused(false)
	_build()
	_show(Mode.PRESS_START)


func _process(delta: float) -> void:
	_blink += delta
	match mode:
		Mode.PRESS_START:
			_press_label.visible = int(_blink * 2.5) % 2 == 0
			if MenuInput.confirm():
				AudioManager.play_sfx("start")
				_show(Mode.MENU)
		Mode.MENU:
			var v := MenuInput.vertical()
			if v != 0:
				selected = wrapi(selected + v, 0, ITEMS.size())
				AudioManager.play_sfx("ui_select")
				_refresh_menu()
			elif MenuInput.confirm():
				_choose(selected)
		Mode.OPTIONS:
			_process_options()


func choose_item(label: String) -> void:
	_choose(ITEMS.find(label))


func _choose(index: int) -> void:
	AudioManager.play_sfx("ui_confirm")
	match index:
		0:
			StageManager.start_new_game(GameManager.GameMode.SOLO)
		1:
			StageManager.start_new_game(GameManager.GameMode.COOP)
		2:
			_show(Mode.OPTIONS)
		3:
			GameManager.request_scene(CONTROLS_SCREEN)
		4:
			get_tree().quit()


# ------------------------------------------------------------------ opciones
func _option_rows() -> Array[String]:
	var music := int(round(float(SaveManager.get_value("settings", "music_volume", 0.8)) * 10.0))
	var sfx := int(round(float(SaveManager.get_value("settings", "sfx_volume", 0.9)) * 10.0))
	var full: bool = SaveManager.get_value("settings", "fullscreen", false)
	return [
		"MÚSICA      ◀ %s ▶" % _bar(music),
		"EFECTOS     ◀ %s ▶" % _bar(sfx),
		"PANTALLA    ◀ %s ▶" % ("COMPLETA" if full else "VENTANA"),
		"PROPORCIÓN  4:3 (arcade)",
		"VOLVER",
	]


func _bar(level: int) -> String:
	return "■".repeat(level) + "□".repeat(10 - level)


func _process_options() -> void:
	var v := MenuInput.vertical()
	var h := MenuInput.horizontal()
	if v != 0:
		option_selected = wrapi(option_selected + v, 0, 5)
		_refresh_options()
	elif h != 0:
		_change_option(option_selected, h)
	elif MenuInput.confirm() and option_selected == 4:
		SaveManager.save_game()
		_show(Mode.MENU)


func _change_option(row: int, dir: int) -> void:
	match row:
		0, 1:
			var key := "music_volume" if row == 0 else "sfx_volume"
			var value := clampf(float(SaveManager.get_value("settings", key, 0.8)) + dir * 0.1, 0.0, 1.0)
			SaveManager.set_value("settings", key, snappedf(value, 0.1))
			AudioManager.set_bus_volume(AudioManager.MUSIC_BUS if row == 0 else AudioManager.SFX_BUS, value)
		2:
			var full: bool = not SaveManager.get_value("settings", "fullscreen", false)
			SaveManager.set_value("settings", "fullscreen", full)
			if not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full
					else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioManager.play_sfx("ui_select")
	_refresh_options()


# ------------------------------------------------------------------ interfaz
func _show(new_mode: Mode) -> void:
	mode = new_mode
	_press_label.visible = mode == Mode.PRESS_START
	_menu.visible = mode == Mode.MENU
	_options.visible = mode == Mode.OPTIONS
	_refresh_menu()
	_refresh_options()


func _refresh_menu() -> void:
	for i in _menu_labels.size():
		var on := i == selected
		_menu_labels[i].text = ("▶  %s  ◀" if on else "%s") % ITEMS[i]
		_menu_labels[i].add_theme_color_override("font_color", GOLD if on else DIM)


func _refresh_options() -> void:
	var rows := _option_rows()
	for i in _option_labels.size():
		var on := i == option_selected
		_option_labels[i].text = ("▶ " if on else "   ") + rows[i]
		_option_labels[i].add_theme_color_override("font_color", GOLD if on else DIM)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var band := ColorRect.new()
	band.color = Color(0.08, 0.2, 0.42)
	band.position = Vector2(0, 90)
	band.size = Vector2(960, 190)
	add_child(band)
	_label("PENGUIN", 88, Color(0.45, 0.78, 1.0), Vector2(0, 92), 960)
	_label("BROTHERS", 88, Color(1.0, 0.55, 0.85), Vector2(0, 180), 960)
	_label("EDICIÓN ASIÁTICA", 26, GOLD, Vector2(0, 282), 960)
	_penguin(Player.Character.BLUE_PENGUIN, Vector2(150, 270), false)
	_penguin(Player.Character.PINK_PENGUIN, Vector2(810, 270), true)
	var hi := int(SaveManager.get_value("progress", "high_score", 0))
	_label("HI-SCORE %06d" % hi, 24, Color.WHITE, Vector2(0, 30), 960)

	_press_label = _label("PULSA START", 40, GOLD, Vector2(0, 430), 960)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(0, 360)
	_menu.size = Vector2(960, 300)
	_menu.add_theme_constant_override("separation", 6)
	add_child(_menu)
	for item in ITEMS:
		var l := _label(item, 34, DIM, Vector2.ZERO, 960, false)
		_menu.add_child(l)
		_menu_labels.append(l)

	_options = VBoxContainer.new()
	_options.position = Vector2(200, 360)
	_options.size = Vector2(560, 300)
	_options.add_theme_constant_override("separation", 10)
	add_child(_options)
	for i in 5:
		var l := _label("", 28, DIM, Vector2.ZERO, 560, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_options.add_child(l)
		_option_labels.append(l)

	_label("1P: A/D · W/Espacio salto · S · Q bomba · E acción     2P: flechas · Ctrl der. · Shift der.",
		16, DIM, Vector2(0, 680), 960)


func _penguin(character: int, pos: Vector2, flip: bool) -> void:
	var folder := "blue_penguin" if character == Player.Character.BLUE_PENGUIN else "pink_penguin"
	var frames := load("res://assets/characters/%s/%s_frames.tres" % [folder, folder]) as SpriteFrames
	if frames == null:
		return
	var holder := Node2D.new()
	holder.position = pos
	add_child(holder)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.flip_h = flip
	var canvas := Vector2(frames.get_meta(&"canvas_size", Vector2i(100, 100)))
	sprite.offset = Vector2(0, -canvas.y * 0.5)
	var ref := float(frames.get_meta(&"reference_height", canvas.y))
	holder.scale = Vector2.ONE * (150.0 / ref)
	holder.add_child(sprite)
	sprite.play(&"victory" if frames.has_animation(&"victory") else &"idle")


func _label(text: String, size: int, color: Color, pos: Vector2, width: float, add := true) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.1))
	l.add_theme_constant_override("outline_size", 8)
	if add:
		add_child(l)
	return l
