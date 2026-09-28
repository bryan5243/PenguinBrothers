extends PlayerState
## De pie, sin moverse.


func enter(_message := {}) -> void:
	player.animator.play_animation(PlayerAnimator.IDLE)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal(delta, 0.0)
	if check_ground_transitions():
		return
	if absf(player.input.move_axis) > 0.2:
		transition_to(&"Move")
