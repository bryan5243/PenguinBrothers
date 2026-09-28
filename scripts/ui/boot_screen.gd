extends Control
## Pantalla CONTROLES (desde el título): probador de controles en vivo para ambos jugadores
## (teclado, mandos y táctil), asignación de mandos y acceso a las herramientas de prueba
## (laboratorio de movimiento con cámara que sigue: legado, NO es el formato del juego).

const COMMAND_LABELS := {
	&"move_left": "Izquierda", &"move_right": "Derecha", &"up": "Arriba",
	&"crouch": "Agacharse", &"jump": "Saltar", &"interact": "Interactuar",
	&"bomb": "Bomba", &"switch_bomb": "Cambiar bomba",
}
const DEVICE_NAMES := ["Teclado", "Mando", "Pantalla táctil"]
const ACTIVE_COLOR := Color(1.0, 0.85, 0.3)
const IDLE_COLOR := Color(0.55, 0.68, 0.82)
const PLAYER_TEST_LEVEL := "res://scenes/worlds/test_level/PlayerTestLevel.tscn"
const TITLE_SCREEN := "res://scenes/ui/TitleScreen.tscn"
const ANIMATION_TEST := "res://scenes/player/BluePenguinAnimationTest.tscn"

var _command_labels: Array[Dictionary] = [{}, {}]
var _device_label: Label
var _mode_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventBus.input_device_changed.connect(func(_d: int) -> void: _refresh_status())
	Input.joy_connection_changed.connect(func(_id: int, _c: bool) -> void: _refresh_status.call_deferred())
	_refresh_status()


func _process(_delta: float) -> void:
	for p in 2:
		for cmd in InputManager.COMMANDS:
			var label: Label = _command_labels[p][cmd]
			var on := InputManager.is_pressed(p, cmd)
			label.add_theme_color_override("font_color", ACTIVE_COLOR if on else IDLE_COLOR)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.16, 0.29)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	root.add_child(_label(ProjectSettings.get_setting("application/config/name"), 44, Color.WHITE))
	root.add_child(_label("CONTROLES · Pulsa cualquier control para verlo iluminado. Esc / Start: volver.", 20, IDLE_COLOR))

	_device_label = _label("", 20, Color(0.8, 0.9, 1.0))
	root.add_child(_device_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	for p in 2:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label("Jugador %d · %s" % [p + 1, "Pingüino azul" if p == 0 else "Pingüino rosa"], 26,
			Color(0.5, 0.75, 1.0) if p == 0 else Color(1.0, 0.55, 0.8)))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 24)
		col.add_child(grid)
		for cmd in InputManager.COMMANDS:
			var l := _label(COMMAND_LABELS[cmd], 20, IDLE_COLOR, false)
			grid.add_child(l)
			_command_labels[p][cmd] = l
		columns.add_child(col)

	var buttons := GridContainer.new()
	buttons.columns = 3
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 10)
	root.add_child(buttons)
	var back_button := Button.new()
	back_button.text = "  Volver al título  "
	back_button.custom_minimum_size = Vector2(0, 48)
	back_button.pressed.connect(func() -> void: GameManager.request_scene(TITLE_SCREEN))
	buttons.add_child(back_button)
	_mode_button = Button.new()
	_mode_button.custom_minimum_size = Vector2(0, 48)
	_mode_button.pressed.connect(_toggle_mode)
	buttons.add_child(_mode_button)
	var play_button := Button.new()
	play_button.text = "  Laboratorio 1J (legado)  "
	play_button.custom_minimum_size = Vector2(0, 48)
	play_button.pressed.connect(_open_player_test.bind(GameManager.GameMode.SOLO))
	buttons.add_child(play_button)
	var coop_button := Button.new()
	coop_button.text = "  Laboratorio 2J (legado)  "
	coop_button.custom_minimum_size = Vector2(0, 48)
	coop_button.pressed.connect(_open_player_test.bind(GameManager.GameMode.COOP))
	buttons.add_child(coop_button)
	var anim_button := Button.new()
	anim_button.text = "  Animaciones del azul  "
	anim_button.custom_minimum_size = Vector2(0, 48)
	anim_button.pressed.connect(func() -> void: GameManager.request_scene(ANIMATION_TEST))
	buttons.add_child(anim_button)
	root.add_child(_label("Los comandos se iluminan al pulsarlos. En modo individual el Jugador 1 acepta cualquier control.", 16, IDLE_COLOR))
	_update_mode_button()
	back_button.grab_focus.call_deferred()


func _open_player_test(mode: GameManager.GameMode) -> void:
	GameManager.start_new_game(mode)
	GameManager.request_scene(PLAYER_TEST_LEVEL)


func _toggle_mode() -> void:
	InputManager.set_coop(not InputManager.coop)
	_update_mode_button()
	_refresh_status()


func _update_mode_button() -> void:
	_mode_button.text = "  Modo: %s (cambiar)  " % ("Cooperativo" if InputManager.coop else "Individual")


func _refresh_status() -> void:
	var pads := InputManager.connected_gamepads()
	var pad_names: Array[String] = []
	for id in pads:
		pad_names.append(Input.get_joy_name(id))
	_device_label.text = "Último control usado: %s   ·   Mandos conectados: %d%s   ·   Táctil: %s" % [
		DEVICE_NAMES[InputManager.last_device], pads.size(),
		(" (" + ", ".join(pad_names) + ")") if not pad_names.is_empty() else "",
		"sí" if InputManager.is_touch_device() else "no",
	]
	if not pads.is_empty():
		var who: Array[String] = []
		for i in 2:
			var dev := InputManager.gamepad_for_player(i)
			who.append("J%d: %s" % [i + 1, "teclado" if dev == InputManager.NO_GAMEPAD else "mando %d" % dev])
		_device_label.text += "\nMandos asignados · " + "  ·  ".join(who)


func _label(text: String, size: int, color: Color, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.PAUSE_ACTION):
		get_viewport().set_input_as_handled()
		GameManager.request_scene(TITLE_SCREEN)
