extends RefCounted
## Pruebas de la Fase 5 arcade: enemigos del Mundo 1 (estados, comportamientos, uso de
## plataformas, daño, puntos/combos, botín) y EnemySpawner (entradas, oleadas, pantalla limpia).
## Las ejecuta tests/smoke_test.gd.

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0
const IDS := ["small_crab", "hermit_crab", "seagull", "small_octopus"]
const STATES := [&"Idle", &"Patrol", &"Chase", &"Attack", &"Hurt", &"Dead", &"Special"]

var t: Node
var arena: Arena
var p1: Player
var p2: Player


func run(test: Node) -> void:
	t = test
	_data()
	StageManager.stage = load(STAGE) as StageData
	StageManager.screen_index = 0
	GameManager.start_new_game(GameManager.GameMode.COOP)
	arena = (load(StageManager.stage.screens[0]) as PackedScene).instantiate() as Arena
	for item in arena.get_node("Items").get_children():
		item.free()
	for sp in arena.get_node("Spawners").get_children():
		sp.free()
	t.get_tree().root.add_child(arena)
	await t.wait_frames(10)
	p1 = arena.players[0]
	p2 = arena.players[1]
	await _park_players()

	await _walker_patrol()
	await _walker_chase_and_attack()
	await _walker_platforms()
	await _bomb_kill_score_combo()
	await _hermit_shell()
	await _seagull()
	await _octopus()
	await _spawner_waves()

	arena.queue_free()
	await t.wait_frames(2)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE


func _data() -> void:
	var ok := true
	for id in IDS:
		var d := load("res://data/enemies/%s.tres" % id) as EnemyData
		var sf := d.sprite_frames if d else null
		ok = ok and d != null and sf != null
		if sf:
			for anim in [&"idle", &"walk", &"attack", &"hurt", &"death"]:
				ok = ok and sf.has_animation(anim)
	t.check(ok, "4 enemigos del Mundo 1 como datos, con sus animaciones (idle, walk, attack, hurt, death)")
	var e := _make("small_crab")
	var has_all := true
	for s in STATES:
		has_all = has_all and e.get_node("StateMachine").has_node(NodePath(s))
	t.check(has_all, "Enemy.tscn: estados IDLE, PATROL, CHASE, ATTACK, HURT, DEAD (+ SPECIAL)")
	e.free()


# ------------------------------------------------------------------ cangrejo (WALKER)
func _walker_patrol() -> void:
	var crab := await _spawn("small_crab", Vector2(480, 448))
	var min_x := 9999.0
	var max_x := -9999.0
	var on_platform := true
	for i in 300:
		await t.wait_frames(1)
		min_x = minf(min_x, crab.global_position.x)
		max_x = maxf(max_x, crab.global_position.x)
		on_platform = on_platform and absf(crab.global_position.y - 448.0) < 3.0
	t.check(on_platform and min_x >= 320.0 and max_x <= 640.0 and max_x - min_x > 60.0,
		"PATROL: recorre su plataforma y se da la vuelta en los bordes (%.0f–%.0f)" % [min_x, max_x])
	crab.queue_free()
	await t.wait_frames(2)


func _walker_chase_and_attack() -> void:
	await _place(p1, Vector2(620, FLOOR_Y))
	var crab := await _spawn("small_crab", Vector2(860, FLOOR_Y))
	var hp := p1.health.current_health
	var chased := false
	var attacked := false
	for i in 240:
		await t.wait_frames(1)
		var st := crab.state_machine.current_state.name
		chased = chased or st == &"Chase"
		attacked = attacked or st == &"Attack"
		if p1.health.current_health < hp:
			break
	t.check(chased and crab.global_position.x < 800.0, "CHASE: persigue al jugador en su piso")
	t.check(attacked and p1.health.current_health < hp, "ATTACK: la pinza (o el contacto) daña al jugador")
	crab.queue_free()
	p1.health.reset()
	await _park_players()


func _walker_platforms() -> void:
	# Bajar: el jugador está abajo, el cangrejo en una plataforma atravesable.
	await _place(p1, Vector2(470, FLOOR_Y))
	var crab := await _spawn("small_crab", Vector2(470, 448))
	var dropped := false
	for i in 180:
		await t.wait_frames(1)
		if crab.global_position.y > 600.0:
			dropped = true
			break
	t.check(dropped, "baja de la plataforma atravesable para perseguir al jugador")
	crab.queue_free()
	await _park_players()
	# Subir: el jugador está en la plataforma de arriba.
	await _place(p1, Vector2(160, 560))
	crab = await _spawn("small_crab", Vector2(200, FLOOR_Y))
	var climbed := false
	for i in 240:
		p1.health.start_invulnerability(0.2)
		await t.wait_frames(1)
		if crab.is_on_floor() and absf(crab.global_position.y - 560.0) < 3.0:
			climbed = true
			break
	t.check(climbed, "salta al piso de arriba para perseguir al jugador")
	crab.queue_free()
	await _park_players()


