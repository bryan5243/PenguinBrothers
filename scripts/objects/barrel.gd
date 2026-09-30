class_name Barrel
extends CarryableBody
## Barril arcade: se recoge, se lleva, se lanza (rueda y hace daño a los enemigos que
## golpea) y se rompe con explosiones o al estrellarse fuerte contra una pared, soltando
## su botín (puntos, power-ups, vidas...). Datos en BarrelData.

signal broken(by_player: int)

const LAYER := 1 << 4                 # objetos
const MASK := 1 | (1 << 5)            # mundo y plataformas atravesables
const ENEMY_LAYER := 1 << 2

@export var data: BarrelData

var is_broken := false
## Jugador que lo lanzó (para puntos y combos) y si va lanzado (hace daño).
var owner_index := -1
var is_thrown := false
var rng := RandomNumberGenerator.new()
var _hit_targets: Array[Node] = []

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var hit_area: Area2D = $HitArea


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = MASK
	rng.randomize()
	hit_area.collision_layer = 0
	hit_area.collision_mask = ENEMY_LAYER
	hit_wall.connect(_on_hit_wall)
	if data:
		apply_motion(data)
		throw_force = data.throw_force
		sprite.texture = data.texture
		var rect := RectangleShape2D.new()
		rect.size = data.size
		shape.shape = rect
		(hit_area.get_node("Shape") as CollisionShape2D).shape = rect
		if data.texture:
			sprite.scale = Vector2.ONE * (data.size.x / data.texture.get_width())


func can_be_picked_up() -> bool:
	return not is_broken and holder == null and not is_thrown


## PlayerBombs lo avisa al lanzarlo: a partir de ahora hace daño al golpear.
func on_thrown(player_index: int) -> void:
	owner_index = player_index
	is_thrown = true
	_hit_targets.clear()


func release(initial_velocity: Vector2) -> void:
	super.release(initial_velocity)
	_hit_targets.clear()


func apply_explosion(info: ExplosionInfo) -> void:
	if not is_broken and info.break_power >= data.hardness:
		break_apart(info.owner_index)


func take_damage(_amount: int, source: Node = null) -> bool:
	var owner_index: int = source.get("owner_index") if source and "owner_index" in source else -1
	break_apart(owner_index)
	return true


func break_apart(by_player := -1) -> void:
	if is_broken:
		return
	is_broken = true
	if holder and holder.has_method(&"on_held_object_gone"):
		holder.on_held_object_gone(self)
	holder = null
	collision_layer = 0
	collision_mask = 0
	var drop_parent := _items_parent()
	if data.drop_table:
		for item in data.drop_table.roll(rng):
			PowerUp.spawn(item, global_position + Vector2(0, -8), drop_parent)
	if by_player >= 0:
		ScoreManager.add_points(by_player, data.points if data.points > 0 else ScoreManager.table.barrel,
			global_position + Vector2(0, -data.size.y))
	BreakEffect.spawn(get_parent(), global_position, data.debris_color)
	AudioManager.play_sfx(data.break_sfx)
	broken.emit(by_player)
	queue_free()


func _physics_process(delta: float) -> void:
	if is_broken or holder != null:
		return
	arcade_step(delta)
	if is_on_floor():
		sprite.rotation += velocity.x / maxf(data.size.y * 0.5, 1.0) * delta
	if is_thrown:
		if velocity.length() >= data.hit_min_speed:
			_hit_enemies()
		elif is_on_floor() and absf(velocity.x) < 5.0:
			is_thrown = false   # se detuvo: vuelve a poder recogerse


## Consulta directa de la forma (sin el retraso de un frame de Area2D): a esta velocidad
## el barril puede cruzar a un enemigo en pocos frames.
func _hit_enemies() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = ENEMY_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body := hit["collider"] as Node
		if body and not body.has_method(&"take_damage") and body.get_parent() \
				and body.get_parent().has_method(&"take_damage"):
			body = body.get_parent()   # zona de golpe de un enemigo
		if body == null or _hit_targets.has(body) or not body.has_method(&"take_damage"):
			continue
		_hit_targets.append(body)
		body.take_damage(data.hit_damage, self)
		# Arcade: el barril se rompe al golpear.
		break_apart(owner_index)
		return


func _on_hit_wall(speed: float) -> void:
	if is_thrown and data.break_speed > 0.0 and speed >= data.break_speed:
		break_apart(owner_index)


func _items_parent() -> Node:
	var arena := get_parent()
	while arena and not arena is Arena:
		arena = arena.get_parent()
	return arena.get_node("Items") if arena and arena.has_node("Items") else get_parent()
