extends PlayerState
## Golpe recibido: empuje (aplicado por Player) y un momento sin control.

var _timer := 0.0


func enter(_message := {}) -> void:
	_timer = player.config.hurt_duration
	player.set_low_profile(false)
	player.animator.play_animation(PlayerAnimator.HURT, true)
	player.animator.squash(Vector2(1.15, 0.85))


func physics_update(delta: float) -> void:
	_timer -= delta
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.config.air_friction * delta)
	if _timer > 0.0:
		return
	if player.is_on_floor():
		transition_to(&"Idle")
	else:
		transition_to(&"Fall")
