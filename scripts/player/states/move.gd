extends PlayerState
## Caminar (y correr si `run_enabled`: tras moverse de forma continua `run_delay` segundos).

var _run_timer := 0.0
var _direction := 0


func enter(_message := {}) -> void:
	_run_timer = 0.0
	_direction = signi(int(signf(player.input.move_axis)))


func physics_update(delta: float) -> void:
	var cfg := player.config
	var axis := player.input.move_axis
	var dir := signi(int(signf(axis))) if absf(axis) > 0.2 else 0
	if dir != 0 and dir == _direction:
		_run_timer += delta
	else:
		_run_timer = 0.0
		_direction = dir
	var speed := cfg.run_speed if cfg.run_enabled and _run_timer >= cfg.run_delay else cfg.move_speed
	player.face_input()
	player.apply_gravity(delta)
	player.apply_horizontal(delta, axis * speed)
	if check_ground_transitions():
		return
	if dir == 0 and absf(player.velocity.x) < 10.0:
		transition_to(&"Idle")
		return
	_animate()


func _animate() -> void:
	var cfg := player.config
	var vx := absf(player.velocity.x) / player.speed_multiplier
	if vx > cfg.move_speed + 20.0:
		player.animator.play_animation(PlayerAnimator.RUN)
		player.animator.set_playback_speed(clampf(vx / cfg.run_speed, 0.8, 1.3))
	else:
		player.animator.play_animation(PlayerAnimator.WALK)
		player.animator.set_playback_speed(clampf(vx / cfg.move_speed, 0.5, 1.2))
