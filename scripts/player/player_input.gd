class_name PlayerInput
extends RefCounted
## Lectura de comandos de UN jugador en el frame actual.
## Los estados del jugador consultan este objeto en lugar de Input directamente,
## lo que permite reemplazarlo en el futuro (IA, repeticiones, pruebas automáticas).

var player_index := 0
var enabled := true

var move_axis := 0.0
var vertical_axis := 0.0
var jump_pressed := false
var jump_held := false
var jump_released := false
var crouch_held := false
var up_held := false
var interact_pressed := false
var bomb_pressed := false
var switch_bomb_pressed := false


func _init(index: int = 0) -> void:
	player_index = index


## Llamar una vez por frame físico, antes de actualizar los estados.
func update() -> void:
	if not enabled:
		clear()
		return
	var im := InputManager
	move_axis = im.get_move_axis(player_index)
	vertical_axis = im.get_vertical_axis(player_index)
	jump_pressed = im.is_just_pressed(player_index, &"jump")
	jump_held = im.is_pressed(player_index, &"jump")
	jump_released = im.is_just_released(player_index, &"jump")
	crouch_held = im.is_pressed(player_index, &"crouch")
	up_held = im.is_pressed(player_index, &"up")
	interact_pressed = im.is_just_pressed(player_index, &"interact")
	bomb_pressed = im.is_just_pressed(player_index, &"bomb")
	switch_bomb_pressed = im.is_just_pressed(player_index, &"switch_bomb")


func clear() -> void:
	move_axis = 0.0
	vertical_axis = 0.0
	jump_pressed = false
	jump_held = false
	jump_released = false
	crouch_held = false
	up_held = false
	interact_pressed = false
	bomb_pressed = false
	switch_bomb_pressed = false
