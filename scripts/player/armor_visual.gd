class_name ArmorVisual
extends Node2D
## Protección visual de la armadura: un escudo que gira alrededor del pingüino, con un
## destello por cada golpe que aún puede absorber. Desaparece al gastarse.

const COLOR := Color(0.55, 0.85, 1.0)
const RADIUS := 44.0

var hits := 0
var _t := 0.0


func set_hits(value: int) -> void:
	hits = value
	visible = hits > 0
	queue_redraw()


func _ready() -> void:
	z_index = 4
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if hits <= 0:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(COLOR.r, COLOR.g, COLOR.b, 0.12 + 0.08 * pulse))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(COLOR.r, COLOR.g, COLOR.b, 0.8), 2.5)
	for i in hits * 3:
		var a := _t * 2.2 + TAU * i / float(hits * 3)
		draw_circle(Vector2.from_angle(a) * RADIUS, 4.0, Color(1, 1, 1, 0.9))