# ------------------------------------------------------------------ daño y puntos
func _bomb_kill_score_combo() -> void:
	ScoreManager.reset()
	var defeated_ids: Array[StringName] = []
	var on_defeated := func(id: StringName, _pos: Vector2, killer: int) -> void:
		if killer == 0:
			defeated_ids.append(id)
	EventBus.enemy_defeated.connect(on_defeated)
	var a := await _spawn("small_crab", Vector2(420, FLOOR_Y))
	var b := await _spawn("small_crab", Vector2(470, FLOOR_Y))
	a.data = a.data.duplicate() as EnemyData
	a.data.drop_table = _sure_drop()
	var bomb := arena.bomb_pool.acquire_bomb(load("res://data/bombs/black_bomb.tres") as BombData, 0)
	bomb.arm_at(Vector2(445, FLOOR_Y - 14))
	await t.wait_frames(2)
	bomb.detonate()
	await t.wait_frames(90)
	t.check(not is_instance_valid(a) and not is_instance_valid(b), "una bomba derrota a los enemigos de su radio")
	t.check(defeated_ids.size() == 2, "enemy_defeated con el jugador que puso la bomba")
	var base := (load("res://data/enemies/small_crab.tres") as EnemyData).score
	# (Sin más enemigos la pantalla queda limpia y suma también su bonificación.)
	var bonus := ScoreManager.table.screen_clear if arena.enemies.is_cleared else 0
	t.check(ScoreManager.scores[0] - bonus == base + base * 2, "puntos con combo: %d + %d x2" % [base, base])
	var drops := 0
	for n in arena.get_node("Items").get_children():
		if n is PowerUp:
			drops += 1
			n.queue_free()
	t.check(drops >= 1, "el enemigo suelta botín (drop_table)")
	EventBus.enemy_defeated.disconnect(on_defeated)


func _hermit_shell() -> void:
	var hermit := await _spawn("hermit_crab", Vector2(300, FLOOR_Y))
	var hp := hermit.health.current_health
	var bomb := arena.bomb_pool.acquire_bomb(load("res://data/bombs/blue_bomb.tres") as BombData, 0)
	bomb.arm_at(Vector2(360, FLOOR_Y - 12))
	await t.wait_frames(10)
	t.check(hermit.state_machine.current_state.name == &"Special" and (hermit.behavior as ShellBehavior).in_shell,
		"el ermitaño se esconde en el caparazón si hay una bomba cerca")
	bomb.detonate()
	await t.wait_frames(2)
	t.check(hermit.health.current_health == hp, "escondido, la bomba pequeña (daño 1) no le hace nada")
	var black := arena.bomb_pool.acquire_bomb(load("res://data/bombs/black_bomb.tres") as BombData, 0)
	black.arm_at(Vector2(340, FLOOR_Y - 14))
	await t.wait_frames(20)
	black.detonate()
	await t.wait_frames(2)
	t.check(hermit.health.current_health == hp - 1, "la bomba normal (daño 2) le quita 1: el caparazón absorbe 1")
	hermit.queue_free()
	await t.wait_frames(2)


func _seagull() -> void:
	# La gaviota va a por el jugador más cercano: P2 lejos, a la izquierda.
	await _place(p2, Vector2(60, 336))
	await _place(p1, Vector2(700, FLOOR_Y))
	var gull := await _spawn("seagull", Vector2(300, 150))
	var cruise := true
	for i in 60:
		await t.wait_frames(1)
		cruise = cruise and absf(gull.global_position.y - 150.0) < 30.0
	t.check(cruise and gull.global_position.x > 330.0, "la gaviota vuela a su altura de crucero")
	var hp := p1.health.current_health
	var dived := false
	for i in 300:
		await t.wait_frames(1)
		dived = dived or gull.state_machine.current_state.name == &"Attack"
		if p1.health.current_health < hp:
			break
	t.check(dived and p1.health.current_health < hp, "cae en picado sobre el jugador y lo daña")
	var back := false
	for i in 240:
		p1.health.start_invulnerability(0.2)
		await t.wait_frames(1)
		if gull.state_machine.current_state.name != &"Attack" and absf(gull.global_position.y - 150.0) < 14.0:
			back = true
			break
	t.check(back, "y vuelve a subir a su altura")
	gull.queue_free()
	p1.health.reset()
	await _park_players()


