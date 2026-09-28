extends RefCounted
## Pruebas del sistema de bombas (Fase 4) sobre el nivel de prueba.
## Las ejecuta tests/smoke_test.gd; `t` es el nodo de prueba (check, wait_frames).

const TEST_LEVEL := "res://scenes/worlds/test_level/PlayerTestLevel.tscn"
const GROUND_Y := 640.0

var t: Node
var level: Node
var p: Player
var pool: BombPool


func run(test: Node) -> void:
	t = test
	_data()
	GameManager.start_new_game(GameManager.GameMode.SOLO)
	level = (load(TEST_LEVEL) as PackedScene).instantiate()
	t.get_tree().root.add_child(level)
	await t.wait_frames(10)
	p = level.player
	pool = level.get_node("BombPool") as BombPool
	t.check(pool != null and pool.size() == pool.initial_bombs, "el nivel tiene un BombPool precargado")
	t.check(p.bombs.current_type() != null and p.bombs.current_type().id == &"blue", "bomba inicial: azul")

	await _throw_and_limit()
	await _explode_and_reuse()
	await _place_pick_carry_throw()
	await _drop_and_kick()
	await _switch_type()
	await _damage_and_chain()
	await _player_knockback()

	level.queue_free()
	await t.wait_frames(2)


func _data() -> void:
	var blue := load("res://data/bombs/blue_bomb.tres") as BombData
	var green := load("res://data/bombs/green_bomb.tres") as BombData
	var black := load("res://data/bombs/black_bomb.tres") as BombData
	t.check(blue != null and green != null and black != null, "tipos de bomba como datos (.tres)")
	t.check(blue.damage < green.damage and green.damage < black.damage, "daño: azul < verde < negra")
	t.check(blue.explosion_radius < green.explosion_radius and green.explosion_radius < black.explosion_radius,
		"radio: azul < verde < negra")
	t.check(blue.texture != null and green.texture != null and black.texture != null, "cada tipo tiene su sprite")


func _throw_and_limit() -> void:
	await _place(p, Vector2(300, GROUND_Y))
	await _press("p1_bomb")
	var active := pool.active_bombs()
	t.check(active.size() == 1 and active[0].owner_index == 0, "Q lanza una bomba del jugador 1")
	var bomb := active[0]
	t.check(bomb.linear_velocity.x > 200.0 and bomb.linear_velocity.y < 0.0, "sale hacia delante y hacia arriba")
	t.check(p.animator.animation == &"throw", "animación de lanzar")
	for i in 4:
		await _press("p1_bomb")
	t.check(pool.count_active(0) == p.config.max_active_bombs, "límite de %d bombas en juego" % p.config.max_active_bombs)
	await t.wait_frames(30)
	t.check(bomb.global_position.x > 380.0 and bomb.global_position.y <= GROUND_Y, "la bomba vuela, cae y rueda con física")


func _explode_and_reuse() -> void:
	var exploded := [0]
	var on_exploded := func(_pos: Vector2, _r: float, _o: int) -> void: exploded[0] += 1
	EventBus.bomb_exploded.connect(on_exploded)
	var size_before := pool.size()
	await t.wait_frames(int(p.bombs.current_type().fuse_time * 60.0) + 20)
	t.check(exploded[0] >= p.config.max_active_bombs and pool.count_active(0) == 0,
		"las bombas explotan al acabar la mecha y vuelven al pool")
	EventBus.bomb_exploded.disconnect(on_exploded)
	await _press("p1_bomb")
	t.check(pool.size() == size_before, "las bombas se reutilizan (pooling)")
	await _clear_bombs()


func _place_pick_carry_throw() -> void:
	await _place(p, Vector2(300, GROUND_Y))
	Input.action_press("p1_crouch")
	await t.wait_frames(3)
	await _press("p1_bomb")
	Input.action_release("p1_crouch")
	var active := pool.active_bombs()
	t.check(active.size() == 1, "abajo + Q coloca una bomba")
	var bomb := active[0]
	await t.wait_frames(20)
	t.check(absf(bomb.global_position.x - (300.0 + p.config.bomb_place_distance)) < 6.0
		and absf(bomb.global_position.y - (GROUND_Y - bomb.data.body_radius)) < 3.0,
		"queda quieta en el suelo delante de los pies")
	await _press("p1_interact")
	t.check(p.bombs.held_bomb == bomb and bomb.state == Bomb.State.HELD and p.carried_object == bomb,
		"E recoge la bomba")
	await t.wait_frames(40)
	t.check(p.animator.animation == &"carry", "animación de llevar")
	Input.action_press("p1_move_right")
	await t.wait_frames(20)
	Input.action_release("p1_move_right")
	t.check(bomb.global_position.distance_to(p.bombs.hold_position()) < 1.0, "la bomba sigue a las manos")
	await _press("p1_interact")
	t.check(p.bombs.held_bomb == null and bomb.state == Bomb.State.ARMED and bomb.linear_velocity.x > 200.0,
		"E la lanza")
	await _clear_bombs()


