extends EnemyState
## SPECIAL: acción propia del tipo de enemigo (el ermitaño se esconde en el caparazón).


func physics_update(delta: float) -> void:
	if behavior().special(delta):
		transition_to(&"Chase")
