extends RefCounted
## Pruebas de la Fase 7 arcade: la llave (aparece al limpiar la A, se recoge, se lleva, cae si
## muere el portador) y la puerta de salida de la B (cerrada sin llave, se abre con ella y
## completa la fase). Las ejecuta tests/smoke_test.gd.

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0

var t: Node
var arena: Arena
var p1: Player
var p2: Player
var requested: Array[String] = []


func run(test: Node) -> void:
	t = test
	EventBus.scene_change_requested.connect(_on_scene_requested)
	_data()
	await _screen_a()
	await _screen_b()
	await _holder_dies()
	EventBus.scene_change_requested.disconnect(_on_scene_requested)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE
	StageManager.carry_over.clear()


func _on_scene_requested(path: String, _transition: StringName) -> void:
	requested.append(path)


func _data() -> void:
	var d := load(KeyItem.DATA_PATH) as ObjectiveData
	t.check(d != null and d.key_texture != null and d.door_closed != null and d.door_open != null,
		"ObjectiveData: llave y puerta (cerrada/abierta) como datos (.tres)")
	t.check(ScoreManager.table.key > 0, "la llave da puntos (ScoreTable.key)")


func _load(index: int) -> Arena:
	StageManager.stage = load(STAGE) as StageData
	StageManager.screen_index = index
	GameManager.start_new_game(GameManager.GameMode.COOP)
	var a := (load(StageManager.stage.screens[index]) as PackedScene).instantiate() as Arena
	for sp in a.get_node("Spawners").get_children():
		sp.free()
	t.get_tree().root.add_child(a)
	await t.wait_frames(10)
	arena = a
	p1 = a.players[0]
	p2 = a.players[1]
	return a


func _unload() -> void:
	arena.queue_free()
	await t.wait_frames(3)
	for g in [KeyItem.GROUP]:
		for n in t.get_tree().get_nodes_in_group(g):
			n.queue_free()
	await t.wait_frames(2)


func _screen_a() -> void:
	StageManager.carry_over.clear()
	await _load(0)
	t.check(arena.screen_role == "A" and arena.key == null, "la pantalla A empieza sin llave")
	requested.clear()
	arena.enemies.cleared.emit()
	await t.wait_frames(2)
	t.check(arena.key != null and arena.key.state == KeyItem.State.FALLING,
		"al limpiar la pantalla A aparece la llave (cayendo)")
	for i in 120:
		if arena.key.state == KeyItem.State.IDLE:
			break
		await t.wait_frames(1)
	var key := arena.key
	t.check(key.state == KeyItem.State.IDLE and key.global_position.y < 224.0 and key.global_position.y > 130.0,
		"la llave cae y se posa sobre la plataforma de arriba")
	arena.enemies.cleared.emit()
	t.check(arena.key == key, "no aparece una segunda llave")

	await _place(p2, Vector2(860, FLOOR_Y))
	var score := ScoreManager.scores[0]
	await _place(p1, Vector2(key.global_position.x, 224.0))
	for i in 30:
		if key.is_carried():
			break
		await t.wait_frames(1)
	t.check(key.is_carried() and key.holder == p1, "el jugador recoge la llave al tocarla")
	t.check(ScoreManager.scores[0] == score + ScoreManager.table.key, "recoger la llave da puntos")
	t.check(StageManager.carry_over.get("key", false) and StageManager.carry_over.get("key_owner", -1) == 0,
		"la llave pasa a StageManager.carry_over (quién la lleva)")
	await t.wait_frames(10)
	t.check(key.global_position.distance_to(p1.global_position + key.data.carry_offset) < 4.0,
		"la lleva flotando sobre la cabeza")
	t.check(not requested.has(StageManager.stage.screens[1]), "aún no hay transición (pausa corta)")
	await t.wait_frames(int(key.data.pickup_to_transition * 60.0) + 6)
	t.check(requested.has(StageManager.stage.screens[1]) and StageManager.screen_index == 1,
		"un momento después pasa a la pantalla B")
	await _unload()
	StageManager.phase = StageManager.Phase.IDLE


func _screen_b() -> void:
	# Llegan a la B con la llave (la llevaba el jugador 2).
	await _load(1)
	StageManager.carry_over = {"key": true, "key_owner": 1}
	arena.free()
	await t.wait_frames(2)
	await _load(1)
	StageManager.carry_over = {"key": true, "key_owner": 1}
	arena._restore_key()
	await t.wait_frames(3)
	var door := arena.get_node("Items/ExitDoor") as ExitDoor
	var key := arena.key
	t.check(arena.screen_role == "B" and door != null and door.state == ExitDoor.State.CLOSED,
		"la pantalla B tiene su puerta de salida, cerrada")
	t.check(key != null and key.is_carried() and key.holder == p2, "la llave vuelve a su portador (jugador 2)")

	# Sin llave la puerta no abre: el jugador 1 llega hasta ella.
	requested.clear()
	await _place(p1, door.global_position)
	await t.wait_frames(20)
	t.check(door.state == ExitDoor.State.CLOSED, "sin la llave la puerta no se abre")
	# Con la llave, su portador llega a la puerta.
	await _place(p2, door.global_position + Vector2(10, 0))
	await t.wait_frames(4)
	t.check(door.is_open() and StageManager.carry_over.get("key", false) == false,
		"el portador de la llave abre la puerta y la gasta")
	t.check(door.sprite.texture == door.data.door_open, "la puerta abierta muestra el portal")
	var score := ScoreManager.scores[0]
	await t.wait_frames(int(door.data.enter_delay * 60.0) + 8)
	t.check(StageManager.phase == StageManager.Phase.CLEARED and requested.has(StageManager.VICTORY_SCREEN),
		"tras abrirla se completa la fase (pantalla de victoria)")
	t.check(ScoreManager.scores[0] >= score + ScoreManager.table.stage_clear, "bonificación de fase completada")
	await _unload()
	StageManager.phase = StageManager.Phase.IDLE


func _holder_dies() -> void:
	StageManager.carry_over.clear()
	await _load(1)
	StageManager.carry_over = {"key": true, "key_owner": 0}
	arena._restore_key()
	await t.wait_frames(3)
	var key := arena.key
	await _place(p2, Vector2(860, FLOOR_Y))
	await _place(p1, Vector2(300, FLOOR_Y))
	t.check(key.is_carried() and key.holder == p1, "el jugador 1 lleva la llave")
	var dropped_at := p1.global_position
	p1.health.kill(null)
	await t.wait_frames(6)
	t.check(not key.is_carried() and key.holder == null and not StageManager.carry_over.has("key_owner"),
		"si el portador muere, la llave se suelta")
	for i in 120:
		if key.state == KeyItem.State.IDLE:
			break
		await t.wait_frames(1)
	t.check(key.state == KeyItem.State.IDLE and absf(key.global_position.x - dropped_at.x) < 8.0,
		"cae donde murió y espera en el suelo")
	# El compañero la recoge (sin esperar, pasada la espera de 1 s).
	await _place(p2, Vector2(key.global_position.x, key.global_position.y + 10.0))
	for i in 120:
		if key.is_carried():
			break
		await t.wait_frames(1)
	t.check(key.is_carried() and key.holder == p2 and StageManager.carry_over.get("key_owner", -1) == 1,
		"el compañero puede recogerla y pasa a ser el portador")
	await _unload()
	StageManager.phase = StageManager.Phase.IDLE


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
