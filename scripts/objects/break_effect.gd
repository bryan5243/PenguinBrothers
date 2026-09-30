class_name BreakEffect
extends CPUParticles2D
## Fragmentos al romperse un objeto (caja, barril, bloque). Se borra solo.


static func spawn(parent: Node, at: Vector2, color: Color) -> BreakEffect:
	var fx := BreakEffect.new()
	fx.position = at
	fx.color = color
	parent.add_child(fx)
	return fx


func _ready() -> void:
	one_shot = true
	amount = 18
	lifetime = 0.7
	explosiveness = 1.0
	direction = Vector2.UP
	spread = 80.0
	gravity = Vector2(0, 900)
	initial_velocity_min = 120.0
	initial_velocity_max = 300.0
	angular_velocity_min = -360.0
	angular_velocity_max = 360.0
	scale_amount_min = 4.0
	scale_amount_max = 8.0
	z_index = 8
	emitting = true
	finished.connect(queue_free)
