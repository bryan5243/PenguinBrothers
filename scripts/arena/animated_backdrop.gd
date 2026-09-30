class_name AnimatedBackdrop
extends Node2D
## Fondo animado de una arena: cielo en degradado arriba, la imagen base de la playa abajo
## (a lo ancho de la pantalla) y, encima, la franja de mar fundiendo un fotograma con el
## siguiente (shader sea_crossfade). La tierra, las cascadas y las palmeras quedan quietas.
## Los fotogramas salen de tools/sprites/extract_background_frames.py.

const SHADER := preload("res://shaders/sea_crossfade.gdshader")

@export var base: Texture2D
@export var frames: Array[Texture2D] = []
@export var sea_mask: Texture2D
@export var area_size := Vector2(960, 720)
## Alto que debe cubrir la imagen desde abajo (lo de arriba lo tapa el marcador; si la imagen
## no llega, se completa con el degradado del cielo). La imagen se centra en horizontal.
@export var cover_height := 672.0
## Segundos que tarda en pasar de un fotograma al siguiente.
@export var frame_time := 0.55
@export var sky_top := Color(0.12, 0.35, 0.85)
@export var sky_bottom := Color(0.35, 0.62, 0.95)

var current := 0
var _t := 0.0
var _overlay: Sprite2D
var _material: ShaderMaterial


func _ready() -> void:
	if base == null:
		return
	var scale_f := maxf(area_size.x / base.get_width(), cover_height / base.get_height())
	var image_h := base.get_height() * scale_f
	var top := area_size.y - image_h
	var left := (area_size.x - base.get_width() * scale_f) * 0.5
	# Cielo que continúa el de la imagen hacia arriba.
	var grad := Gradient.new()
	grad.set_color(0, sky_top)
	grad.set_color(1, sky_bottom)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 4
	gtex.height = 64
	var sky := Sprite2D.new()
	sky.name = "Sky"
	sky.texture = gtex
	sky.centered = false
	sky.scale = Vector2(area_size.x / 4.0, (maxf(top, 0.0) + 4.0) / 64.0)
	sky.visible = top > 0.0
	add_child(sky)
	var base_sprite := Sprite2D.new()
	base_sprite.name = "Base"
	base_sprite.texture = base
	base_sprite.centered = false
	base_sprite.position = Vector2(left, top)
	base_sprite.scale = Vector2(scale_f, scale_f)
	add_child(base_sprite)
	if frames.size() >= 2 and sea_mask:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"mask", sea_mask)
		_overlay = Sprite2D.new()
		_overlay.name = "Sea"
		_overlay.texture = base
		_overlay.centered = false
		_overlay.position = base_sprite.position
		_overlay.scale = base_sprite.scale
		_overlay.material = _material
		add_child(_overlay)
		_apply()


func _process(delta: float) -> void:
	if _material == null:
		return
	_t += delta / maxf(frame_time, 0.05)
	if _t >= 1.0:
		_t -= 1.0
		current = (current + 1) % frames.size()
	_apply()


func _apply() -> void:
	_material.set_shader_parameter(&"frame_a", frames[current])
	_material.set_shader_parameter(&"frame_b", frames[(current + 1) % frames.size()])
	_material.set_shader_parameter(&"blend", _t)
