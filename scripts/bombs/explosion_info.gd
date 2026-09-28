class_name ExplosionInfo
extends RefCounted
## Datos de UNA explosión concreta (tipo de bomba + nivel de poder de quien la lanzó).
## Explosion la pasa a todo lo alcanzado: apply_explosion(info).

var center := Vector2.ZERO
var radius := 96.0
var damage := 1
var knockback := 420.0
var break_power := 1
var hurts_players := true
## Nivel de poder de la bomba (1–4).
var power_level := 1
## Jugador que la puso (para puntos y combos), -1 si nadie.
var owner_index := -1
var data: BombData
## Nodo que explotó (la bomba), o null.
var source: Node


static func from_bomb(bomb_data: BombData, at: Vector2, level: int, radius_multiplier: float,
		bomb_owner: int, source_node: Node) -> ExplosionInfo:
	var info := ExplosionInfo.new()
	info.data = bomb_data
	info.center = at
	info.power_level = level
	info.radius = bomb_data.explosion_radius * radius_multiplier
	info.damage = bomb_data.damage
	info.knockback = bomb_data.knockback
	info.break_power = bomb_data.break_power
	info.hurts_players = bomb_data.hurts_players
	info.owner_index = bomb_owner
	info.source = source_node
	return info


## Dirección hacia fuera de la explosión para un punto (arriba si coincide con el centro).
func push_direction(point: Vector2) -> Vector2:
	var d := point - center
	return d.normalized() if d.length() > 0.5 else Vector2.UP
