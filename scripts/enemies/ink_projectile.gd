class_name InkProjectile
extends Area2D
## Chorro de tinta del pulpo: va en línea recta, daña al primer jugador que toca y
## desaparece al chocar con el mundo o al recorrer `max_distance`.

var direction := 1
var speed := 260.0
var max_distance := 520.0
var damage := 1
var texture: Texture2D
var _travelled := 0.0


func _init() -> void:
	add_to_group(&"enemy_attacks")


func _ready() -> void:
	collision_layer = 0
	collision_mask = (1 << 1) | 1   # jugadores y mundo
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.flip_h = direction < 0
	if texture:
		sprite.scale = Vector2.ONE * (28.0 / maxf(texture.get_width(), 1.0))
	add_child(sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position.x += direction * step
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		# Un pingüino deslizándose es inmune: la tinta pasa sin tocarlo.
		if (body as Player).config.slide_immune_to_enemies and (body as Player).is_sliding():
			return
		if (body as Player).is_alive():
			(body as Player).take_damage(damage, self)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
