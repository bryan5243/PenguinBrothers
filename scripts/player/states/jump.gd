extends PlayerState
## Salto. La altura depende de cuánto se mantiene el botón (salto variable).


func enter(_message := {}) -> void:
	player.consume_jump()
	player.velocity.y = -player.config.jump_force
	player.animator.play_animation(PlayerAnimator.JUMP, true)
	player.animator.squash(Vector2(0.82, 1.2))
	AudioManager.play_sfx("jump")


func physics_update(delta: float) -> void:
	var cfg := player.config
	if not player.input.jump_held and player.velocity.y < -cfg.jump_cut_speed:
		player.velocity.y = -cfg.jump_cut_speed
	if player.is_on_ceiling() and player.velocity.y < 0.0:
		player.velocity.y = 0.0
	player.apply_gravity(delta)
	air_control(delta)
	var ladder := player.wants_ladder()
	if ladder:
		transition_to(&"Climb", {"ladder": ladder})
		return
	if player.velocity.y >= 0.0:
		transition_to(&"Fall")
