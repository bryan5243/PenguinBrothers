extends EnemyState
## DEAD: animación de muerte (deja de chocar y de hacer daño); al acabar, puntos (con
## combo), botín, aviso `defeated` y desaparece.

const MIN_TIME := 0.5

var _timer := 0.0
var _done := false


func enter(_message := {}) -> void:
	_done = false
	enemy.collision_layer = 0
	enemy.hitbox.set_deferred(&"monitoring", false)
	enemy.velocity = Vector2(enemy.velocity.x * 0.3, -180.0 if not enemy.data.flying else 0.0)
	enemy.play(&"death", true)
	var frames := enemy.animator.sprite_frames
	_timer = MIN_TIME
	if frames and frames.has_animation(&"death"):
		_timer = maxf(MIN_TIME, frames.get_frame_count(&"death") / maxf(frames.get_animation_speed(&"death"), 1.0))


func physics_update(delta: float) -> void:
	if enemy.data.flying:
		enemy.velocity.y = minf(enemy.velocity.y + 900.0 * delta, 500.0)
	else:
		enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 400.0 * delta)
	_timer -= delta
	if _timer <= 0.0 and not _done:
		_done = true
		enemy.finish_death()
