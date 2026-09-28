extends PlayerState
## Aterrizaje tras una caída fuerte: breve aplastamiento. No bloquea el control:
## un salto almacenado o el movimiento salen de inmediato.

var _timer := 0.0


func enter(message := {}) -> void:
	_timer = player.config.land_duration
	var impact: float = message.get("impact", player.config.land_min_fall_speed)
	var strength := clampf(impact / player.config.max_fall_speed, 0.0, 1.0)
	player.animator.play_animation(PlayerAnimator.LAND, true)
	player.animator.squash(Vector2(1.0 + 0.25 * strength, 1.0 - 0.25 * strength))
	AudioManager.play_sfx("land")


func physics_update(delta: float) -> void:
	_timer -= delta
	player.face_input()
	player.apply_gravity(delta)
	player.apply_horizontal(delta, player.input.move_axis * player.config.move_speed)
	if check_ground_transitions():
		return
	if _timer <= 0.0 or absf(player.input.move_axis) > 0.2:
		transition_to(&"Move" if absf(player.input.move_axis) > 0.2 else &"Idle")
