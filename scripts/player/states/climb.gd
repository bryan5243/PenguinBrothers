extends PlayerState
## Subir y bajar escaleras. Sin gravedad; el jugador se centra en la escalera y atraviesa
## las plataformas mientras trepa. Saltar suelta la escalera; al llegar arriba queda de pie.

var ladder: Ladder


func enter(message := {}) -> void:
	ladder = message.get("ladder")
	player.bombs.drop_held()
	player.set_low_profile(false)
	player.set_platform_collision(false)
	player.velocity = Vector2.ZERO
	player.global_position.x = ladder.center_x()
	player.animator.play_animation(PlayerAnimator.CLIMB)


func exit() -> void:
	player.set_platform_collision(true)
	player.animator.set_playback_speed(1.0)


func physics_update(_delta: float) -> void:
	var cfg := player.config
	if not is_instance_valid(ladder) or player.get_overlapping_ladder() != ladder:
		_leave(&"Fall")
		return
	if player.input.jump_pressed:
		player.consume_jump()
		player.global_position.y -= 2.0
		player.velocity.x = player.input.move_axis * cfg.move_speed
		transition_to(&"Jump")
		return
	var v := player.input.vertical_axis
	player.velocity = Vector2(0.0, v * cfg.climb_speed)
	player.global_position.x = ladder.center_x()
	player.animator.set_playback_speed(absf(v))
	# Arriba: los pies alcanzan la parte superior -> de pie sobre la plataforma.
	if v < 0.0 and player.global_position.y <= ladder.top_y():
		player.global_position.y = ladder.top_y() - 1.0
		player.velocity = Vector2.ZERO
		_leave(&"Idle")
		return
	# Abajo: toca el suelo.
	if v > 0.0 and player.is_on_floor() and player.global_position.y > ladder.top_y() + 16.0:
		_leave(&"Idle")


func _leave(next_state: StringName) -> void:
	player.set_platform_collision(true)
	transition_to(next_state)
