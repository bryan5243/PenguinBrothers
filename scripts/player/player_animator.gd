class_name PlayerAnimator
extends AnimatedSprite2D
## Capa visual del jugador, separada de la lógica de movimiento.
## Los estados piden animaciones por nombre estándar; si el SpriteFrames todavía no tiene
## esa animación se usa un respaldo en lugar de fallar. También gestiona efectos visuales
## que no afectan a la jugabilidad: parpadeo, destello de daño y estirar/aplastar.
##
## Normalización (ver docs/GAMEPLAY.md, «Sprites»): todos los fotogramas de un personaje
## comparten lienzo, con los pies en el borde inferior y el centro del cuerpo en el centro.
## Con `offset = (0, -alto/2)` el origen de este nodo queda en los pies (GroundPoint) en
## TODAS las animaciones, así que cambiar de animación no mueve ni escala al personaje.
## La escala global la aplica VisualRoot (Player), nunca este nodo por animación.

## Nombres estándar de animación (ver docs/GAMEPLAY.md).
const IDLE := &"idle"
const WALK := &"walk"
const RUN := &"run"
const JUMP := &"jump"
const FALL := &"fall"
const LAND := &"land"
const CROUCH := &"crouch"
const SLIDE := &"slide"
const CLIMB := &"climb"
const LIFT := &"lift"
const CARRY := &"carry"
const THROW := &"throw"
const PLACE_BOMB := &"place_bomb"
const HURT := &"hurt"
const DEATH := &"death"
const VICTORY := &"victory"
const SWIM := &"swim"
const ATTACK := &"attack"
const FIRE_ATTACK := &"fire_attack"
const DROP := &"drop"

## Con algo en las manos, estas animaciones se sustituyen por `carry`.
const CARRY_VARIANTS: Array[StringName] = [&"idle", &"walk", &"run", &"land"]
## Animaciones «llevando un objeto con estilo» (p. ej. barril dibujado en el sprite):
## nombre estándar -> sufijo de `carry_<estilo>_<sufijo>`. Si el SpriteFrames no las tiene
## (pingüino rosa), se usa `carry` normal y el objeto se sigue dibujando aparte.
const STYLED_CARRY := {
	&"idle": &"idle", &"walk": &"walk", &"run": &"run", &"land": &"land", &"jump": &"jump",
	&"fall": &"jump", &"crouch": &"crouch", &"lift": &"lift", &"throw": &"throw", &"drop": &"drop",
}
## Estas interrumpen cualquier acción de una sola vez en curso.
const PRIORITY: Array[StringName] = [&"hurt", &"death", &"climb", &"slide", &"victory"]
## Duración máxima de una acción de una sola vez (por si la animación fuera en bucle).
const ONESHOT_MAX_TIME := 0.6

## Respaldo cuando falta una animación.
const FALLBACKS := {
	&"run": &"walk", &"land": &"idle", &"crouch": &"idle", &"slide": &"crouch",
	&"climb": &"idle", &"lift": &"idle", &"carry": &"idle", &"throw": &"idle",
	&"place_bomb": &"crouch", &"hurt": &"fall", &"death": &"hurt",
	&"victory": &"idle", &"fall": &"jump", &"walk": &"idle", &"jump": &"idle",
	&"swim": &"fall", &"attack": &"throw", &"fire_attack": &"attack",
}

@export var blue_penguin_frames: SpriteFrames
@export var pink_penguin_frames: SpriteFrames
@export var blink_rate := 14.0
@export var squash_recovery := 12.0
@export var hurt_flash_color := Color(1.8, 0.55, 0.55)

var _blinking := false
var _blink_time := 0.0
var _squash := Vector2.ONE
var _flash_time := 0.0
var _facing := 1
## Lleva algo en las manos: idle/walk/run/land se muestran como `carry`.
var carrying := false:
	set(value):
		if value == carrying:
			return
		carrying = value
		if _oneshot == &"" and _requested != &"":
			play_animation(_requested)
## Estilo del objeto que lleva (&"barrel"...). Con animaciones propias el objeto va dibujado.
var carry_style := &""
## Animación de acción de una sola vez (lanzar, colocar, recoger) que se superpone a la del
## estado; al terminar vuelve a la última animación pedida por el estado.
var _oneshot := &""
var _oneshot_left := 0.0
var _requested := &""
## Rectángulo visible (sin transparencia) de cada textura, para la depuración.
var _used_rects := {}


func setup(character: int) -> void:
	var frames: SpriteFrames = blue_penguin_frames if character == 0 else pink_penguin_frames
	if frames:
		sprite_frames = frames
	centered = true
	_align_feet()
	reset_visual()
	play_animation(IDLE)


## El origen del nodo queda en los pies: los fotogramas tienen los pies en el borde inferior.
## El desplazamiento es el mismo para todas las animaciones (lienzo común).
func _align_feet() -> void:
	offset = Vector2(0.0, -get_canvas_size().y * 0.5)


## Tamaño del lienzo común de los fotogramas del personaje.
func get_canvas_size() -> Vector2:
	if sprite_frames == null:
		return Vector2.ZERO
	if sprite_frames.has_meta(&"canvas_size"):
		return Vector2(sprite_frames.get_meta(&"canvas_size"))
	if sprite_frames.has_animation(IDLE):
		var tex := sprite_frames.get_frame_texture(IDLE, 0)
		if tex:
			return tex.get_size()
	return Vector2.ZERO


## Altura en píxeles del dibujo de referencia (idle); base de la escala global.
func get_reference_height() -> float:
	if sprite_frames and sprite_frames.has_meta(&"reference_height"):
		return float(sprite_frames.get_meta(&"reference_height"))
	return get_canvas_size().y


