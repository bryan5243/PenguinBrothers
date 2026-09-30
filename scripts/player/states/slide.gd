extends PlayerState
## Deslizamiento sobre el vientre: se activa al agacharse andando (o corriendo).
## Arranca con un pequeño impulso, resbala y se va apagando (frenado fijo + proporcional).
## Mantiene el cuerpo bajo (pasa por huecos estrechos). Mientras dura:
##   · los ataques de los enemigos no le hacen daño (las bombas sí),
##   · los enemigos que toca se apartan (empujados, sin daño) y lo frenan un poco.

const ENEMY_LAYER := 1 << 2

var _timer := 0.0
var _dir := 1.0
var _ramp := 0.0
var _shoving := false


func enter(_message := {}) -> void:
	_timer = player.config.slide_duration
	_dir = signf(player.velocity.x) if not is_zero_approx(player.velocity.x) else float(player.facing)
	_ramp = 0.0
	player.set_low_profile(true, player.config.slide_height)
	player.animator.play_animation(PlayerAnimator.SLIDE, true)
	player.animator.squash(Vector2(1.12, 0.86))
	AudioManager.play_sfx("slide")


func exit() -> void:
	player.animator.set_playback_speed(1.0)


func physics_update(delta: float) -> void:
	var cfg := player.config
	_timer -= delta
	player.apply_gravity(delta)
	var speed := absf(player.velocity.x)
	if _ramp < cfg.slide_ramp_time:
		# Arranque: sube de la velocidad con la que entró a la del deslizamiento.
		_ramp += delta
		speed = maxf(speed, lerpf(speed, cfg.slide_speed, clampf(_ramp / maxf(cfg.slide_ramp_time, 0.001), 0.0, 1.0)))
	else:
		var brake := cfg.slide_friction + cfg.slide_drag * speed + (cfg.slide_shove_drag if _shoving else 0.0)
		speed = maxf(0.0, speed - brake * delta)
	player.velocity.x = _dir * speed
	# La animación va al ritmo del resbalón.
	player.animator.set_playback_speed(clampf(speed / cfg.slide_speed, 0.5, 1.2))
	_shoving = _shove_enemies(speed)
	if not player.is_on_floor():
		transition_to(&"Fall")
		return
	if player.has_buffered_jump() and player.can_stand_up():
		player.set_low_profile(false)
		transition_to(&"Jump")
		return
	var stopped := speed < cfg.slide_min_speed or player.is_on_wall()
	if _timer <= 0.0 or stopped:
		if player.input.crouch_held or not player.can_stand_up():
			transition_to(&"Crouch")
		else:
			player.set_low_profile(false)
			transition_to(&"Move" if absf(player.input.move_axis) > 0.2 else &"Idle")


## Aparta a los enemigos que toca el cuerpo (sin daño). Devuelve true si empujó a alguno.
func _shove_enemies(speed: float) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(player.config.body_radius * 2.0 + 10.0, player.config.slide_height)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, player.global_position + Vector2(_dir * 4.0, -player.config.slide_height * 0.5))
	query.collision_mask = ENEMY_LAYER
	query.collide_with_areas = false
	var pushed := false
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 8):
		var enemy := hit["collider"] as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		# Solo los que tiene delante: los que quedan detrás no se tocan.
		if signf(enemy.global_position.x - player.global_position.x) == _dir:
			enemy.shove(_dir * speed * player.config.slide_shove_ratio)
			pushed = true
	return pushed
