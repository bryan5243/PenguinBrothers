class_name ScreenTransition
extends CanvasLayer
## Transiciones arcade entre pantallas (nunca un desplazamiento de cámara):
##   fade  -> fundido a negro
##   flash -> destello blanco
##   wipe  -> cortina negra que barre de izquierda a derecha
## `cover()` tapa la pantalla y `reveal()` la destapa; Main cambia la escena entre ambas.

const DURATION := 0.22

var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0, 0, 0, 0)
	add_child(_rect)


func is_covering() -> bool:
	return _rect.color.a > 0.01


func cover(kind: StringName) -> void:
	var size := _rect.get_viewport_rect().size
	_rect.position = Vector2.ZERO
	_rect.size = size
	match kind:
		&"flash":
			_rect.color = Color(1, 1, 1, 0)
			await _tween_alpha(1.0, DURATION * 0.5)
		&"wipe":
			_rect.color = Color(0, 0, 0, 1)
			_rect.position.x = -size.x
			var t := create_tween()
			t.tween_property(_rect, "position:x", 0.0, DURATION)
			await t.finished
		_:
			_rect.color = Color(0, 0, 0, 0)
			await _tween_alpha(1.0, DURATION)


func reveal(kind: StringName) -> void:
	var size := _rect.get_viewport_rect().size
	match kind:
		&"wipe":
			var t := create_tween()
			t.tween_property(_rect, "position:x", size.x, DURATION)
			await t.finished
			_rect.color.a = 0.0
			_rect.position.x = 0.0
		&"flash":
			await _tween_alpha(0.0, DURATION * 1.5)
		_:
			await _tween_alpha(0.0, DURATION)


func _tween_alpha(target: float, time: float) -> void:
	var t := create_tween()
	t.tween_property(_rect, "color:a", target, time)
	await t.finished
