extends RefCounted
## Pruebas de la Fase 3 arcade: bombas con física controlada, área visible y niveles de
## poder 1–4, en la pantalla A del Mundo 1-1. Las ejecuta tests/smoke_test.gd.

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0

var t: Node
var arena: Arena
var p1: Player
var p2: Player
var pool: BombPool


func run(test: Node) -> void:
	t = test
	StageManager.stage = load(STAGE) as StageData
	StageManager.screen_index = 0
	GameManager.start_new_game(GameManager.GameMode.COOP)
	arena = (load(StageManager.stage.screens[0]) as PackedScene).instantiate() as Arena
	for item in arena.get_node("Items").get_children():
		item.free()
	# Sin enemigos: estas pruebas no deben depender de ellos (ver enemy_test.gd).
	for sp in arena.get_node("Spawners").get_children():
		sp.free()
	t.get_tree().root.add_child(arena)
	await t.wait_frames(10)
	p1 = arena.players[0]
	p2 = arena.players[1]
	pool = arena.bomb_pool
	await _controlled_physics()
	await _placement_and_throw_distance()
	await _platforms_and_visuals()
	await _power_levels()
	arena.queue_free()
	await t.wait_frames(2)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE


func _controlled_physics() -> void:
	await _place(p2, Vector2(880, FLOOR_Y))
	var landings: Array[float] = []
	for attempt in 2:
		await _place(p1, Vector2(80, FLOOR_Y))
		var bomb := p1.bombs.throw_new_bomb()
		bomb.fuse_left = 10.0
		var bounces := 0
		var was_up := true
		for i in 150:
			await t.wait_frames(1)
			if bomb.velocity.y < 0.0 and not was_up:
				bounces += 1
			was_up = bomb.velocity.y < 0.0
		landings.append(bomb.global_position.x)
		t.check(bounces <= bomb.max_bounces and is_zero_approx(bomb.velocity.x) and bomb.is_on_floor(),
			"física controlada: bota como mucho %d veces y se detiene (%d botes)" % [bomb.max_bounces, bounces])
		bomb.detonate()
		await t.wait_frames(40)
		p1.health.reset()
	t.check(absf(landings[0] - landings[1]) < 1.0, "el mismo lanzamiento cae siempre en el mismo sitio (%.0f)" % landings[0])


## Colocar deja la bomba quieta aunque se pase por encima; lanzarla la deja cerca y
## lanzarla saltando, solo un poco más lejos.
func _placement_and_throw_distance() -> void:
	await _place(p1, Vector2(120, FLOOR_Y))
	var placed := p1.bombs.place_bomb()
	placed.fuse_left = 10.0
	await t.wait_frames(10)
	var x0 := placed.global_position.x
	Input.action_press("p1_move_right")
	await t.wait_frames(40)
	Input.action_release("p1_move_right")
	await t.wait_frames(10)
	t.check(absf(placed.global_position.x - x0) < 2.0 and p1.global_position.x > x0 + 40.0,
		"la bomba colocada se queda donde se puso aunque se pase por encima")
	placed.detonate()
	await t.wait_frames(40)
	p1.health.reset()
	await _place(p1, Vector2(120, FLOOR_Y))
	await t.wait_frames(int(p1.config.invulnerability_time * 60.0))
	var bomb := p1.bombs.throw_new_bomb()
	bomb.fuse_left = 10.0
	await t.wait_frames(60)
	var standing := bomb.global_position.x - 120.0
	t.check(standing > 40.0 and standing < 130.0 and is_zero_approx(bomb.velocity.x),
		"lanzada de pie cae cerca y se queda (%.0f px)" % standing)
	bomb.detonate()
	await t.wait_frames(40)
	p1.health.reset()
	# Sin las plataformas de encima (la bomba lanzada en alto caería sobre ellas).
	var platforms := arena.get_node("Platforms") as CollisionObject2D
	var layer := platforms.collision_layer
	platforms.collision_layer = 0
	await _place(p1, Vector2(120, FLOOR_Y))
	await t.wait_frames(int(p1.config.invulnerability_time * 60.0))
	Input.action_press("p1_jump")
	await t.wait_frames(14)
	var jump_x := p1.global_position.x
	bomb = p1.bombs.throw_new_bomb()
	bomb.fuse_left = 10.0
	Input.action_release("p1_jump")
	await t.wait_frames(70)
	var jumping := bomb.global_position.x - jump_x
	t.check(jumping > standing and jumping < standing + 90.0,
		"lanzada saltando cae solo un poco más lejos (%.0f px)" % jumping)
	bomb.detonate()
	await t.wait_frames(40)
	p1.health.reset()
	platforms.collision_layer = layer