func _drop_and_kick() -> void:
	await _place(p, Vector2(300, GROUND_Y))
	var bomb := p.bombs.place_bomb()
	await t.wait_frames(15)
	p.bombs.try_pick_up()
	Input.action_press("p1_crouch")
	await t.wait_frames(3)
	await _press("p1_interact")
	Input.action_release("p1_crouch")
	t.check(p.bombs.held_bomb == null and absf(bomb.linear_velocity.x) < 120.0, "abajo + E la suelta suavemente")
	await t.wait_frames(20)
	await _place(p, Vector2(bomb.global_position.x - 90.0, GROUND_Y))
	bomb.fuse_left = 5.0
	Input.action_press("p1_move_right")
	var kicked := false
	for i in 50:
		await t.wait_frames(1)
		if bomb.linear_velocity.x > p.config.kick_speed * 0.6:
			kicked = true
			break
	Input.action_release("p1_move_right")
	t.check(kicked, "caminar contra una bomba la patea")
	await _clear_bombs()


func _switch_type() -> void:
	var changed := [&""]
	var on_changed := func(_i: int, id: StringName) -> void: changed[0] = id
	EventBus.bomb_type_changed.connect(on_changed)
	await _press("p1_switch_bomb")
	t.check(p.bombs.current_type().id == &"green" and changed[0] == &"green", "R cambia a la bomba verde")
	await _press("p1_switch_bomb")
	await _press("p1_switch_bomb")
	t.check(p.bombs.current_type().id == &"blue", "el cambio es cíclico")
	p.bombs.ammo[&"green"] = 0
	await _press("p1_switch_bomb")
	t.check(p.bombs.current_type().id == &"black", "se salta los tipos sin munición")
	p.bombs.ammo[&"green"] = -1
	p.bombs.current_index = 0
	EventBus.bomb_type_changed.disconnect(on_changed)


func _damage_and_chain() -> void:
	var near := level.get_node("TestTarget640") as TestTarget
	var far := level.get_node("TestTarget2450") as TestTarget
	near.health.reset()
	far.health.reset()
	await _place(p, Vector2(450, GROUND_Y))
	var data := p.bombs.current_type()
	var a := pool.acquire_bomb(data, 0)
	a.arm_at(Vector2(600, GROUND_Y - 13))
	var b := pool.acquire_bomb(data, 0)
	b.arm_at(Vector2(600 - data.explosion_radius * 0.6, GROUND_Y - 13))
	await t.wait_frames(5)
	a.detonate()
	t.check(near.health.current_health == near.max_health - data.damage, "la explosión daña lo que está en su radio")
	t.check(far.health.current_health == far.max_health, "no daña fuera del radio")
	t.check(b.state == Bomb.State.ARMED, "la bomba cercana aún no explota (retraso de cadena)")
	await t.wait_frames(int(data.chain_delay * 60.0) + 4)
	t.check(b.state == Bomb.State.POOLED, "reacción en cadena")
	await t.wait_frames(10)


func _player_knockback() -> void:
	await _place(p, Vector2(400, GROUND_Y))
	var hp := p.health.current_health
	var data := p.bombs.current_type()
	t.check(data.hurts_players, "arcade: las bombas también dañan a los jugadores")
	var bomb := pool.acquire_bomb(data, 0)
	bomb.arm_at(Vector2(370, GROUND_Y - 13))
	await t.wait_frames(2)
	bomb.detonate()
	t.check(p.health.current_health == hp - data.damage and p.velocity.x > 0.0,
		"la explosión daña y empuja al jugador (también al compañero)")
	var push_only := data.duplicate() as BombData
	push_only.hurts_players = false
	await _place(p, Vector2(400, GROUND_Y))
	await t.wait_frames(int(p.config.invulnerability_time * 60.0))
	hp = p.health.current_health
	bomb = pool.acquire_bomb(push_only, 0)
	bomb.arm_at(Vector2(370, GROUND_Y - 13))
	await t.wait_frames(2)
	bomb.detonate()
	t.check(p.velocity.x > 100.0 and p.velocity.y < 0.0 and p.health.current_health == hp,
		"un tipo sin hurts_players solo empuja")
	p.health.reset()
	await _place(p, Vector2(300, GROUND_Y))
	var held := p.bombs.place_bomb()
	await t.wait_frames(10)
	p.bombs.try_pick_up()
	held.detonate()
	t.check(p.bombs.held_bomb == null and not p.animator.carrying, "si explota en las manos, deja de llevarla")
	await t.wait_frames(60)


# ---------------------------------------------------------------- utilidades
func _press(action: StringName) -> void:
	Input.action_press(action)
	await t.wait_frames(2)
	Input.action_release(action)
	await t.wait_frames(2)


func _clear_bombs() -> void:
	for b in pool.active_bombs():
		if b.state == Bomb.State.HELD:
			p.bombs.drop_held()
		b._go_to_pool()
	await t.wait_frames(2)


func _place(pl: Player, pos: Vector2) -> void:
	for a in InputManager.COMMANDS:
		Input.action_release("p1_" + a)
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
