@tool
class_name Ladder
extends Area2D
## Escalera trepable. El origen está en la base; la parte superior queda en y = -height.
## Coloca la parte superior a la altura de la plataforma a la que lleva: al llegar arriba
## el jugador queda de pie sobre ella. Se dibuja con un placeholder hasta tener su sprite.

const RAIL_WIDTH := 6.0
const RUNG_SPACING := 22.0
const RAIL_COLOR := Color(0.55, 0.34, 0.16)
const RUNG_COLOR := Color(0.68, 0.45, 0.22)

@export var height := 240.0:
	set(value):
		height = maxf(32.0, value)
		_update_shape()
		queue_redraw()
@export var width := 44.0:
	set(value):
		width = maxf(16.0, value)
		_update_shape()
		queue_redraw()
## Margen por encima de la parte superior para poder bajar desde la plataforma.
@export var top_grab_margin := 14.0
## Si se asigna, se dibuja esta textura en lugar del placeholder.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 << 4  # capa 5: objects
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(&"ladders")
	_update_shape()


## Coordenada Y global de la parte superior (donde termina de subir el jugador).
func top_y() -> float:
	return global_position.y - height


func center_x() -> float:
	return global_position.x


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = get_node_or_null(^"Shape") as CollisionShape2D
		if _shape == null:
			_shape = CollisionShape2D.new()
			_shape.name = "Shape"
			add_child(_shape)
	var rect := _shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		_shape.shape = rect
	rect.size = Vector2(width * 0.5, height + top_grab_margin)
	_shape.position = Vector2(0.0, -(height + top_grab_margin) * 0.5)


func _draw() -> void:
	if texture:
		draw_texture_rect(texture, Rect2(-width * 0.5, -height, width, height), true)
		return
	var half := width * 0.5
	var y := -RUNG_SPACING * 0.5
	while y > -height:
		draw_rect(Rect2(-half, y - 3.0, width, 6.0), RUNG_COLOR)
		y -= RUNG_SPACING
	draw_rect(Rect2(-half - RAIL_WIDTH * 0.5, -height, RAIL_WIDTH, height), RAIL_COLOR)
	draw_rect(Rect2(half - RAIL_WIDTH * 0.5, -height, RAIL_WIDTH, height), RAIL_COLOR)
