class_name PlayerDebugOverlay
extends Node2D
## Superposición de depuración del jugador (F1 en los niveles de prueba):
##   verde    -> CollisionShape2D (cuerpo físico)
##   amarillo -> GroundPoint (pies / apoyo)
##   cian     -> centro del cuerpo físico
##   magenta  -> caja del dibujo visible del fotograma actual
## Permite comprobar que cambiar de animación no mueve el sprite ni la colisión.
## El interruptor es global (todas las instancias a la vez).

static var enabled := false

const BODY_COLOR := Color(0.2, 1.0, 0.3)
const GROUND_COLOR := Color(1.0, 0.9, 0.1)
const CENTER_COLOR := Color(0.2, 0.9, 1.0)
const VISUAL_COLOR := Color(1.0, 0.3, 0.9)

@export var body_shape: CollisionShape2D
@export var ground_point: Node2D
@export var visual_root: Node2D
@export var animator: PlayerAnimator


static func toggle() -> void:
	enabled = not enabled


func _ready() -> void:
	z_index = 50


func _process(_delta: float) -> void:
	visible = enabled
	if enabled:
		queue_redraw()


func _draw() -> void:
	if body_shape and body_shape.shape is CapsuleShape2D:
		var cap := body_shape.shape as CapsuleShape2D
		var c := body_shape.position
		var half := maxf(cap.height * 0.5 - cap.radius, 0.0)
		draw_arc(c + Vector2(0, -half), cap.radius, PI, TAU, 16, BODY_COLOR, 1.5)
		draw_arc(c + Vector2(0, half), cap.radius, 0.0, PI, 16, BODY_COLOR, 1.5)
		draw_line(c + Vector2(-cap.radius, -half), c + Vector2(-cap.radius, half), BODY_COLOR, 1.5)
		draw_line(c + Vector2(cap.radius, -half), c + Vector2(cap.radius, half), BODY_COLOR, 1.5)
		draw_circle(c, 3.0, CENTER_COLOR)
	if animator and visual_root:
		var r := animator.get_visual_rect()
		var xf := visual_root.transform * animator.transform
		var pts := PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y),
			xf * r.end, xf * Vector2(r.position.x, r.end.y), xf * r.position])
		draw_polyline(pts, VISUAL_COLOR, 1.0)
	if ground_point:
		var g := ground_point.position
		draw_line(g + Vector2(-14, 0), g + Vector2(14, 0), GROUND_COLOR, 2.0)
		draw_line(g + Vector2(0, -6), g + Vector2(0, 6), GROUND_COLOR, 2.0)
