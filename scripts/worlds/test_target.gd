class_name TestTarget
extends StaticBody2D
## Diana de prueba (solo niveles de prueba) para comprobar el daño de las explosiones
## hasta que existan los enemigos (Fase 8). Está en la capa de enemigos, tiene un
## HealthComponent, muestra su vida y se recupera sola al cabo de un rato.

@export var max_health := 6
@export var recover_time := 3.0
@export var size := Vector2(40, 56)

var health: HealthComponent
var _flash := 0.0
var _recover := 0.0
var _label: Label


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y * 0.5)
	add_child(shape)
	health = HealthComponent.new()
	health.name = "Health"
	health.max_health = max_health
	add_child(health)
	health.damaged.connect(func(_a: int, _s: Node) -> void: _flash = 0.15)
	_label = Label.new()
	_label.position = Vector2(-30, -size.y - 26)
	_label.size = Vector2(60, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)


func take_damage(amount: int, source: Node = null) -> bool:
	var ok := health.take_damage(amount, source)
	_recover = recover_time
	return ok


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _recover > 0.0:
		_recover -= delta
		if _recover <= 0.0:
			health.reset()
	_label.text = "%d/%d" % [health.current_health, health.max_health]
	queue_redraw()


func _draw() -> void:
	var color := Color(1, 0.4, 0.4) if _flash > 0.0 else (Color(0.4, 0.4, 0.45) if health.is_dead else Color(0.9, 0.55, 0.2))
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y), size), color)
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y), size), Color(0.2, 0.1, 0.05), false, 2.0)
	draw_circle(Vector2(0, -size.y * 0.6), 8.0, Color.WHITE)
	draw_circle(Vector2(0, -size.y * 0.6), 4.0, Color(0.8, 0.1, 0.1))
