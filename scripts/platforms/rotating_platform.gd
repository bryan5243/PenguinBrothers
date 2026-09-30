class_name RotatingPlatform
extends StaticBody2D
## Plataforma giratoria (disco de madera): la forma arcade de cambiar de piso.
##
## Un pingüino encima pulsa ARRIBA → tiembla un instante, gira y lo lanza hacia arriba
## (`launch_height`, ajustada al piso que le toca): así se sube de piso. ABAJO → los de encima
## dan la vuelta con ella y quedan PEGADOS boca abajo a su parte de abajo `stick_time` segundos
## (la plataforma se queda boca abajo); luego la plataforma se endereza y los suelta, que caen
## al piso de abajo. Las bombas y barriles que están encima salen despedidos (arriba) o caen
## (abajo). Mientras está girando o boca abajo no se puede pisar y después espera `cooldown`.
## Los enemigos no la activan.
##
## El origen del nodo es el centro de la superficie en la que se pisa. Ajustes en
## RotatingPlatformData (data/platforms/).

signal flip_started(direction: int)
signal flip_finished

enum State { READY, WINDUP, FLIP, HANGING, REVERT, COOLDOWN }

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
var _disk_rest := Vector2.ZERO
var _disk_scale := Vector2.ONE
var _stuck: Array[Player] = []

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


## Empieza un giro (UP o DOWN). Lo llaman los jugadores que están encima; también sirve para
## activarla desde un interruptor o una prueba.
func start_flip(dir: int) -> bool:
	if state != State.READY or (dir == UP and not can_flip_up) or (dir == DOWN and not can_flip_down):
		return false
	direction = dir
	state = State.WINDUP
	_timer = data.windup_time
	return true


## Lo que va montado ahora mismo: jugadores apoyados y objetos libres en reposo encima.
func riders() -> Array[Node2D]:
	var list: Array[Node2D] = []
	for body in rider_zone.get_overlapping_bodies():
		if body is Player:
			var p := body as Player
			if p.is_alive() and p.is_on_floor() \
					and absf(p.global_position.y - global_position.y) <= FEET_TOLERANCE:
				list.append(p)
		elif body is CarryableBody:
			var obj := body as CarryableBody
			if not obj.is_held() and obj.is_on_floor():
				list.append(obj)
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
			var t := clampf(1.0 - _timer / maxf(data.flip_time, 0.01), 0.0, 1.0)
			# El disco se ve de canto: girar es cambiar su alto con el coseno.
			# Hacia arriba da la vuelta entera (termina derecho); hacia abajo, media vuelta
			# (termina boca abajo).
			var turn := PI if direction == DOWN else TAU
			disk.scale = Vector2(_disk_scale.x, _disk_scale.y * cos(turn * t))
			_keep_stuck()
			if _timer <= 0.0:
				_after_flip()
		State.HANGING:
			_timer -= delta
			_keep_stuck()
			if _timer <= 0.0 or _stuck.is_empty():
				_release_stuck()
				state = State.REVERT
				_timer = data.revert_time
		State.REVERT:
			_timer -= delta
			var back := clampf(1.0 - _timer / maxf(data.revert_time, 0.01), 0.0, 1.0)
			disk.scale = Vector2(_disk_scale.x, lerpf(-_disk_scale.y, _disk_scale.y, back))
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
	disk.position = _disk_rest
	# Mientras gira no se puede pisar (y los de encima la atraviesan al caer).
	shape_node.disabled = true
	_stuck.clear()
	for r in on_top:
		if r is Player:
			var p := r as Player
			if direction == UP:
				p.launch(Vector2(p.velocity.x, -sqrt(2.0 * p.config.gravity * get_launch_height())))
			elif p.stick_to(self, _stick_position(_stuck.size())):
				_stuck.append(p)
		elif r is CarryableBody:
			var obj := r as CarryableBody
			var vy := -data.object_launch_speed if direction == UP else data.drop_speed
			obj.launch(Vector2(obj.velocity.x, vy))
	AudioManager.play_sfx("platform_flip")
	flip_started.emit(direction)


## Terminó el giro: hacia arriba la plataforma queda lista; hacia abajo se queda boca abajo
## mientras sujeta a alguien.
func _after_flip() -> void:
	if direction == DOWN and not _stuck.is_empty():
		state = State.HANGING
		_timer = data.stick_time
		disk.scale = Vector2(_disk_scale.x, -_disk_scale.y)
	elif direction == DOWN:
		disk.scale = Vector2(_disk_scale.x, -_disk_scale.y)
		state = State.REVERT
		_timer = data.revert_time
	else:
		_finish()


func _stick_position(index: int) -> Vector2:
	# Cada pingüino pegado se coloca un poco a un lado del anterior (0, +1, -1, +2...).
	var side := (index + 1) / 2 * (1 if index % 2 == 1 else -1)
	if index == 0:
		side = 0
	return data.stick_offset + Vector2(side * data.stick_spread, 0.0)


## Quita de la lista a los que dejaron de estar pegados (heridos, muertos...).
func _keep_stuck() -> void:
	for p in _stuck.duplicate():
		if not is_instance_valid(p) or not p.is_stuck():
			_stuck.erase(p)


func _release_stuck() -> void:
	for p in _stuck:
		if is_instance_valid(p):
			p.release_stuck(Vector2(0.0, data.drop_speed))
	_stuck.clear()


func _finish() -> void:
	disk.scale = _disk_scale
	disk.position = _disk_rest
	shape_node.disabled = false
	state = State.COOLDOWN
	_timer = data.cooldown
	flip_finished.emit()
