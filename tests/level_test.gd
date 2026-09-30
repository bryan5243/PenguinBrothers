extends RefCounted
## Pruebas de diseño de las pantallas (Fases 8–9): recorrido sin bloqueos. Con las capacidades
## reales del pingüino (PlayerConfig: salto, velocidad) y las plataformas giratorias se calcula
## qué pisos se alcanzan desde el punto de inicio y se exige que sean todos (incluida la llave
## y la puerta). También revisa que los enemigos entren dentro de la arena. Las ejecuta
## tests/smoke_test.gd.

const STAGE := "res://data/stages/world_01_stage_01.tres"
const FLOOR_Y := 672.0
## Margen de seguridad sobre las capacidades del salto (no se exige el límite exacto).
const JUMP_MARGIN := 0.92
const REACH_MARGIN := 0.75
const LAND_MARGIN := 8.0

var t: Node
var cfg: PlayerConfig


class Surface:
	var name := ""
	var x0 := 0.0
	var x1 := 0.0
	var y := 0.0
	var rotator: RotatingPlatform = null

	func contains_x(x: float, margin := 0.0) -> bool:
		return x >= x0 + margin and x <= x1 - margin


func run(test: Node) -> void:
	t = test
	cfg = load("res://data/player/default_player_config.tres") as PlayerConfig
	StageManager.stage = load(STAGE) as StageData
	GameManager.start_new_game(GameManager.GameMode.COOP)
	for i in StageManager.stage.screen_count():
		await _check_screen(i)
	StageManager.stage = null
	StageManager.phase = StageManager.Phase.IDLE


func _check_screen(index: int) -> void:
	StageManager.screen_index = index
	var arena := (load(StageManager.stage.screens[index]) as PackedScene).instantiate() as Arena
	t.get_tree().root.add_child(arena)
	await t.wait_frames(6)
	var label := "pantalla %s" % arena.screen_role
	var surfaces := _surfaces(arena)
	var start := _surface_at(surfaces, arena.spawner.get_node("P1").position)
	var start2 := _surface_at(surfaces, arena.spawner.get_node("P2").position)
	t.check(start != null and start2 != null, "%s: los dos jugadores empiezan sobre una superficie" % label)
	var reached := _reach(surfaces, start)
	var missing: Array[String] = []
	for s in surfaces:
		if not reached.has(s):
			missing.append(s.name)
	t.check(missing.is_empty(), "%s: todos los pisos son alcanzables desde el inicio %s" % [label, missing])
	t.check(reached.has(start2), "%s: el jugador 2 llega al mismo conjunto de pisos" % label)
	if arena.screen_role == "A":
		var ks := _surface_under(surfaces, arena.key_position)
		t.check(ks != null and reached.has(ks), "%s: la llave cae sobre un piso alcanzable" % label)
	var door := arena.get_node_or_null("Items/ExitDoor") as ExitDoor
	if door:
		var ds := _surface_at(surfaces, door.position)
		t.check(ds != null and reached.has(ds), "%s: la puerta está sobre un piso alcanzable" % label)
	# Objetos de la pantalla sobre pisos alcanzables (barriles, cajas, piedras).
	var stranded: Array[String] = []
	for n in arena.get_node("Items").get_children():
		if n is ExitDoor or n is KeyItem:
			continue
		var s := _surface_under(surfaces, n.position - Vector2(0, 4))
		if s == null or not reached.has(s):
			stranded.append(String(n.name))
	t.check(stranded.is_empty(), "%s: barriles y cajas sobre pisos alcanzables %s" % [label, stranded])
	# Rotators: que cada una suba de verdad a un piso.
	for r in arena.get_node("Rotators").get_children():
		if r is RotatingPlatform:
			var goes := false
			for s in surfaces:
				if s.rotator == null and _rotator_reaches(r, s):
					goes = true
			t.check(goes, "%s: %s lleva a un piso de arriba" % [label, r.name])
	# Enemigos: entradas dentro de la arena y oleadas seguidas.
	var waves := {}
	var inside := true
	for sp in arena.get_node("Spawners").get_children():
		if sp is EnemySpawner:
			waves[sp.wave] = true
			var p: Vector2 = sp.position
			inside = inside and p.x >= -1.0 and p.x <= 961.0 and p.y >= -1.0 and p.y <= FLOOR_Y + 1.0
	var contiguous := true
	for w in waves:
		contiguous = contiguous and (w == 1 or waves.has(w - 1))
	t.check(inside and not waves.is_empty() and contiguous,
		"%s: enemigos dentro de la arena y oleadas seguidas (%s)" % [label, waves.keys()])
	arena.queue_free()
	await t.wait_frames(3)


