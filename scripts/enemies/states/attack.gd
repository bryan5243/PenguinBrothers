extends EnemyState
## ATTACK: pinza, picado o tinta, según el comportamiento. Al terminar vuelve a perseguir.

var _target: Player


func enter(message := {}) -> void:
	_target = message.get("target") as Player
	if _target == null or not is_instance_valid(_target):
		_target = enemy.find_target()
	if _target == null:
		transition_to.call_deferred(&"Patrol")
		return
	behavior().start_attack(_target)


func physics_update(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		transition_to(&"Patrol")
		return
	if behavior().attack(delta, _target):
		transition_to(&"Chase")
