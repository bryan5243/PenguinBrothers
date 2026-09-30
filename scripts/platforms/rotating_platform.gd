class_name RotatingPlatform
extends StaticBody2D
## Plataforma giratoria (disco de madera): la forma arcade de cambiar de piso.
##
## Un pingüino encima puede hacerla girar cuando quiera:
##   · ARRIBA  → tiembla, da la vuelta y lo lanza al piso de arriba (`launch_height`).
##   · ABAJO   → gira media vuelta llevándolo consigo: queda COLGANDO boca abajo bajo el disco.
##     Colgado se desplaza por debajo (izquierda/derecha, con inercia) hasta `hang_time`
##     segundos. ARRIBA (o saltar) → la plataforma gira de vuelta y lo deja encima otra vez;
##     ABAJO → se suelta y cae; si no hace nada, cae al acabarse el tiempo (parpadea antes).
## Con dos pingüinos colgados, cualquiera que pida volver endereza la plataforma para ambos.
## Las bombas y barriles que están encima salen despedidos (arriba) o caen (abajo). Mientras
## está girando o boca abajo no se puede pisar. Los enemigos no la activan.
##
## El origen del nodo es el centro de la superficie en la que se pisa. Ajustes en
## RotatingPlatformData (data/platforms/).

signal flip_started(direction: int)
signal flip_finished

enum State { READY, WINDUP, FLIP, INVERTED, REVERT, COOLDOWN }

const UP := -1
const DOWN := 1
const DEFAULT_DATA := "res://data/platforms/rotating_platform.tres"
const LAYER := 1 << 5                    # plataformas atravesables
const RIDER_MASK := (1 << 1) | (1 << 3) | (1 << 4)   # jugadores, bombas, objetos
## Diferencia máxima (px) entre los pies y la superficie para contar como «encima».
const FEET_TOLERANCE := 6.0
## El dibujo es algo más ancho que la superficie de colisión (el borde del disco).
const ART_OVERHANG := 1.08

@export var data: RotatingPlatformData
## Altura a la que lanza hacia arriba (px sobre la superficie). -1 = la de `data`.
@export var launch_height := -1.0
@export var can_flip_up := true
## Falso si hay suelo sólido debajo (plataformas a ras de suelo).
@export var can_flip_down := true

var state := State.READY
var direction := 0
var _timer := 0.0
var _time := 0.0
var _flip_t := 0.0
var _disk_rest := Vector2.ZERO
var _disk_scale := Vector2.ONE
## Colgados: Player -> {x: posición horizontal local, vx: velocidad, left: tiempo que queda}.
var _riders := {}

@onready var shape_node: CollisionShape2D = $Shape
@onready var disk: Sprite2D = $Disk
@onready var rider_zone: Area2D = $RiderZone


func _ready() -> void:
	if data == null:
		data = load(DEFAULT_DATA) as RotatingPlatformData
	collision_layer = LAYER
	collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(data.width, data.thickness)
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, data.thickness * 0.5)
	shape_node.one_way_collision = true
	var zone := RectangleShape2D.new()
	zone.size = Vector2(data.width, data.rider_zone_height + 4.0)
	var zone_shape := rider_zone.get_child(0) as CollisionShape2D
	zone_shape.shape = zone
	zone_shape.position = Vector2(0.0, -data.rider_zone_height * 0.5 + 2.0)
	rider_zone.collision_layer = 0
	rider_zone.collision_mask = RIDER_MASK
	rider_zone.monitorable = false
	if data.texture:
		disk.texture = data.texture
		var sc := data.width * ART_OVERHANG / data.texture.get_width()
		_disk_scale = Vector2(sc, sc)
		_disk_rest = Vector2(0.0, (0.5 - data.texture_surface) * data.texture.get_height() * sc)
	disk.scale = _disk_scale
	disk.position = _disk_rest


func get_launch_height() -> float:
	return launch_height if launch_height > 0.0 else data.launch_height


func is_ready() -> bool:
	return state == State.READY


func is_inverted() -> bool:
	return state == State.INVERTED