# ---------------------------------------------------------------- superficies
func _surfaces(arena: Arena) -> Array[Surface]:
	var out: Array[Surface] = []
	var ground := Surface.new()
	ground.name = "suelo"
	ground.x0 = 24.0
	ground.x1 = 936.0
	ground.y = FLOOR_Y
	out.append(ground)
	for cs in arena.get_node("Platforms").get_children():
		if cs is CollisionShape2D:
			var size := (cs.shape as RectangleShape2D).size
			var s := Surface.new()
			s.x0 = cs.position.x - size.x * 0.5
			s.x1 = cs.position.x + size.x * 0.5
			s.y = cs.position.y - size.y * 0.5
			s.name = "tablón y=%d [%d-%d]" % [s.y, s.x0, s.x1]
			out.append(s)
	for r in arena.get_node("Rotators").get_children():
		if r is RotatingPlatform:
			var s := Surface.new()
			s.x0 = r.position.x - r.data.width * 0.5
			s.x1 = r.position.x + r.data.width * 0.5
			s.y = r.position.y
			s.rotator = r
			s.name = "%s y=%d" % [r.name, s.y]
			out.append(s)
	return out


func _surface_at(list: Array[Surface], pos: Vector2) -> Surface:
	for s in list:
		if absf(s.y - pos.y) <= 4.0 and s.contains_x(pos.x):
			return s
	return null


## Superficie más alta que queda bajo un punto (donde se posaría un objeto que cae).
func _surface_under(list: Array[Surface], pos: Vector2) -> Surface:
	var best: Surface = null
	for s in list:
		if s.contains_x(pos.x) and s.y >= pos.y - 2.0 and (best == null or s.y < best.y):
			best = s
	return best


# ---------------------------------------------------------------- alcanzabilidad
func _reach(list: Array[Surface], start: Surface) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Surface] = [start]
	while not queue.is_empty():
		var a: Surface = queue.pop_front()
		for b in list:
			if not seen.has(b) and _can_go(a, b):
				seen[b] = true
				queue.append(b)
	return seen


func _gap(a: Surface, b: Surface) -> float:
	return maxf(0.0, maxf(a.x0 - b.x1, b.x0 - a.x1))


func _can_go(a: Surface, b: Surface) -> bool:
	var gap := _gap(a, b)
	if absf(a.y - b.y) < 1.0:
		return gap <= 12.0     # mismo piso, casi pegados: se camina
	if a.rotator and b.y < a.y:
		if _rotator_reaches(a.rotator, b):
			return true
	var rise := a.y - b.y
	if rise > 0.0:
		return rise <= _jump_height() * JUMP_MARGIN and gap <= _air_reach(rise) * REACH_MARGIN
	# Bajar: se cae por el borde y se controla en el aire.
	return gap <= _air_reach(rise) * REACH_MARGIN


func _jump_height() -> float:
	return cfg.jump_force * cfg.jump_force / (2.0 * cfg.gravity)


## Distancia horizontal que se cubre saltando y llegando a un piso `rise` px más arriba (o abajo si < 0).
func _air_reach(rise: float) -> float:
	var v := cfg.jump_force
	var disc := maxf(0.0, v * v - 2.0 * cfg.gravity * rise)
	var time := (v + sqrt(disc)) / cfg.gravity
	return cfg.move_speed * time


func _rotator_reaches(r: RotatingPlatform, s: Surface) -> bool:
	var rise := r.global_position.y - s.y
	if rise <= 0.0 or rise > r.get_launch_height() - LAND_MARGIN:
		return false
	return s.contains_x(r.global_position.x, 10.0)
