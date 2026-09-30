class_name ShellBehavior
extends WalkerBehavior
## Cangrejo ermitaño: como el cangrejo, pero se esconde en su caparazón cuando hay una bomba
## encendida cerca o justo después de recibir un golpe. Escondido no hace daño por contacto y
## el caparazón absorbe `shell_armor` de cada golpe (una bomba pequeña no le hace nada).

var in_shell := false
var _shell_time := 0.0
var _shell_cooldown := 0.0
var _hurt_trigger := false


func patrol(delta: float) -> void:
	_shell_cooldown = maxf(0.0, _shell_cooldown - delta)
	super.patrol(delta)


func chase(delta: float, target: Player) -> void:
	_shell_cooldown = maxf(0.0, _shell_cooldown - delta)
	super.chase(delta, target)


func wants_special() -> bool:
	if _hurt_trigger:
		return true
	if _shell_cooldown > 0.0 or not enemy.is_on_floor():
		return false
	for node in enemy.get_tree().get_nodes_in_group(CarryableBody.GROUP):
		var bomb := node as Bomb
		if bomb and bomb.state == Bomb.State.ARMED \
				and bomb.global_position.distance_to(enemy.global_position) <= data.shell_trigger_range:
			return true
	return false


func special(delta: float) -> bool:
	if not in_shell:
		in_shell = true
		_hurt_trigger = false
		_shell_time = data.shell_time
		enemy.play(&"special", true)
	enemy.apply_gravity(delta)
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 900.0 * delta)
	_shell_time -= delta
	if _shell_time <= 0.0:
		in_shell = false
		_shell_cooldown = 1.0
		return true
	return false


func on_hurt() -> void:
	_hurt_trigger = true


func modify_damage(amount: int, _source: Node) -> int:
	return amount - data.shell_armor if in_shell else amount


func on_blocked() -> void:
	AudioManager.play_sfx("hit")


func deals_contact_damage() -> bool:
	return not in_shell
