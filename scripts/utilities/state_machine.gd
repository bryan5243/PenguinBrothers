class_name StateMachine
extends Node
## Máquina de estados finita genérica, reutilizable por jugador, enemigos y jefes.
## Los estados son nodos hijos que heredan de State; el nombre del nodo es su id.

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: State
## Si está activo, la máquina llama a los estados en _process/_physics_process.
## Desactívalo si el actor prefiere llamar a physics_update() manualmente.
@export var auto_process := true

var current_state: State
var states: Dictionary = {}


func _ready() -> void:
	var actor := owner if owner else get_parent()
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.actor = actor
	if initial_state == null and not states.is_empty():
		initial_state = states.values()[0]
	if initial_state:
		# Esperar a que el actor termine su _ready antes de entrar al estado inicial.
		_enter_initial.call_deferred()


func _enter_initial() -> void:
	current_state = initial_state
	current_state.enter()


func _process(delta: float) -> void:
	if auto_process and current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if auto_process and current_state:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(state_name: StringName, message := {}) -> void:
	if not states.has(state_name):
		push_warning("StateMachine '%s': el estado '%s' no existe." % [get_path(), state_name])
		return
	var previous: StringName = current_state.name if current_state else &""
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter(message)
	state_changed.emit(previous, state_name)


func is_in(state_name: StringName) -> bool:
	return current_state != null and current_state.name == state_name
