extends RefCounted
## Pruebas de la normalización de sprites del jugador (lienzo común, pies, escala única,
## colisión independiente de la animación, flip_h). Las ejecuta tests/smoke_test.gd.

const BLUE_FRAMES := "res://assets/characters/blue_penguin/blue_penguin_frames.tres"
const PINK_FRAMES := "res://assets/characters/pink_penguin/pink_penguin_frames.tres"
const REQUIRED := [&"idle", &"walk", &"run", &"jump", &"fall", &"land", &"crouch", &"slide",
	&"climb", &"lift", &"carry", &"throw", &"place_bomb", &"hurt", &"death", &"victory",
	&"attack", &"fire_attack"]

var t: Node


func run(test: Node) -> void:
	t = test
	_frames_normalized(load(BLUE_FRAMES) as SpriteFrames, "azul", true)
	_frames_normalized(load(PINK_FRAMES) as SpriteFrames, "rosa", false)
	await _player_visual(Player.Character.BLUE_PENGUIN, "azul")
	await _player_visual(Player.Character.PINK_PENGUIN, "rosa")


func _frames_normalized(frames: SpriteFrames, label: String, full_set: bool) -> void:
	t.check(frames != null and frames.has_meta(&"canvas_size") and frames.has_meta(&"reference_height"),
		"%s: SpriteFrames con lienzo y altura de referencia" % label)
	if frames == null:
		return
	if full_set:
		var missing: Array[StringName] = []
		for anim in REQUIRED:
			if not frames.has_animation(anim):
				missing.append(anim)
		t.check(missing.is_empty(), "%s: tiene todas las animaciones requeridas %s" % [label, missing])
	var canvas: Vector2i = frames.get_meta(&"canvas_size")
	var same_size := true
	var feet_on_base := true
	var bad: Array[String] = []
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			var tex := frames.get_frame_texture(anim, i)
			if Vector2i(tex.get_size()) != canvas:
				same_size = false
				bad.append("%s[%d] tamaño" % [anim, i])
			var used := tex.get_image().get_used_rect()
			if used.end.y != canvas.y:
				feet_on_base = false
				bad.append("%s[%d] pies" % [anim, i])
	t.check(same_size, "%s: todos los fotogramas comparten el lienzo %s %s" % [label, canvas, bad])
	t.check(feet_on_base, "%s: todos los fotogramas apoyan en la línea base %s" % [label, bad])


func _player_visual(character: Player.Character, label: String) -> void:
	var p := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate() as Player
	p.character = character
	p.position = Vector2(-5000, -5000)
	t.get_tree().root.add_child(p)
	await t.wait_frames(2)
	p.set_physics_process(false)
	var a := p.animator
	var base_scale := p.visual_root.scale
	var base_offset := a.offset
	var shape := p.body_shape.shape as CapsuleShape2D
	var shape_state := [shape.height, shape.radius, p.body_shape.position]
	var body_pos := p.position

	a.play_animation(PlayerAnimator.IDLE, true)
	var idle := a.get_visual_rect()
	var idle_height := idle.size.y * base_scale.y
	t.check(absf(idle_height - p.config.visual_height * p.config.visual_scale) < 1.5,
		"%s: altura visual de idle = PLAYER_HEIGHT (%.1f px)" % [label, idle_height])
	t.check(is_equal_approx(base_scale.x, base_scale.y) and base_scale.x > 0.0, "%s: escala global uniforme" % label)

	var stable := true
	var feet := true
	for anim in a.sprite_frames.get_animation_names():
		a.play_animation(anim, true)
		for i in a.sprite_frames.get_frame_count(anim):
			a.frame = i
			var r := a.get_visual_rect()
			if absf(r.end.y) > 0.01:
				feet = false
			if p.visual_root.scale != base_scale or a.offset != base_offset or p.position != body_pos:
				stable = false
			if [shape.height, shape.radius, p.body_shape.position] != shape_state:
				stable = false
	t.check(stable, "%s: cambiar de animación no cambia escala, offset, colisión ni posición" % label)
	t.check(feet, "%s: los pies coinciden con GroundPoint en todos los fotogramas" % label)
	t.check(p.ground_point.position == Vector2.ZERO and p.visual_root.position == p.ground_point.position,
		"%s: GroundPoint en el origen del cuerpo y raíz visual anclada a él" % label)

	a.play_animation(PlayerAnimator.WALK, true)
	a.frame = 1
	var right := a.get_visual_rect()
	p.facing = -1
	var left := a.get_visual_rect()
	t.check(a.flip_h and absf(left.position.x + right.end.x) < 0.01 and left.end.y == right.end.y
		and p.position == body_pos and p.ground_point.position == Vector2.ZERO,
		"%s: flip_h refleja el dibujo sobre GroundPoint sin mover el cuerpo" % label)

	p.set_low_profile(true, p.config.slide_height)
	t.check(is_equal_approx(shape.height, maxf(p.config.slide_height, p.config.body_radius * 2.0)),
		"%s: el estado de deslizamiento usa su propia colisión" % label)
	p.set_low_profile(false)
	p.queue_free()
	await t.wait_frames(1)
