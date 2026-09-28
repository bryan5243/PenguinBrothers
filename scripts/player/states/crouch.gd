extends PlayerState
## Agachado. Reduce el cuerpo; solo se levanta si hay espacio encima.
## Bajo un techo bajo permite gatear para salir. Abajo + saltar sobre una plataforma la atraviesa.


func enter(_message := {}) -> void:
	player.set_low_profile(true)
	player.animator.play_animation(PlayerAnimator.CROUCH)
	player.animator.squash(Vector2(1.08, 0.92))


func physics_update(delta: float) -> void:
	player.face_input()
	player.apply_gravity(delta)
	var crawl := 0.0 if player.can_stand_up() else player.input.move_axis * player.config.crawl_speed
	player.apply_horizontal(delta, crawl)
	if not player.is_on_floor():
		transition_to(&"Fall")
		return
	var ladder := player.wants_ladder()
	if ladder:
		transition_to(&"Climb", {"ladder": ladder})
		return
	if player.has_buffered_jump():
		if player.is_on_platform():
			player.drop_through_platform()
			transition_to(&"Fall")
			return
		if player.can_stand_up():
			player.set_low_profile(false)
			transition_to(&"Jump")
			return
	if not player.input.crouch_held and player.can_stand_up():
		player.set_low_profile(false)
		transition_to(&"Move" if absf(player.input.move_axis) > 0.2 else &"Idle")
