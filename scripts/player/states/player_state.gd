class_name PlayerState
extends State
## Base de los estados del jugador: acceso tipado al jugador y transiciones comunes.

var player: Player:
	get:
		return actor as Player


## Transiciones compartidas por los estados en el suelo (Idle, Move, Land).
## Devuelve true si cambió de estado.
func check_ground_transitions() -> bool:
	if not player.is_on_floor():
		transition_to(&"Fall")
		return true
	var ladder := player.wants_ladder()
	if ladder:
		transition_to(&"Climb", {"ladder": ladder})
		return true
	if player.has_buffered_jump():
		if player.input.crouch_held and player.is_on_platform():
			player.drop_through_platform()
			transition_to(&"Fall")
			return true
		if player.can_jump():
			transition_to(&"Jump")
			return true
	if player.input.crouch_held:
		transition_to(&"Slide" if player.can_slide() else &"Crouch")
		return true
	return false


## Transiciones compartidas en el aire (Jump, Fall).
func check_air_transitions() -> bool:
	var ladder := player.wants_ladder()
	if ladder:
		transition_to(&"Climb", {"ladder": ladder})
		return true
	if player.can_jump():
		# Coyote time: aún se puede saltar justo después de dejar el borde.
		transition_to(&"Jump")
		return true
	return false


## Controla el movimiento horizontal con la velocidad dada.
func air_control(delta: float) -> void:
	player.face_input()
	player.apply_horizontal(delta, player.input.move_axis * player.config.move_speed * _air_speed_factor())


func _air_speed_factor() -> float:
	# Conserva el impulso de la carrera al saltar.
	var cfg := player.config
	return clampf(absf(player.velocity.x) / cfg.move_speed, 1.0, cfg.run_speed / cfg.move_speed)
