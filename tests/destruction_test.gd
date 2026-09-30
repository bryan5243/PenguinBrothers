extends RefCounted
## Pruebas de la Fase 4 arcade: barriles (recoger, llevar, lanzar como arma, romper),
## objetos destruibles con dureza y botín, y power-ups. Las ejecuta tests/smoke_test.gd.

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0
const FIRE := "res://data/powerups/fire.tres"

var t: Node
var arena: Arena
var p1: Player
var p2: Player
var items: Node


func run(test: Node) -> void:
	t = test
	StageManager.stage = load(STAGE) as StageData
	StageManager.screen_index = 0
	GameManager.start_new_game(GameManager.GameMode.COOP)
	arena = (load(StageManager.stage.screens[0]) as PackedScene).instantiate() as Arena
	t.get_tree().root.add_child(arena)
	await t.wait_frames(10)
	p1 = arena.players[0]
	p2 = arena.players[1]
	items = arena.get_node("Items")
	await _place(p2, Vector2(880, FLOOR_Y))
	_data_and_drop_table()
	await _barrel_as_weapon()
	await _power_up_pickup()
	await _destructibles()
	await _barrel_breaks()
	await _power_up_effects()
	arena.queue_free()
	await t.wait_frames(2)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE


func _data_and_drop_table() -> void:
	var barrels := 0
	var crates := 0
	for n in items.get_children():
		if n is Barrel:
			barrels += 1
		elif n is Destructible:
			crates += 1
	t.check(barrels >= 2 and crates >= 2, "la pantalla A tiene barriles y objetos destruibles")
	var crate := load("res://data/destructibles/crate.tres") as DestructibleData
	t.check(crate.max_health > 0 and crate.drop_table != null and crate.texture != null and crate.hardness == 1,
		"DestructibleData: health, destructible, drop_table y efecto")
	var table := load("res://data/drops/barrel_drops.tres") as DropTable
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 7
	b.seed = 7
	var ra := table.roll(a)
	var rb := table.roll(b)
	t.check(ra.size() == rb.size() and (ra.is_empty() or ra[0] == rb[0]), "el botín es reproducible con la misma semilla")


func _barrel_as_weapon() -> void:
	var barrel := _first(Barrel) as Barrel
	barrel.data = barrel.data.duplicate() as BarrelData
	barrel.data.drop_table = _only(load(FIRE) as PowerUpData)
	await _place(p1, Vector2(barrel.global_position.x - 40.0, FLOOR_Y))
	await _press("p1_interact")
	t.check(p1.bombs.held_object == barrel and barrel.is_held(), "E recoge el barril")
	await t.wait_frames(40)
	t.check(p1.animator.animation == &"carry", "lo lleva con la animación de carga")
	var enemy := _DummyEnemy.new()
	enemy.position = Vector2(barrel.global_position.x + 100.0, FLOOR_Y - 20.0)
	arena.enemies.add_child(enemy)
	await t.wait_frames(2)
	var score := ScoreManager.scores[0]
	var damage := barrel.data.hit_damage
	await _press("p1_interact")
	var hit := false
	for i in 60:
		await t.wait_frames(1)
		if enemy.damage_taken > 0:
			hit = true
			break
	t.check(hit and enemy.damage_taken == damage, "el barril lanzado rueda y golpea al enemigo (arma)")
	await t.wait_frames(2)
	t.check(not is_instance_valid(barrel) or barrel.is_broken, "el barril se rompe al golpear")
	t.check(ScoreManager.scores[0] > score, "puntos por romper el barril")
	t.check(_power_ups().size() == 1 and _power_ups()[0].data.id == &"fire", "suelta su botín (power-up)")
	enemy.queue_free()


func _power_up_pickup() -> void:
	var pu: PowerUp = _power_ups()[0]
	await t.wait_frames(40)
	t.check(pu.global_position.y > FLOOR_Y - 40.0, "el power-up cae hasta el suelo")
	var level := p1.bombs.power_level
	p1.global_position = pu.global_position + Vector2(0, 20)
	await t.wait_frames(4)
	t.check(not is_instance_valid(pu) and p1.bombs.power_level == level + 1, "recoger «fuego» sube el nivel de bomba")


func _destructibles() -> void:
	var crate := _first(Destructible, &"crate") as Destructible
	crate.data = crate.data.duplicate() as DestructibleData
	crate.data.drop_table = _only(load("res://data/powerups/cherry.tres") as PowerUpData)
	var before := _power_ups().size()
	var score := ScoreManager.scores[0]
	var info := _explosion_at(crate.global_position, 1)
	crate.apply_explosion(info)
	await t.wait_frames(2)
	t.check(not is_instance_valid(crate), "una bomba rompe la caja")
	t.check(ScoreManager.scores[0] > score and _power_ups().size() == before + 1, "puntos y botín de la caja")
	var block := _first(Destructible, &"stone_block") as Destructible
	block.apply_explosion(_explosion_at(block.global_position, 1))
	t.check(is_instance_valid(block) and not block.is_broken and block.health == block.data.max_health,
		"el bloque de piedra resiste las bombas normales (dureza 2)")
	t.check(not block.take_damage(5, null), "y los golpes directos")
	block.apply_explosion(_explosion_at(block.global_position, 4))
	await t.wait_frames(2)
	t.check(not is_instance_valid(block), "BOMB LEVEL 4 rompe el bloque de piedra")
	for pu in _power_ups():
		pu.queue_free()
	await t.wait_frames(2)