## Empieza un giro (UP o DOWN). Lo llaman los jugadores que están encima; también sirve para
## activarla desde un interruptor o una prueba.
func start_flip(dir: int) -> bool:
	if state != State.READY or (dir == UP and not can_flip_up) or (dir == DOWN and not can_flip_down):
		return false
	direction = dir
	state = State.WINDUP
	_timer = data.windup_time
	return true


## Pide volver a enderezar la plataforma estando boca abajo (los colgados quedan encima).
func request_revert() -> bool:
	if state != State.INVERTED:
		return false
	_begin_revert()
	return true


## Lo que va montado ahora mismo: jugadores apoyados y objetos libres en reposo encima.
func riders() -> Array[Node2D]:
	var list: Array[Node2D] = []
	for body in rider_zone.get_overlapping_bodies():
		if body is Player:
			var p := body as Player
			if p.is_alive() and p.is_on_floor() and not p.is_stuck() \
					and absf(p.global_position.y - global_position.y) <= FEET_TOLERANCE:
				list.append(p)
		elif body is CarryableBody:
			var obj := body as CarryableBody
			if not obj.is_held() and obj.is_on_floor():
				list.append(obj)
	return list


func hanging_players() -> Array[Player]:
	var list: Array[Player] = []
	for p in _riders:
		list.append(p)
	return list


func _physics_process(delta: float) -> void:
	_time += delta
	match state:
		State.READY:
			_check_riders_input()
		State.WINDUP:
			_timer -= delta
			disk.position = _disk_rest + Vector2(sin(_time * 70.0) * data.shake_amplitude, 0.0)
			if _timer <= 0.0:
				_flip()
		State.FLIP:
			_timer -= delta
			_flip_t = clampf(1.0 - _timer / maxf(data.flip_time, 0.01), 0.0, 1.0)
			# El disco se ve de canto: girar es cambiar su alto con el coseno. Hacia arriba da la
			# vuelta entera (termina derecho); hacia abajo, media vuelta (termina boca abajo).
			var turn := PI if direction == DOWN else TAU
			disk.scale = Vector2(_disk_scale.x, _disk_scale.y * cos(turn * _flip_t))
			if _timer <= 0.0:
				_after_flip()
		State.INVERTED:
			_prune()
			if _riders.is_empty():
				_begin_revert()
		State.REVERT:
			_timer -= delta
			_flip_t = clampf(1.0 - _timer / maxf(data.revert_time, 0.01), 0.0, 1.0)
			disk.scale = Vector2(_disk_scale.x, -_disk_scale.y * cos(PI * _flip_t))
			if _timer <= 0.0:
				_finish()
		State.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.READY


func _check_riders_input() -> void:
	for r in riders():
		var p := r as Player
		if p == null:
			continue
		var inp := p.input
		if inp.up_pressed and not inp.interact_pressed and start_flip(UP):
			return
		if inp.crouch_pressed and absf(inp.move_axis) < 0.2 and start_flip(DOWN):
			return


func _flip() -> void:
	var on_top := riders()
	state = State.FLIP
	_timer = data.flip_time
	_flip_t = 0.0
	disk.position = _disk_rest
	# Mientras gira no se puede pisar (y los de encima la atraviesan).
	shape_node.disabled = true
	_riders.clear()
	for r in on_top:
		if r is Player:
			var p := r as Player
			if direction == UP:
				p.launch(Vector2(p.velocity.x, -sqrt(2.0 * p.config.gravity * get_launch_height())))
			else:
				var lim := _limit()
				_riders[p] = {"x": clampf(p.global_position.x - global_position.x, -lim, lim),
					"vx": 0.0, "left": data.hang_time, "warned": false}
				if not p.stick_to(self):
					_riders.erase(p)
		elif r is CarryableBody:
			var obj := r as CarryableBody
			var vy := -data.object_launch_speed if direction == UP else data.drop_speed
			obj.launch(Vector2(obj.velocity.x, vy))
	AudioManager.play_sfx("platform_flip")
	flip_started.emit(direction)


## Terminó el giro: hacia arriba la plataforma queda lista; hacia abajo se queda boca abajo
## mientras haya alguien colgado (si no, se endereza).
func _after_flip() -> void:
	if direction == DOWN:
		disk.scale = Vector2(_disk_scale.x, -_disk_scale.y)
		state = State.INVERTED
		_prune()
	else:
		_finish()


