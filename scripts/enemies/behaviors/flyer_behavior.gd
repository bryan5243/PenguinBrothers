class_name FlyerBehavior
extends EnemyBehavior
## Gaviota: vuela de pared a pared a su altura de crucero (con un leve vaivén) y, cuando
## tiene a un jugador debajo, cae en picado hacia él; luego vuelve a subir a su altura.
## No usa gravedad ni plataformas (solo choca con el mundo sólido).

var cruise_y := 0.0
var _dive_dir := Vector2.DOWN
var _dive_time := 0.0
var _t := 0.0


func setup() -> void:
	cruise_y = enemy.global_position.y


func patrol(delta: float) -> void:
	_t += delta
	if enemy.wall_ahead(enemy.facing):
		enemy.facing = -enemy.facing
	enemy.velocity.x = enemy.facing * data.speed
	var dy := cruise_y - enemy.global_position.y
	if absf(dy) > 6.0:
		enemy.velocity.y = clampf(dy * 4.0, -data.dive_return_speed, data.dive_return_speed)
	else:
		enemy.velocity.y = sin(_t * 3.0) * 18.0
	enemy.play(&"walk")


func can_attack(target: Player) -> bool:
	var dx := absf(target.global_position.x - enemy.global_position.x)
	var below := target.global_position.y - enemy.global_position.y
	return enemy.attack_cooldown <= 0.0 and below > 40.0 and dx <= data.dive_trigger_width \
		and absf(enemy.global_position.y - cruise_y) < 12.0


func start_attack(target: Player) -> void:
	_dive_time = 0.0
	var aim := target.global_position + Vector2(0, -24) - enemy.global_position
	_dive_dir = aim.normalized() if aim.length() > 1.0 else Vector2.DOWN
	enemy.facing = signi(int(signf(_dive_dir.x))) if absf(_dive_dir.x) > 0.1 else enemy.facing
	enemy.play(&"attack", true)


func attack(delta: float, _target: Player) -> bool:
	_dive_time += delta
	enemy.velocity = _dive_dir * data.dive_speed
	if enemy.is_on_floor() or enemy.is_on_wall() or enemy.is_on_ceiling() or _dive_time > 1.4:
		enemy.velocity = Vector2.ZERO
		enemy.attack_cooldown = data.attack_cooldown
		return true
	return false
