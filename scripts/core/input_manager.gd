extends Node
## Capa de abstracción de entrada.
## El gameplay nunca lee teclas ni botones concretos: pregunta por comandos
## ("jump", "bomb"...) de un jugador. Este autoload traduce el comando a las acciones
## del Input Map ("p1_jump", "p2_jump"...), que agrupan teclado, mando y táctil.
##
## En modo individual el Jugador 1 acepta también las acciones del Jugador 2
## (flechas, segundo mando), para poder jugar solo con cualquier control.

enum Device { KEYBOARD, GAMEPAD, TOUCH }

const COMMANDS: Array[StringName] = [
	&"move_left", &"move_right", &"up", &"crouch",
	&"jump", &"interact", &"bomb", &"switch_bomb",
]
const PAUSE_ACTION := &"pause"
const PLAYER_PREFIXES: Array[String] = ["p1_", "p2_"]

var coop := false
var last_device: Device = Device.KEYBOARD


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_touch_device():
		last_device = Device.TOUCH


func set_coop(enabled: bool) -> void:
	coop = enabled


## Nombres de las acciones del Input Map que representan `command` para un jugador.
func actions_for(player_index: int, command: StringName) -> Array[StringName]:
	var result: Array[StringName] = [StringName(PLAYER_PREFIXES[player_index] + command)]
	if not coop and player_index == 0:
		result.append(StringName(PLAYER_PREFIXES[1] + command))
	return result


func is_pressed(player_index: int, command: StringName) -> bool:
	for a in actions_for(player_index, command):
		if Input.is_action_pressed(a):
			return true
	return false


func is_just_pressed(player_index: int, command: StringName) -> bool:
	for a in actions_for(player_index, command):
		if Input.is_action_just_pressed(a):
			return true
	return false


func is_just_released(player_index: int, command: StringName) -> bool:
	for a in actions_for(player_index, command):
		if Input.is_action_just_released(a):
			return true
	return false


func get_strength(player_index: int, command: StringName) -> float:
	var s := 0.0
	for a in actions_for(player_index, command):
		s = maxf(s, Input.get_action_strength(a))
	return s


## Eje horizontal -1..1 (izquierda/derecha), con fuerza analógica si viene del stick.
func get_move_axis(player_index: int) -> float:
	return get_strength(player_index, &"move_right") - get_strength(player_index, &"move_left")


## Eje vertical -1..1 (arriba negativo, abajo positivo), útil para escaleras.
func get_vertical_axis(player_index: int) -> float:
	return get_strength(player_index, &"crouch") - get_strength(player_index, &"up")


## Pulsa/suelta un comando desde código (lo usarán los controles táctiles).
func press_command(player_index: int, command: StringName, strength := 1.0) -> void:
	Input.action_press(StringName(PLAYER_PREFIXES[player_index] + command), strength)


func release_command(player_index: int, command: StringName) -> void:
	Input.action_release(StringName(PLAYER_PREFIXES[player_index] + command))


func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")


func connected_gamepads() -> Array[int]:
	return Input.get_connected_joypads()


func _input(event: InputEvent) -> void:
	var device := last_device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		device = Device.TOUCH
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		device = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton:
		device = Device.KEYBOARD
	if device != last_device:
		last_device = device
		EventBus.input_device_changed.emit(device)
