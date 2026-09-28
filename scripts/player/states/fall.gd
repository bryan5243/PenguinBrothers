extends PlayerState
## En el aire bajando (tras un salto o al dejar un borde).

var _max_fall_speed := 0.0


func enter(_message := {}) -> void:
	_max_fall_speed = 0.0
	player.animator.play_animation(PlayerAnimator.FALL)
	if player.is_low and player.can_stand_up():
		player.set_low_profile(false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	air_control(delta)
	_max_fall_speed = maxf(_max_fall_speed, player.velocity.y)
	if check_air_transitions():
		return
	if player.is_on_floor():
		if player.is_low:
			transition_to(&"Crouch")
		elif _max_fall_speed >= player.config.land_min_fall_speed:
			transition_to(&"Land", {"impact": _max_fall_speed})
		elif absf(player.input.move_axis) > 0.2:
			transition_to(&"Move")
		else:
			transition_to(&"Idle")
