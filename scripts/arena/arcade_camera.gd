class_name ArcadeCamera
extends Camera2D
## Cámara arcade de pantalla fija: encuadra la arena completa y NO sigue a nadie.
## Solo tiembla un poco con las explosiones.

@export var arena_size := Vector2(960, 720)
@export var shake_strength := 6.0
@export var shake_duration := 0.22

var _shake := 0.0


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position = arena_size * 0.5
	zoom = Vector2.ONE
	position_smoothing_enabled = false
	limit_left = 0
	limit_top = 0
	limit_right = int(arena_size.x)
	limit_bottom = int(arena_size.y)
	make_current()
	EventBus.bomb_exploded.connect(_on_bomb_exploded)


func _on_bomb_exploded(_pos: Vector2, radius: float, _owner: int) -> void:
	_shake = maxf(_shake, shake_duration * clampf(radius / 110.0, 0.5, 1.5))


func _process(delta: float) -> void:
	if _shake <= 0.0:
		offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta)
	var k := _shake / shake_duration
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * k
