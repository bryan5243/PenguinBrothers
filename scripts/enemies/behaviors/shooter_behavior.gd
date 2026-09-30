class_name ShooterBehavior
extends WalkerBehavior
## Pulpo pequeño: avanza despacio por su piso y, si ve a un jugador en el mismo piso, se
## gira y le lanza tinta en línea recta (InkProjectile). No persigue de cerca: guarda distancia.

const INK_SCRIPT := preload("res://scripts/enemies/ink_projectile.gd")

var _fired := false


func chase(delta: float, target: Player) -> void:
	var dx := target.global_position.x - enemy.global_position.x
	var dy := _target_floor(target) - enemy.global_position.y
	if absf(dy) < SAME_FLOOR:
		enemy.apply_gravity(delta)
		if absf(dx) > TURN_DEADZONE:
			enemy.turn_to(signi(int(signf(dx))))
		# Mantiene la distancia de disparo: se acerca solo si está lejos.
		var far := absf(dx) > data.projectile_range * 0.6
		var blocked := enemy.is_on_floor() and not enemy.ground_ahead(enemy.facing)
		enemy.velocity.x = enemy.facing * data.speed if far and not blocked else 0.0
		enemy.play(&"walk" if enemy.velocity.x != 0.0 else &"idle")
	else:
		patrol(delta)


func can_attack(target: Player) -> bool:
	var dx := absf(target.global_position.x - enemy.global_position.x)
	var dy := absf(target.global_position.y - enemy.global_position.y)
	return enemy.is_on_floor() and enemy.attack_cooldown <= 0.0 and dy < SAME_FLOOR * 0.8 \
		and dx <= data.projectile_range * 0.8


func start_attack(target: Player) -> void:
	_fired = false
	super.start_attack(target)


func attack(delta: float, _target: Player) -> bool:
	enemy.apply_gravity(delta)
	enemy.velocity.x = 0.0
	_attack_time += delta
	if not _fired and _attack_time >= data.attack_hit_time:
		_fired = true
		_shoot()
	if _attack_time >= data.attack_duration:
		enemy.attack_cooldown = data.attack_cooldown
		return true
	return false


func _shoot() -> void:
	var ink := Area2D.new()
	ink.set_script(INK_SCRIPT)
	ink.set("direction", enemy.facing)
	ink.set("speed", data.projectile_speed)
	ink.set("max_distance", data.projectile_range)
	ink.set("damage", data.damage)
	ink.set("texture", data.projectile_texture)
	ink.position = enemy.global_position + Vector2(enemy.facing * (data.body_size.x * 0.5 + 6.0), -data.body_size.y * 0.55)
	enemy.get_parent().add_child(ink)
	AudioManager.play_sfx("bomb_throw", 0.7)