func _barrel_breaks() -> void:
	var barrel := _first(Barrel) as Barrel
	barrel.data = barrel.data.duplicate() as BarrelData
	barrel.data.drop_table = null
	barrel.apply_explosion(_explosion_at(barrel.global_position, 1))
	await t.wait_frames(2)
	t.check(not is_instance_valid(barrel), "las explosiones rompen los barriles")
	var scene := load("res://scenes/objects/Barrel.tscn") as PackedScene
	var b2 := scene.instantiate() as Barrel
	b2.position = Vector2(700, FLOOR_Y - 20)
	items.add_child(b2)
	b2.data = b2.data.duplicate() as BarrelData
	b2.data.drop_table = null
	await t.wait_frames(2)
	b2.on_thrown(0)
	b2.launch(Vector2(b2.data.break_speed + 150.0, -40.0))
	await t.wait_frames(60)
	t.check(not is_instance_valid(b2), "lanzado con fuerza contra la pared, se rompe")


func _power_up_effects() -> void:
	await _place(p1, Vector2(600, FLOOR_Y))
	var hp := p1.health.current_health
	var armor := load("res://data/powerups/armor.tres") as PowerUpData
	t.check(p1.apply_power_up(armor) and p1.armor_hits == 1 and p1._armor_visual.visible,
		"armadura: protección visual alrededor del pingüino")
	t.check(not p1.take_damage(1, null) and p1.health.current_health == hp and p1.armor_hits == 0
		and not p1._armor_visual.visible, "la armadura absorbe un golpe y desaparece")
	var boots := (load("res://data/powerups/boots.tres") as PowerUpData).duplicate() as PowerUpData
	boots.duration = 0.3
	p1.apply_power_up(boots)
	Input.action_press("p1_move_left")
	await t.wait_frames(6)
	t.check(absf(p1.velocity.x) > p1.config.move_speed * 1.3, "botas: más velocidad")
	await t.wait_frames(20)
	Input.action_release("p1_move_left")
	t.check(is_equal_approx(p1.speed_multiplier, 1.0), "el efecto de las botas se acaba")
	var lives := GameManager.lives[0]
	p1.apply_power_up(load("res://data/powerups/one_up.tres") as PowerUpData)
	t.check(GameManager.lives[0] == lives + 1, "1UP: vida extra")
	var fruit := PowerUp.spawn(load("res://data/powerups/melon.tres") as PowerUpData, Vector2(300, 600), items)
	var score := ScoreManager.scores[1]
	await _place(p2, Vector2(300, FLOOR_Y))
	await t.wait_frames(30)
	t.check(not is_instance_valid(fruit) and ScoreManager.scores[1] == score + 2000, "fruta: puntos para quien la recoge (P2)")
	var short := (load("res://data/powerups/cherry.tres") as PowerUpData).duplicate() as PowerUpData
	short.lifetime = 0.3
	var gone := PowerUp.spawn(short, Vector2(800, 300), items)
	await t.wait_frames(40)
	t.check(not is_instance_valid(gone), "si nadie lo recoge, desaparece")


# ---------------------------------------------------------------- utilidades
func _explosion_at(at: Vector2, level: int) -> ExplosionInfo:
	var data := p1.config.bomb_types[0]
	var info := ExplosionInfo.from_bomb(data, at, level, 1.0, 0, null)
	if level >= Explosion.SPECIAL_LEVEL:
		info.damage += data.special_damage_bonus
		info.break_power += data.special_break_bonus
	return info


func _only(item: PowerUpData) -> DropTable:
	var table := DropTable.new()
	table.items = [item] as Array[PowerUpData]
	table.drop_chance = 1.0
	return table


func _first(kind: Variant, id: StringName = &"") -> Node:
	for n in items.get_children():
		if is_instance_of(n, kind) and not n.is_queued_for_deletion():
			if id == &"" or (n.get("data") and n.data.id == id):
				return n
	return null


func _power_ups() -> Array:
	var out := []
	for n in items.get_children():
		if n is PowerUp and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _press(action: StringName) -> void:
	Input.action_press(action)
	await t.wait_frames(2)
	Input.action_release(action)
	await t.wait_frames(2)


func _place(pl: Player, pos: Vector2) -> void:
	for prefix in ["p1_", "p2_"]:
		for c in InputManager.COMMANDS:
			Input.action_release(prefix + c)
	pl.global_position = pos
	pl.velocity = Vector2.ZERO
	pl.facing = 1
	pl.set_low_profile(false)
	pl.state_machine.transition_to(&"Fall")
	for i in 60:
		if pl.is_on_floor() and pl.state_machine.is_in(&"Idle"):
			break
		await t.wait_frames(1)
	await t.wait_frames(2)


## Enemigo mínimo (capa de enemigos) para comprobar el golpe del barril.
class _DummyEnemy extends StaticBody2D:
	signal defeated
	var damage_taken := 0

	func _init() -> void:
		add_to_group(&"enemies")
		collision_layer = 1 << 2
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 40)
		cs.shape = rect
		add_child(cs)

	func take_damage(amount: int, _source: Node = null) -> bool:
		damage_taken += amount
		return true
