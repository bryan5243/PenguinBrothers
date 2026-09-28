class_name Explosion
extends Node2D
## Explosión reutilizable (sale de un BombPool). Al dispararse con un ExplosionInfo:
##   1. Busca en un círculo de radio `info.radius` jugadores, enemigos, bombas y objetos
##      (capas 2, 3, 4 y 5). NO distingue entre amigo y enemigo: afecta a todos.
##   2. A cada uno (o a su padre, si lo alcanzado es una zona de golpe):
##        - si tiene `apply_explosion(info)`, lo decide él (Player: daño y empuje; Bomb:
##          cadena; enemigos, barriles y destructibles);
##        - si no, y tiene `take_damage(amount, source)`, recibe `info.damage`;
##        - otros CarryableBody salen despedidos.
##   3. Dibuja el ÁREA REAL de la explosión (círculo que se desvanece), la animación del tipo
##      de bomba escalada a ese radio, partículas, sonido y EventBus.bomb_exploded.

signal finished(explosion: Explosion)

const QUERY_MASK := (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
const MAX_RESULTS := 48
## Duración del círculo que marca el alcance.
const AREA_TIME := 0.35
## Nivel de poder a partir del cual la explosión es «especial» (anillo dorado).
const SPECIAL_LEVEL := 4

var pool: BombPool
var active := false
var info: ExplosionInfo
## Lo que alcanzó la última explosión (para pruebas y depuración).
var last_affected: Array[Node] = []
var _linger := 0.0
var _area_time := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var debris: CPUParticles2D = $Debris


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_finished)
	_reset()


func trigger(explosion: ExplosionInfo) -> void:
	info = explosion
	var data := info.data
	active = true
	global_position = info.center
	visible = true
	sprite.visible = true
	_linger = -1.0
	_area_time = AREA_TIME
	var frames: SpriteFrames = data.frames if data.frames and data.frames.has_animation(&"explode") else null
	if frames:
		sprite.sprite_frames = frames
	var diameter := data.explosion_texture_diameter if frames else 86.0
	var s := info.radius * 2.0 / diameter
	sprite.scale = Vector2(s, s)
	sprite.modulate = data.explosion_tint
	sprite.frame = 0
	sprite.play(&"explode")
	debris.emission_sphere_radius = info.radius * 0.25
	debris.initial_velocity_max = info.radius * 3.0
	debris.restart()
	debris.emitting = true
	last_affected = apply_to_area(info)
	queue_redraw()
	AudioManager.play_sfx(data.explode_sfx)
	EventBus.bomb_exploded.emit(info.center, info.radius, info.owner_index)


## Aplica la explosión a todo lo que haya en el radio. Devuelve los nodos afectados.
func apply_to_area(explosion: ExplosionInfo) -> Array[Node]:
	var circle := CircleShape2D.new()
	circle.radius = explosion.radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, explosion.center)
	query.collision_mask = QUERY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if explosion.source is CollisionObject2D:
		query.exclude = [(explosion.source as CollisionObject2D).get_rid()]
	var hits := get_world_2d().direct_space_state.intersect_shape(query, MAX_RESULTS)
	var affected: Array[Node] = []
	for hit in hits:
		var target := _resolve(hit["collider"] as Node)
		if target == null or target == explosion.source or affected.has(target):
			continue
		affected.append(target)
		if target.has_method(&"apply_explosion"):
			target.apply_explosion(explosion)
		elif target.has_method(&"take_damage"):
			target.take_damage(explosion.damage, explosion.source)
		elif target is CarryableBody:
			(target as CarryableBody).launch(explosion.push_direction((target as Node2D).global_position)
				* explosion.knockback)
	return affected


## Una zona de golpe (Area2D) representa a su padre si el padre sabe reaccionar.
func _resolve(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method(&"apply_explosion") or node.has_method(&"take_damage") or node is CarryableBody:
		return node
	var parent := node.get_parent()
	if parent and (parent.has_method(&"apply_explosion") or parent.has_method(&"take_damage")):
		return parent
	return node


func _draw() -> void:
	if info == null or _area_time <= 0.0:
		return
	var k := _area_time / AREA_TIME
	var c := info.data.area_color
	draw_circle(Vector2.ZERO, info.radius, Color(c.r, c.g, c.b, 0.22 * k))
	draw_arc(Vector2.ZERO, info.radius, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.9 * k), 3.0)
	if info.power_level >= SPECIAL_LEVEL:
		draw_arc(Vector2.ZERO, info.radius * (1.0 - 0.25 * k), 0.0, TAU, 48, Color(1.0, 0.85, 0.2, k), 5.0)


func _on_sprite_finished() -> void:
	# Las partículas siguen un poco más que el destello.
	sprite.visible = false
	_linger = debris.lifetime


func _process(delta: float) -> void:
	if not active:
		return
	if _area_time > 0.0:
		_area_time = maxf(0.0, _area_time - delta)
		queue_redraw()
	if _linger < 0.0:
		return
	_linger -= delta
	if _linger <= 0.0:
		_reset()
		finished.emit(self)
		if pool == null:
			queue_free()


func _reset() -> void:
	active = false
	visible = false
	_area_time = 0.0
	sprite.stop()
	debris.emitting = false
	queue_redraw()
