extends EnemyState
## HURT: aturdido un momento tras un golpe (sale despedido si fue una explosión).

var _timer := 0.0


func enter(_message := {}) -> void:
	_timer = enemy.data.hurt_duration
	enemy.play(&"hurt", true)
	behavior().on_hurt()


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 700.0 * delta)
	if enemy.data.flying:
		enemy.velocity.y = move_toward(enemy.velocity.y, 0.0, 700.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(&"Special" if behavior().wants_special() else &"Chase")
