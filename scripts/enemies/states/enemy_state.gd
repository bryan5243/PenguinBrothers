class_name EnemyState
extends State
## Base de los estados de enemigo: acceso tipado al enemigo y a su comportamiento.

var enemy: Enemy:
	get:
		return actor as Enemy


func behavior() -> EnemyBehavior:
	return enemy.behavior
