extends RefCounted
## Pruebas del deslizamiento arcade: resbalón fluido (no exagerado), inmunidad a los ataques
## de enemigos (contacto, pinza, tinta) solo mientras se desliza, y empuje sin daño a los
## enemigos que toca. Las ejecuta tests/smoke_test.gd.

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0

var t: Node
var arena: Arena
var p1: Player
var p2: Player


func run(test: Node) -> void:
	t = test
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
	await _place(p2, Vector2(900, FLOOR_Y))
	await _feel()
	await _immunity()
	await _shove()
	arena.queue_free()
	await t.wait_frames(2)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE


func _start_slide(from: Vector2) -> void:
	await _place(p1, from)
	Input.action_press("p1_move_right")
	await t.wait_frames(14)
	Input.action_press("p1_crouch")
	await t.wait_frames(2)
	Input.action_release("p1_move_right")
	Input.action_release("p1_crouch")


func _feel() -> void:
	var cfg := p1.config
	await _place(p1, Vector2(80, FLOOR_Y))
	Input.action_press("p1_move_right")
	await t.wait_frames(14)
	Input.action_press("p1_crouch")
	await t.wait_frames(1)
	var x0 := p1.global_position.x
	var speeds: Array[float] = []
	var frames := 0
	Input.action_release("p1_move_right")
	Input.action_release("p1_crouch")
	while p1.state_machine.is_in(&"Slide") and frames < 120:
		speeds.append(absf(p1.velocity.x))
		await t.wait_frames(1)
		frames += 1
	var dist := p1.global_position.x - x0
	t.check(speeds.size() > 10 and speeds.max() <= cfg.slide_speed * 1.02,
		"deslizamiento: no pasa de su velocidad máxima (%d px/s)" % int(speeds.max()))
	t.check(dist > 60.0 and dist < 170.0, "resbala un tramo moderado, sin exagerar (%d px)" % int(dist))
	t.check(frames / 60.0 < 0.9, "dura menos de un segundo (%.2f s)" % (frames / 60.0))
	# Fluido: tras el arranque solo frena, sin saltos ni subidas.
	var peak := speeds.find(speeds.max())
	var smooth := true
	for i in range(peak + 1, speeds.size()):
		smooth = smooth and speeds[i] <= speeds[i - 1] + 0.5 and speeds[i - 1] - speeds[i] < 25.0
	t.check(smooth, "frena poco a poco, sin tirones")
	await t.wait_frames(6)


func _immunity() -> void:
	var crab := await _spawn("small_crab", Vector2(700, FLOOR_Y))
	crab.set_physics_process(false)
	p1.health.reset()
	await _start_slide(Vector2(80, FLOOR_Y))
	t.check(p1.is_sliding(), "está deslizándose")
	var hp := p1.health.current_health
	t.check(not p1.take_damage(1, crab) and p1.health.current_health == hp,
		"deslizándose, el golpe de un enemigo (contacto o pinza) no le hace daño")
	var ink := InkProjectile.new()
	t.check(not p1.take_damage(1, ink) and p1.health.current_health == hp,
		"ni la tinta (ataque de largo alcance)")
	ink.free()
	var bomb_like := Node2D.new()
	t.check(p1.take_damage(1, bomb_like) and p1.health.current_health == hp - 1,
		"pero una explosión o trampa sí lo daña")
	bomb_like.free()
	await t.wait_frames(90)
	p1.health.reset()
	await t.wait_frames(int(p1.config.invulnerability_time * 60.0) + 4)
	t.check(not p1.is_sliding() and p1.take_damage(1, crab), "fuera del deslizamiento el enemigo vuelve a dañarlo")
	# Un proyectil real pasa de largo por un pingüino que se desliza.
	p1.health.reset()
	await t.wait_frames(int(p1.config.invulnerability_time * 60.0) + 4)
	await _start_slide(Vector2(300, FLOOR_Y))
	var shot := InkProjectile.new()
	shot.direction = -1
	shot.position = p1.global_position + Vector2(40, -14)
	arena.add_child(shot)
	hp = p1.health.current_health
	await t.wait_frames(6)
	t.check(p1.health.current_health == hp and is_instance_valid(shot) and not shot.is_queued_for_deletion(),
		"la tinta pasa sin tocarlo")
	shot.queue_free()
	crab.queue_free()
	await t.wait_frames(60)


func _shove() -> void:
	p1.health.reset()
	var crab := await _spawn("small_crab", Vector2(200, FLOOR_Y))
	var hp := crab.health.current_health
	await _place(p1, Vector2(80, FLOOR_Y))
	Input.action_press("p1_move_right")
	await t.wait_frames(14)
	Input.action_press("p1_crouch")
	await t.wait_frames(2)
	Input.action_release("p1_move_right")
	Input.action_release("p1_crouch")
	var x0 := crab.global_position.x
	var life := p1.health.current_health
	var pushed_at := 0.0
	for i in 60:
		await t.wait_frames(1)
		pushed_at = maxf(pushed_at, crab.shove_velocity)
	t.check(pushed_at > 100.0 and crab.global_position.x > x0 + 15.0,
		"al deslizarse contra un enemigo lo empuja (%d px)" % int(crab.global_position.x - x0))
	t.check(crab.health.current_health == hp and crab.is_alive(), "el empujón no le hace daño al enemigo")
	t.check(p1.health.current_health == life, "ni el enemigo al pingüino")
	await t.wait_frames(40)
	t.check(is_zero_approx(crab.shove_velocity), "el empujón se apaga solo")
	crab.queue_free()
	await t.wait_frames(2)


func _spawn(id: String, pos: Vector2) -> Enemy:
	var e := (load("res://scenes/enemies/Enemy.tscn") as PackedScene).instantiate() as Enemy
	e.data = load("res://data/enemies/%s.tres" % id) as EnemyData
	e.position = pos
	e.spawn_grace = 0.0
	arena.enemies.add_child(e)
	await t.wait_frames(3)
	return e


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