func _octopus() -> void:
	# (Pantalla A: hay una roca en el suelo entre x=452 y 508; la tinta choca con ella.)
	await _place(p1, Vector2(600, FLOOR_Y))
	await t.wait_frames(int(p1.config.invulnerability_time * 60.0))
	var octo := await _spawn("small_octopus", Vector2(880, FLOOR_Y))
	var hp := p1.health.current_health
	var shot := false
	for i in 300:
		await t.wait_frames(1)
		for n in arena.enemies.get_children():
			shot = shot or n is InkProjectile
		if p1.health.current_health < hp:
			break
	t.check(shot, "el pulpo lanza tinta al jugador de su piso")
	t.check(p1.health.current_health < hp, "la tinta daña al jugador")
	octo.queue_free()
	p1.health.reset()
	await _park_players()


# ------------------------------------------------------------------ spawner y oleadas
func _spawner_waves() -> void:
	var holder := arena.get_node("Spawners")
	var left := _spawner("small_crab", EnemySpawner.Entry.LEFT, Vector2(0, FLOOR_Y), 2, 1)
	var top := _spawner("small_crab", EnemySpawner.Entry.TOP, Vector2(480, 0), 1, 2)
	holder.add_child(left)
	holder.add_child(top)
	var cleared := [false]
	arena.enemies.cleared.connect(func() -> void: cleared[0] = true, CONNECT_ONE_SHOT)
	arena.enemies.is_cleared = false
	arena.enemies.register_spawners([left, top] as Array[EnemySpawner])
	t.check(arena.enemies.remaining() == 3 and arena.enemies.current_wave == 1, "oleada 1 activa; 3 enemigos reservados")
	await t.wait_frames(8)
	var first := _alive_enemies()
	t.check(first.size() == 1 and absf(first[0].global_position.x - EnemySpawner.SIDE_MARGIN) < 1.0,
		"entra por la izquierda, de uno en uno (max_enemies = 1)")
	first[0].health.kill()
	await t.wait_frames(40)
	var second := _alive_enemies()
	t.check(second.size() == 1 and left.spawned == 2 and top.spawned == 0, "sale el siguiente de la oleada 1")
	second[0].health.kill()
	await t.wait_frames(60)
	var third := _alive_enemies()
	t.check(arena.enemies.current_wave == 2 and third.size() == 1 and top.spawned == 1,
		"la oleada 2 empieza al acabar la 1 (entra desde arriba)")
	t.check(not cleared[0], "la pantalla no está limpia mientras queden enemigos")
	third[0].health.kill()
	await t.wait_frames(60)
	t.check(cleared[0] and arena.enemies.remaining() == 0, "sin enemigos ni oleadas pendientes: pantalla limpia")


# ---------------------------------------------------------------- utilidades
func _make(id: String) -> Enemy:
	var e := (load("res://scenes/enemies/Enemy.tscn") as PackedScene).instantiate() as Enemy
	e.data = load("res://data/enemies/%s.tres" % id) as EnemyData
	return e


func _spawn(id: String, pos: Vector2) -> Enemy:
	var e := _make(id)
	e.position = pos
	e.spawn_grace = 0.0
	arena.enemies.add_child(e)
	await t.wait_frames(3)
	return e


func _spawner(id: String, entry: EnemySpawner.Entry, pos: Vector2, count: int, wave: int) -> EnemySpawner:
	var sp := EnemySpawner.new()
	sp.enemy_type = load("res://data/enemies/%s.tres" % id) as EnemyData
	sp.entry = entry
	sp.position = pos
	sp.spawn_delay = 0.05
	sp.interval = 0.3
	sp.count = count
	sp.max_enemies = 1
	sp.wave = wave
	return sp


func _alive_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in arena.enemies.get_children():
		if n is Enemy and (n as Enemy).is_alive():
			out.append(n)
	return out


func _sure_drop() -> DropTable:
	var table := DropTable.new()
	var list: Array[PowerUpData] = [load("res://data/powerups/cherry.tres") as PowerUpData]
	table.items = list
	table.drop_chance = 1.0
	return table


## Deja a los jugadores lejos, en la plataforma alta de la derecha y con invulnerabilidad.
func _park_players() -> void:
	for p in [p1, p2]:
		p.health.reset()
		p.health.start_invulnerability(0.1)
	await _place(p2, Vector2(900, 336))
	await _place(p1, Vector2(860, 336))


func _place(pl: Player, pos: Vector2) -> void:
	for prefix in ["p1_", "p2_"]:
		for c in InputManager.COMMANDS:
			Input.action_release(prefix + c)
	pl.global_position = pos
	pl.velocity = Vector2.ZERO
	pl.set_low_profile(false)
	pl.state_machine.transition_to(&"Fall")
	for i in 60:
		if pl.is_on_floor() and pl.state_machine.is_in(&"Idle"):
			break
		await t.wait_frames(1)
	await t.wait_frames(2)