## Escala visual única para este personaje: la altura de referencia pasa a medir
## `visual_height` píxeles, multiplicada por el ajuste global `visual_scale`.
func get_base_scale(visual_height: float, visual_scale := 1.0) -> float:
	var ref := get_reference_height()
	if ref <= 0.0:
		return visual_scale
	return visual_height / ref * visual_scale


## Caja del dibujo visible del fotograma actual, en coordenadas locales de este nodo
## (sin el estirar/aplastar). Solo para depuración y pruebas.
func get_visual_rect() -> Rect2:
	if sprite_frames == null or not sprite_frames.has_animation(animation):
		return Rect2()
	var tex := sprite_frames.get_frame_texture(animation, frame)
	if tex == null:
		return Rect2()
	if not _used_rects.has(tex):
		_used_rects[tex] = Rect2(tex.get_image().get_used_rect())
	var used: Rect2 = _used_rects[tex]
	var size := tex.get_size()
	var top_left := offset - size * 0.5 if centered else offset
	if flip_h:
		used.position.x = size.x - used.end.x
	return Rect2(top_left + used.position, used.size)


func play_animation(anim: StringName, restart := false) -> void:
	_requested = anim
	var styled := styled_carry(anim, carry_style) if carrying else &""
	if styled != &"":
		anim = styled
	elif carrying and CARRY_VARIANTS.has(anim):
		anim = CARRY
	if _oneshot != &"":
		if not PRIORITY.has(anim):
			return
		_oneshot = &""
	var resolved := resolve(anim)
	if resolved == &"":
		return
	speed_scale = 1.0
	if restart or animation != resolved or not is_playing():
		play(resolved)


## ¿Tiene este personaje animaciones propias para llevar objetos de ese estilo?
func has_styled_carry(style: StringName) -> bool:
	return style != &"" and sprite_frames != null \
		and sprite_frames.has_animation(StringName("carry_%s_idle" % style))


## Animación «carry_<estilo>_…» equivalente a `anim`, o vacío si no existe.
func styled_carry(anim: StringName, style: StringName) -> StringName:
	if style == &"" or sprite_frames == null or not STYLED_CARRY.has(anim):
		return &""
	var name := StringName("carry_%s_%s" % [style, STYLED_CARRY[anim]])
	if sprite_frames.has_animation(name):
		return name
	# Sin versión propia de correr/aterrizar/saltar: la de andar o la de quieto.
	for alt in [&"walk", &"idle"]:
		var fallback := StringName("carry_%s_%s" % [style, alt])
		if anim in [&"run", &"land", &"jump", &"fall"] and sprite_frames.has_animation(fallback):
			return fallback
	return &""


## Reproduce una acción corta (THROW, PLACE_BOMB, LIFT, DROP) por encima de la animación del
## estado. `style`: estilo del objeto (lanzar/soltar un barril usa sus propias animaciones).
func play_oneshot(anim: StringName, style := &"") -> void:
	var styled := styled_carry(anim, style if style != &"" else (carry_style if carrying else &""))
	var resolved := styled if styled != &"" else resolve(anim)
	if resolved == &"":
		return
	_oneshot = resolved
	var fps := sprite_frames.get_animation_speed(resolved)
	var count := sprite_frames.get_frame_count(resolved)
	_oneshot_left = minf(ONESHOT_MAX_TIME, count / maxf(fps, 1.0) + 0.12)
	speed_scale = 1.0
	play(resolved)


func is_playing_oneshot() -> bool:
	return _oneshot != &""


func _end_oneshot() -> void:
	_oneshot = &""
	if _requested != &"":
		play_animation(_requested, true)


## Devuelve la animación disponible más cercana a `anim`, o vacío si no hay ninguna.
func resolve(anim: StringName) -> StringName:
	if sprite_frames == null:
		return &""
	var current := anim
	for i in 6:
		if sprite_frames.has_animation(current):
			return current
		if not FALLBACKS.has(current):
			break
		current = FALLBACKS[current]
	return &""


## Ajusta la velocidad de la animación actual (p. ej. caminar según la velocidad real).
func set_playback_speed(value: float) -> void:
	if _oneshot != &"":
		return
	speed_scale = maxf(0.0, value)


## Voltea con flip_h: como el lienzo está centrado en el cuerpo, los pies (origen)
## no se mueven al girar.
func set_facing(direction: int) -> void:
	_facing = direction
	flip_h = direction < 0


## Estira (valores > 1 en y) o aplasta (< 1) el sprite; vuelve solo a la normalidad.
func squash(amount: Vector2) -> void:
	_squash = amount


func flash() -> void:
	_flash_time = 0.15


func set_blinking(active: bool) -> void:
	_blinking = active
	_blink_time = 0.0
	if not active:
		visible = true


func reset_visual() -> void:
	rotation = 0.0
	_oneshot = &""
	carrying = false
	carry_style = &""
	_squash = Vector2.ONE
	_flash_time = 0.0
	_blinking = false
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE


func _process(delta: float) -> void:
	if _oneshot != &"":
		_oneshot_left -= delta
		if _oneshot_left <= 0.0:
			_end_oneshot()
	_squash = _squash.lerp(Vector2.ONE, minf(1.0, delta * squash_recovery))
	# Solo el efecto pasajero de estirar/aplastar; vuelve siempre a 1.
	scale = _squash
	if _flash_time > 0.0:
		_flash_time -= delta
		modulate = hurt_flash_color
	else:
		modulate = Color.WHITE
	if _blinking:
		_blink_time += delta
		visible = int(_blink_time * blink_rate) % 2 == 0
