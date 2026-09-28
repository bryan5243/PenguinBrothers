class_name CoopCamera
extends Camera2D
## Cámara que sigue a los jugadores vivos. En cooperativo encuadra a ambos alejándose
## hasta `min_zoom`; si aun así no caben, los mantiene dentro de la pantalla
## (ninguno puede alejarse más: estilo arcade). Respeta los límites del nivel.
## Colócala después de los jugadores en el árbol para que se actualice tras moverlos.

## Zoom normal (1 = sin zoom) y zoom mínimo al separarse los jugadores.
@export var max_zoom := 1.0
@export var min_zoom := 0.72
@export var zoom_speed := 3.0
## Espacio libre alrededor de los jugadores (píxeles de pantalla).
@export var margin := Vector2(220.0, 160.0)
## Desplazamiento del encuadre (negativo = ver más por encima de los jugadores).
@export var view_offset := Vector2(0.0, -80.0)
## Distancia mínima al borde de la pantalla al retener a los jugadores.
@export var screen_edge_padding := 36.0
@export var keep_players_on_screen := true
## Temblor al explotar una bomba (px máximos) y cuánto dura en segundos.
@export var shake_strength := 7.0
@export var shake_duration := 0.25

var targets: Array[Node2D] = []
var _shake := 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = true
	make_current()
	EventBus.bomb_exploded.connect(_on_bomb_exploded)
	_update_targets()
	if not targets.is_empty():
		global_position = _center()
		reset_smoothing()


func _physics_process(delta: float) -> void:
	_update_shake(delta)
	_update_targets()
	if targets.is_empty():
		return
	var rect := _targets_rect()
	var view := get_viewport_rect().size
	var needed := minf(view.x / (rect.size.x + margin.x * 2.0), view.y / (rect.size.y + margin.y * 2.0))
	var target_zoom := clampf(needed, min_zoom, max_zoom)
	var z := lerpf(zoom.x, target_zoom, minf(1.0, delta * zoom_speed))
	zoom = Vector2(z, z)
	global_position = _center()
	if keep_players_on_screen and targets.size() > 1 and needed < min_zoom:
		_keep_on_screen()


func _update_targets() -> void:
	targets.clear()
	for node in get_tree().get_nodes_in_group(&"players"):
		var p := node as Player
		if p and p.is_inside_tree() and p.is_alive():
			targets.append(p)


func _targets_rect() -> Rect2:
	var rect := Rect2(targets[0].global_position, Vector2.ZERO)
	for t in targets:
		rect = rect.expand(t.global_position)
		rect = rect.expand(t.global_position + Vector2(0.0, -70.0))
	return rect


func _center() -> Vector2:
	return _targets_rect().get_center() + view_offset


## Centro real de la vista tras aplicar los límites del nivel.
func _clamped_view_center() -> Vector2:
	var half := get_viewport_rect().size / zoom / 2.0
	var c := global_position
	c.x = clampf(c.x, limit_left + half.x, maxf(limit_left + half.x, limit_right - half.x))
	c.y = clampf(c.y, limit_top + half.y, maxf(limit_top + half.y, limit_bottom - half.y))
	return c


func _keep_on_screen() -> void:
	var half := get_viewport_rect().size / zoom / 2.0
	var c := _clamped_view_center()
	var left := c.x - half.x + screen_edge_padding
	var right := c.x + half.x - screen_edge_padding
	for t in targets:
		var p := t as Player
		if p.global_position.x < left:
			p.global_position.x = left
			p.velocity.x = maxf(p.velocity.x, 0.0)
		elif p.global_position.x > right:
			p.global_position.x = right
			p.velocity.x = minf(p.velocity.x, 0.0)


func _on_bomb_exploded(_pos: Vector2, radius: float, _owner: int) -> void:
	_shake = maxf(_shake, shake_duration * clampf(radius / 120.0, 0.5, 1.5))


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta)
	var k := _shake / shake_duration
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength * k
