extends EnemyState
## CHASE: va a por el jugador vivo más cercano (usando plataformas) y ataca al tenerlo a tiro.


func physics_update(delta: float) -> void:
	var target := enemy.find_target()
	if target == null:
		transition_to(&"Patrol")
		return
	if behavior().wants_special():
		transition_to(&"Special")
		return
	if behavior().can_attack(target):
		transition_to(&"Attack", {"target": target})
		return
	behavior().chase(delta, target)
