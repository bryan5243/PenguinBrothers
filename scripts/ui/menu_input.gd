class_name MenuInput
extends RefCounted
## Lectura de menús arcade con cualquiera de los dos jugadores (teclado, mandos o táctil),
## siempre mediante los comandos de InputManager (nunca teclas directas).


static func pressed(command: StringName) -> bool:
	return InputManager.is_just_pressed(0, command) or InputManager.is_just_pressed(1, command)


## Confirmar: Saltar, Bomba, Interactuar o Start. W y ↑ saltan y a la vez son «arriba»:
## en ese caso cuentan como arriba, no como confirmar.
static func confirm() -> bool:
	var jump := pressed(&"jump") and not pressed(&"up")
	return jump or pressed(&"bomb") or pressed(&"interact") \
		or Input.is_action_just_pressed(InputManager.PAUSE_ACTION)


## -1 arriba, 1 abajo, 0 nada.
static func vertical() -> int:
	if pressed(&"up"):
		return -1
	if pressed(&"crouch"):
		return 1
	return 0


## -1 izquierda, 1 derecha, 0 nada.
static func horizontal() -> int:
	if pressed(&"move_left"):
		return -1
	if pressed(&"move_right"):
		return 1
	return 0
