class_name State
extends Node
## Estado base para StateMachine. Cada estado concreto (Idle, Run, Patrol, Attack...)
## hereda de esta clase y sobrescribe solo lo que necesita.

## Asignado por la StateMachine al registrarse.
var state_machine: StateMachine
## Nodo controlado (Player, Enemy, Boss...).
var actor: Node


func enter(_message := {}) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


## Atajo para cambiar de estado desde dentro de un estado.
func transition_to(state_name: StringName, message := {}) -> void:
	state_machine.transition_to(state_name, message)
