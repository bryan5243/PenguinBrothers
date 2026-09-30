extends EnemyState
## IDLE: quieto un momento; si ve a un jugador lo persigue, si no vuelve a patrullar.

var _timer := 0.0


func enter(_message := {}) -> void:
	var r := enemy.data.idle_time
	_timer = enemy.rng.randf_range(r.x, r.y)
	if not enemy.data.flying:
		enemy.velocity.x = 0.0
	enemy.play(&"idle")


func physics_update(delta: float) -> void:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 900.0 * delta)
	if enemy.spawn_grace > 0.0:
		return
	if behavior().wants_special():
		transition_to(&"Special")
		return
	if enemy.data.flying or enemy.find_target():
		transition_to(&"Chase" if enemy.find_target() else &"Patrol")
		return
	_timer -= delta
	if _timer <= 0.0:
		transition_to(&"Patrol")