func _platforms_and_visuals() -> void:
	# Pantalla A: plataforma atravesable de x=24 a 300 a y=560.
	await _place(p1, Vector2(150, 560))
	var bomb := p1.bombs.place_bomb()
	bomb.fuse_left = 10.0
	await t.wait_frames(20)
	t.check(bomb.is_on_floor() and absf(bomb.global_position.y - (560.0 - bomb.data.body_radius)) < 2.0,
		"la bomba se queda sobre la plataforma")
	t.check(bomb.sprite.animation == &"fuse" and bomb.sprite.is_playing(), "mecha animada con los sprites del tipo")
	bomb.detonate()
	var fx := _last_explosion()
	t.check(fx != null and fx.visible and fx._area_time > 0.0 and is_equal_approx(fx.info.radius, bomb.data.explosion_radius),
		"la explosión dibuja su área real (radio %.0f)" % bomb.data.explosion_radius)
	var expected_scale := fx.info.radius * 2.0 / bomb.data.explosion_texture_diameter
	t.check(fx.sprite.sprite_frames == bomb.data.frames and absf(fx.sprite.scale.x - expected_scale) < 0.01,
		"animación de explosión del tipo, escalada a su alcance")
	await t.wait_frames(60)
	p1.health.reset()


func _power_levels() -> void:
	var data := p1.bombs.current_type()
	var base := data.explosion_radius
	var mults := p1.config.bomb_power_radius
	# P2 a una distancia que solo alcanza el nivel 2.
	var distance := base * (1.0 + mults[1]) * 0.5 + p2.config.body_radius
	await _place(p1, Vector2(560, FLOOR_Y))
	await _place(p2, Vector2(560 + distance, FLOOR_Y))
	var hp := p2.health.current_health
	var bomb := p1.bombs.place_bomb()
	bomb.global_position.x = 560.0
	bomb.detonate()
	t.check(p2.health.current_health == hp, "nivel 1: P2 fuera del alcance")
	var levels := [0]
	var on_level := func(i: int, l: int) -> void: if i == 0: levels[0] = l
	EventBus.bomb_level_changed.connect(on_level)
	t.check(p1.bombs.level_up() and p1.bombs.power_level == 2 and levels[0] == 2, "sube a BOMB LEVEL 2")
	t.check(arena.hud.get_lives_text(0).ends_with("Lv2"), "el HUD muestra el nivel de bomba")
	await t.wait_frames(int(p1.config.invulnerability_time * 60.0))
	p1.health.reset()
	await _place(p1, Vector2(560, FLOOR_Y))
	await _place(p2, Vector2(560 + distance, FLOOR_Y))
	bomb = p1.bombs.place_bomb()
	bomb.global_position.x = 560.0
	t.check(is_equal_approx(bomb.radius_multiplier, mults[1]), "la bomba lleva el alcance del nivel 2")
	bomb.detonate()
	t.check(p2.health.current_health < hp, "nivel 2: mayor alcance, ahora sí alcanza a P2")
	p1.bombs.set_power_level(4)
	bomb = p1.bombs.place_bomb()
	var info := bomb.make_explosion_info()
	t.check(info.power_level == 4 and info.damage == data.damage + data.special_damage_bonus
		and info.break_power == data.break_power + data.special_break_bonus
		and is_equal_approx(info.radius, base * mults[3]), "BOMB LEVEL 4: poder especial (más daño, rompe lo duro, alcance x%.1f)" % mults[3])
	bomb._go_to_pool()
	t.check(not p1.bombs.level_up(), "el nivel máximo es 4")
	p1.health.kill(null)
	await t.wait_frames(3)
	t.check(p1.bombs.power_level == 1 and levels[0] == 1, "al perder una vida el poder vuelve al nivel 1")
	EventBus.bomb_level_changed.disconnect(on_level)
	await t.wait_frames(int(p1.config.respawn_delay * 60.0) + 10)


func _last_explosion() -> Explosion:
	for child in pool.get_children():
		var fx := child as Explosion
		if fx and fx.active:
			return fx
	return null


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
