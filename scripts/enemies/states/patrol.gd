extends EnemyState
## PATROL: recorre su piso (o vuela de pared a pared) hasta ver a un jugador.
## Los enemigos de suelo hacen pausas cortas (Idle) de vez en cuando.

var _timer := 0.0


func enter(_message := {}) -> void:
	_timer = enemy.rng.randf_range(2.5, 5.0)


func physics_update(delta: float) -> void:
	behavior().patrol(delta)
	if behavior().wants_special():
		transition_to(&"Special")
		return
	if enemy.find_target():
		transition_to(&"Chase")
		return
	_timer -= delta
	if _timer <= 0.0 and not enemy.data.flying and enemy.is_on_floor():
		transition_to(&"Idle")
