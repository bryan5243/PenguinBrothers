class_name Explosion
extends Node2D
## Explosión reutilizable (sale de un BombPool). Al dispararse:
##   1. Busca en un círculo de radio `data.explosion_radius` jugadores, enemigos, bombas y
##      objetos (capas 2, 3, 4 y 5).
##   2. A cada uno le aplica la explosión:
##        - si tiene `apply_explosion(center, data, owner_index, source)` lo decide él
##          (Player: empuje; Bomb: reacción en cadena; enemigos/objetos futuros);
##        - si no, y tiene `take_damage(amount, source)`, recibe `data.damage`;
##        - los RigidBody2D reciben además un impulso hacia fuera.
##   3. Reproduce el efecto visual y el sonido, y avisa por EventBus.bomb_exploded.

signal finished(explosion: Explosion)

const QUERY_MASK := (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
## Diámetro visible del último fotograma del efecto dentro de su textura (px).
const EFFECT_DIAMETER := 86.0
const MAX_RESULTS := 32

var pool: BombPool
var active := false
var _linger := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var debris: CPUParticles2D = $Debris


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_finished)
	_reset()


func trigger(center: Vector2, data: BombData, owner_index: int, source: Node) -> void:
	active = true
	global_position = center
	visible = true
	sprite.visible = true
	_linger = -1.0
	var s := data.explosion_radius * 2.0 / EFFECT_DIAMETER
	sprite.scale = Vector2(s, s)
	sprite.modulate = data.explosion_tint
	sprite.frame = 0
	sprite.play(&"explode")
	debris.emission_sphere_radius = data.explosion_radius * 0.25
	debris.initial_velocity_max = data.explosion_radius * 3.0
	debris.restart()
	debris.emitting = true
	apply_to_area(center, data, owner_index, source)
	AudioManager.play_sfx(data.explode_sfx)
	EventBus.bomb_exploded.emit(center, data.explosion_radius, owner_index)


## Aplica la explosión a todo lo que haya en el radio. Devuelve los nodos afectados.
func apply_to_area(center: Vector2, data: BombData, owner_index: int, source: Node) -> Array[Node]:
	var circle := CircleShape2D.new()
	circle.radius = data.explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = QUERY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if source is CollisionObject2D:
		query.exclude = [(source as CollisionObject2D).get_rid()]
	var hits := get_world_2d().direct_space_state.intersect_shape(query, MAX_RESULTS)
	var affected: Array[Node] = []
	for hit in hits:
		var target := hit["collider"] as Node
		if target == null or target == source or affected.has(target):
			continue
		affected.append(target)
		if target.has_method(&"apply_explosion"):
			target.apply_explosion(center, data, owner_index, source)
		elif target.has_method(&"take_damage"):
			target.take_damage(data.damage, source)
		if target is RigidBody2D and not target is Bomb:
			var body := target as RigidBody2D
			var dir := (body.global_position - center).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			body.apply_central_impulse(dir * data.knockback * body.mass)
	return affected


func _on_sprite_finished() -> void:
	# Las partículas siguen un poco más que el destello.
	sprite.visible = false
	_linger = debris.lifetime


func _process(delta: float) -> void:
	if not active or _linger < 0.0:
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
	sprite.stop()
	debris.emitting = false
