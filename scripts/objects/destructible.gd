class_name Destructible
extends StaticBody2D
## Objeto sólido del escenario que puede romperse (caja, bloque de piedra, pared...).
## Datos en DestructibleData: vida, dureza, puntos, botín (drop_table) y efecto.
## Solo lo dañan las explosiones con poder suficiente (break_power >= hardness) y los
## golpes directos (take_damage) si no es duro.

signal broken(by_player: int)

const LAYER := 1 | (1 << 4)   # mundo (los jugadores chocan) + objetos (lo encuentran las explosiones)

@export var data: DestructibleData

var health := 1
var is_broken := false
## Generador propio del botín (las pruebas pueden fijar la semilla).
var rng := RandomNumberGenerator.new()

var _flash := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	rng.randomize()
	if data:
		health = data.max_health
		sprite.texture = data.texture
		var rect := RectangleShape2D.new()
		rect.size = data.size
		shape.shape = rect
		shape.position = Vector2(0, -data.size.y * 0.5)
		sprite.position = shape.position
		if data.texture:
			sprite.scale = data.size / data.texture.get_size()


## Alcanzado por una explosión: solo le afecta si el poder de destrucción basta.
func apply_explosion(info: ExplosionInfo) -> void:
	if is_broken or data == null or not data.destructible:
		return
	if info.break_power < data.hardness:
		_flash = 0.12   # la bomba no puede con él: solo tiembla
		return
	_hurt(info.damage, info.owner_index)


## Golpe directo (barril lanzado, ataque...). No afecta a los objetos duros.
func take_damage(amount: int, source: Node = null) -> bool:
	if is_broken or data == null or not data.destructible or data.hardness > 1:
		return false
	var owner_index: int = source.get("owner_index") if source and "owner_index" in source else -1
	_hurt(amount, owner_index)
	return true


func break_apart(by_player := -1) -> void:
	if is_broken:
		return
	is_broken = true
	collision_layer = 0
	var parent := get_parent()
	var drop_parent := _items_parent()
	if data.drop_table:
		for item in data.drop_table.roll(rng):
			PowerUp.spawn(item, global_position + Vector2(0, -data.size.y * 0.5), drop_parent)
	if by_player >= 0:
		ScoreManager.add_points(by_player, data.points if data.points > 0 else ScoreManager.table.destructible,
			global_position + Vector2(0, -data.size.y))
	BreakEffect.spawn(parent, global_position + Vector2(0, -data.size.y * 0.5), data.debris_color)
	AudioManager.play_sfx(data.break_sfx)
	broken.emit(by_player)
	queue_free()


func _hurt(amount: int, by_player: int) -> void:
	health -= amount
	_flash = 0.12
	if health <= 0:
		break_apart(by_player)


func _items_parent() -> Node:
	var arena := get_parent()
	while arena and not arena is Arena:
		arena = arena.get_parent()
	return arena.get_node("Items") if arena and arena.has_node("Items") else get_parent()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(1.8, 1.8, 1.8) if _flash > 0.0 else Color.WHITE
