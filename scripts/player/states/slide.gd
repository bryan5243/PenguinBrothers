extends PlayerState
## Deslizamiento sobre el vientre: se activa al agacharse corriendo.
## Mantiene el cuerpo bajo (pasa por huecos estrechos) y frena poco a poco.

var _timer := 0.0


func enter(_message := {}) -> void:
	_timer = player.config.slide_duration
	player.set_low_profile(true, player.config.slide_height)
	player.velocity.x = player.facing * maxf(player.config.slide_speed, absf(player.velocity.x))
	player.animator.play_animation(PlayerAnimator.SLIDE, true)
	AudioManager.play_sfx("slide")


func physics_update(delta: float) -> void:
	_timer -= delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.config.slide_friction * delta)
	if not player.is_on_floor():
		transition_to(&"Fall")
		return
	if player.has_buffered_jump() and player.can_stand_up():
		player.set_low_profile(false)
		transition_to(&"Jump")
		return
	var stopped := absf(player.velocity.x) < 60.0 or player.is_on_wall()
	if _timer <= 0.0 or stopped:
		if player.input.crouch_held or not player.can_stand_up():
			transition_to(&"Crouch")
		else:
			player.set_low_profile(false)
			transition_to(&"Move" if absf(player.input.move_axis) > 0.2 else &"Idle")