func _begin_revert() -> void:
	state = State.REVERT
	_timer = data.revert_time
	_flip_t = 0.0


func _prune() -> void:
	for p in _riders.keys():
		if not is_instance_valid(p) or not (p as Player).is_stuck() or (p as Player).stuck_to != self:
			_riders.erase(p)


func _limit() -> float:
	return maxf(0.0, data.width * 0.5 - data.hang_margin)


## Lo llama cada jugador colgado en su paso físico: decide dónde está, cómo se ve y cuándo se
## suelta.
func drive_rider(p: Player, delta: float) -> void:
	var r: Dictionary = _riders.get(p, {})
	if r.is_empty():
		p.release_stuck()
		return
	var inp := p.input
	var down_y := data.hang_offset.y
	var y := 0.0
	var rot := 0.0
	match state:
		State.FLIP:
			# Da la vuelta con el disco: baja de encima a debajo mientras se voltea.
			var e := smoothstep(0.0, 1.0, _flip_t)
			y = lerpf(0.0, down_y, e)
			rot = PI * e
		State.INVERTED:
			y = down_y
			_hang_move(p, r, delta)
			rot = PI + clampf(r["vx"] / maxf(data.hang_speed, 1.0), -1.0, 1.0) * data.hang_sway \
				+ sin(_time * 2.6) * data.hang_sway * 0.25
			# Volver arriba (la plataforma se endereza), soltarse o esperar.
			if inp.up_pressed or inp.jump_pressed:
				_begin_revert()
			elif inp.crouch_pressed:
				_drop(p, r)
				return
			else:
				r["left"] -= delta
				if r["left"] <= data.hang_warning and not r["warned"]:
					r["warned"] = true
					p.animator.set_blinking(true)
				if r["left"] <= 0.0:
					_drop(p, r)
					return
		State.REVERT:
			var e := smoothstep(0.0, 1.0, _flip_t)
			y = lerpf(down_y, 0.0, e)
			rot = PI * (1.0 - e)
			if _flip_t >= 1.0:
				return
	p.global_position = global_position + Vector2(r["x"], y)
	p.animator.rotation = rot
	# Boca abajo el dibujo se ve reflejado al girarlo 180°: se compensa para que mire hacia
	# donde se mueve.
	p.animator.set_facing(-p.facing if rot > PI * 0.5 else p.facing)


## Desplazamiento colgado: acelera hacia la velocidad pedida, con inercia, sin salirse del disco.
func _hang_move(p: Player, r: Dictionary, delta: float) -> void:
	var axis := p.input.move_axis
	var target := axis * data.hang_speed
	r["vx"] = move_toward(r["vx"], target, data.hang_accel * delta)
	var lim := _limit()
	r["x"] = clampf(r["x"] + r["vx"] * delta, -lim, lim)
	if (r["x"] <= -lim and r["vx"] < 0.0) or (r["x"] >= lim and r["vx"] > 0.0):
		r["vx"] = 0.0
	if absf(axis) > 0.2:
		p.facing = int(signf(axis))
	if absf(r["vx"]) > 8.0:
		p.animator.play_animation(PlayerAnimator.WALK)
		p.animator.set_playback_speed(clampf(absf(r["vx"]) / data.hang_speed, 0.4, 1.2))
	else:
		p.animator.play_animation(PlayerAnimator.IDLE)


func _drop(p: Player, r: Dictionary) -> void:
	_riders.erase(p)
	p.release_stuck(Vector2(r["vx"] * 0.6, data.drop_speed))


func _finish() -> void:
	disk.scale = _disk_scale
	disk.position = _disk_rest
	shape_node.disabled = false
	# Los que seguían colgados quedan encima (con un saltito) al volver a girar.
	for p in _riders.keys():
		if is_instance_valid(p) and (p as Player).is_stuck():
			var r: Dictionary = _riders[p]
			(p as Player).global_position = global_position + Vector2(r["x"], -1.0)
			(p as Player).release_stuck(Vector2(r["vx"] * 0.5, -data.revert_hop))
	_riders.clear()
	state = State.COOLDOWN
	_timer = data.cooldown
	flip_finished.emit()
