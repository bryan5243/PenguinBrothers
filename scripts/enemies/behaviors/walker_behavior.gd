class_name WalkerBehavior
extends EnemyBehavior
## Enemigo de suelo (cangrejo): patrulla su piso dando la vuelta en paredes y bordes;
## persigue al jugador más cercano. Si el jugador está en otro piso usa las plataformas:
## baja de las atravesables (o se deja caer por el borde) y salta al piso de arriba.
## Ataca con la pinza a corta distancia.

## Diferencia de altura (px) para considerar que el jugador está en el mismo piso.
const SAME_FLOOR := 44.0
## Altura máxima de una plataforma que intenta alcanzar saltando.
const JUMP_REACH := 130.0

## Distancia horizontal mínima para girarse hacia el jugador (evita temblar debajo/encima).
const TURN_DEADZONE := 20.0

var _attack_time := 0.0
var _hit_done := false
var _jump_cooldown := 0.0
## Altura del piso donde estaba el jugador la última vez que pisó suelo: si salta, el enemigo
## no cambia de plan a cada momento.
var _target_floor_y := INF
var _target_ref: Player


func patrol(delta: float) -> void:
	enemy.apply_gravity(delta)
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if enemy.is_on_floor() and (enemy.wall_ahead(enemy.facing) or not enemy.ground_ahead(enemy.facing)
			or (enemy.turn_timer <= 0.0 and enemy.enemy_ahead(enemy.facing))):
		enemy.facing = -enemy.facing
		enemy.turn_timer = Enemy.TURN_DELAY
	enemy.velocity.x = enemy.facing * data.speed
	enemy.play(&"walk")


func chase(delta: float, target: Player) -> void:
	enemy.apply_gravity(delta)
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	var dx := target.global_position.x - enemy.global_position.x
	var dy := _target_floor(target) - enemy.global_position.y
	if absf(dx) > TURN_DEADZONE:
		enemy.turn_to(signi(int(signf(dx))))
	var dir := enemy.facing
	var speed := _chase_speed()
	var on_floor := enemy.is_on_floor()
	if dy > SAME_FLOOR:
		# Jugador más abajo: bajar por la plataforma o dejarse caer por el borde.
		if on_floor and data.can_drop_through and absf(dx) < 60.0 and enemy.on_one_way_platform():
			enemy.drop_through()
		enemy.velocity.x = dir * speed
	elif dy < -SAME_FLOOR:
		# Jugador más arriba: saltar si hay plataforma encima; si no, buscarla patrullando.
		if on_floor and data.jump_force > 0.0 and _jump_cooldown <= 0.0 and _platform_above():
			enemy.velocity.y = -data.jump_force
			_jump_cooldown = 1.2
		if on_floor and (enemy.wall_ahead(enemy.facing) or not enemy.ground_ahead(enemy.facing)):
			enemy.facing = -enemy.facing
		enemy.velocity.x = enemy.facing * data.speed
	else:
		# Mismo piso: ir hacia él sin caerse del borde.
		var blocked := on_floor and not enemy.ground_ahead(dir)
		enemy.velocity.x = 0.0 if blocked or absf(dx) < TURN_DEADZONE * 0.5 else dir * speed
	enemy.play(&"run" if absf(enemy.velocity.x) > data.speed + 1.0 else &"walk")


func can_attack(target: Player) -> bool:
	var dx := absf(target.global_position.x - enemy.global_position.x)
	var dy := absf(target.global_position.y - enemy.global_position.y)
	return enemy.is_on_floor() and enemy.attack_cooldown <= 0.0 and dx <= data.attack_range and dy < SAME_FLOOR * 0.8


func start_attack(target: Player) -> void:
	_attack_time = 0.0
	_hit_done = false
	enemy.velocity.x = 0.0
	enemy.facing = signi(int(signf(target.global_position.x - enemy.global_position.x)))
	enemy.play(&"attack", true)


func attack(delta: float, _target: Player) -> bool:
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 900.0 * delta)
	_attack_time += delta
	if not _hit_done and _attack_time >= data.attack_hit_time:
		_hit_done = true
		enemy.strike(data.attack_range + 12.0)
	if _attack_time >= data.attack_duration:
		enemy.attack_cooldown = data.attack_cooldown
		return true
	return false


## Altura «de piso» del jugador: la real si está en el suelo; si está en el aire, la del último
## suelo que pisó.
func _target_floor(target: Player) -> float:
	if target != _target_ref:
		_target_ref = target
		_target_floor_y = target.global_position.y
	if target.is_on_floor() or _target_floor_y == INF:
		_target_floor_y = target.global_position.y
	return _target_floor_y


func _chase_speed() -> float:
	return data.chase_speed


## ¿Hay una plataforma atravesable encima, al alcance del salto?
func _platform_above() -> bool:
	var from := enemy.global_position + Vector2(0, -data.body_size.y - 4.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, -JUMP_REACH), 1 << 5)
	return not enemy.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
