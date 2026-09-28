extends Node2D
## Escena de prueba visual del Pingüino Azul (solo para pruebas; no forma parte del juego).
## Usa la escena real del jugador (Player.tscn con el personaje azul) con la lógica
## detenida, para reproducir cada animación sobre el suelo y comprobar que:
##   · la escala no cambia entre animaciones,
##   · los pies siguen sobre la línea del suelo (GroundPoint),
##   · la colisión y la posición del CharacterBody2D no cambian,
##   · flip_h no desplaza al personaje.
##
## Teclas: 1 idle · 2 caminar · 3 correr · 4 saltar · 5 caída · 6 aterrizaje · 7 agacharse
##         8 deslizarse · 9 recoger · 0 lanzar · ←/→ anterior/siguiente · F voltear
##         Espacio pausa/reproduce · , . fotograma a fotograma · F1 depuración · Esc salir

const BOOT_SCREEN := "res://scenes/ui/BootScreen.tscn"
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const HOTKEYS := {
	KEY_1: &"idle", KEY_2: &"walk", KEY_3: &"run", KEY_4: &"jump", KEY_5: &"fall",
	KEY_6: &"land", KEY_7: &"crouch", KEY_8: &"slide", KEY_9: &"lift", KEY_0: &"throw",
}
## Orden de avance con ←/→ (las que falten en el SpriteFrames se saltan).
const ORDER: Array[StringName] = [&"idle", &"walk", &"run", &"jump", &"fall", &"land", &"crouch",
	&"slide", &"climb", &"lift", &"carry", &"throw", &"place_bomb", &"hurt", &"death", &"victory",
	&"swim", &"attack", &"fire_attack"]
## Nombres de la especificación (blue_penguin_*) para los nombres estándar del proyecto.
const SPEC_NAMES := {&"climb": &"ladder", &"lift": &"pickup"}

var player: Player
var animations: Array[StringName] = []
var index := 0

@onready var info: Label = $UI/Info
@onready var spawn: Marker2D = $Spawn


func _ready() -> void:
	PlayerDebugOverlay.enabled = true
	player = PLAYER_SCENE.instantiate() as Player
	player.character = Player.Character.BLUE_PENGUIN
	player.position = spawn.position
	add_child(player)
	# Solo la parte visual: sin física ni estados, el cuerpo queda quieto sobre el suelo.
	player.set_physics_process(false)
	player.health.set_process(false)
	var available := player.animator.sprite_frames.get_animation_names()
	for anim in ORDER:
		if available.has(anim):
			animations.append(anim)
	for anim in available:
		if not animations.has(StringName(anim)):
			animations.append(StringName(anim))
	show_animation(&"idle")


func show_animation(anim: StringName) -> void:
	var i := animations.find(anim)
	if i < 0:
		return
	index = i
	player.animator.play_animation(anim, true)
	# La colisión la decide el ESTADO que usa la animación, no el tamaño del dibujo:
	# aquí se imita al estado correspondiente para poder verla con F1.
	if anim == &"slide":
		player.set_low_profile(true, player.config.slide_height)
	elif anim == &"crouch":
		player.set_low_profile(true)
	else:
		player.set_low_profile(false)


func step(direction: int) -> void:
	index = wrapi(index + direction, 0, animations.size())
	show_animation(animations[index])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.DEBUG_OVERLAY_ACTION):
		PlayerDebugOverlay.toggle()
	elif event.is_action_pressed(InputManager.PAUSE_ACTION):
		GameManager.request_scene(BOOT_SCREEN)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: Key = (event as InputEventKey).physical_keycode
		var anim_player := player.animator
		if HOTKEYS.has(key):
			show_animation(HOTKEYS[key])
		elif key == KEY_RIGHT:
			step(1)
		elif key == KEY_LEFT:
			step(-1)
		elif key == KEY_F:
			player.facing = -player.facing
		elif key == KEY_SPACE:
			if anim_player.is_playing():
				anim_player.pause()
			else:
				anim_player.play()
		elif key == KEY_PERIOD or key == KEY_COMMA:
			anim_player.pause()
			var count := anim_player.sprite_frames.get_frame_count(anim_player.animation)
			anim_player.frame = wrapi(anim_player.frame + (1 if key == KEY_PERIOD else -1), 0, count)
		else:
			return
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var a := player.animator
	var anim := a.animation
	var shape := player.body_shape.shape as CapsuleShape2D
	var rect := a.get_visual_rect()
	var s := player.visual_root.scale.x
	info.text = "\n".join([
		"blue_penguin_%s   (animación «%s»)   %d/%d" % [SPEC_NAMES.get(anim, anim), anim, index + 1, animations.size()],
		"Fotograma %d/%d · %s · %s" % [a.frame + 1, a.sprite_frames.get_frame_count(anim),
			"reproduciendo" if a.is_playing() else "en pausa", "izquierda (flip_h)" if a.flip_h else "derecha"],
		"Lienzo común %s · altura de referencia %d px · escala global %.3f (PlayerConfig.visual_*)" % [
			a.get_canvas_size(), a.get_reference_height(), s],
		"Cuerpo en %s · colisión del estado: cápsula r%.0f h%.0f · GroundPoint %s" % [player.position, shape.radius,
			shape.height, player.ground_point.position],
		"Caja visual: pies a %.1f px del GroundPoint · alto %.0f px en pantalla" % [
			(rect.end.y * s), rect.size.y * s],
		"1 idle · 2 caminar · 3 correr · 4 saltar · 5 caída · 6 aterrizaje · 7 agacharse · 8 deslizarse · 9 recoger · 0 lanzar",
		"←/→ anterior/siguiente · F voltear · Espacio pausa · , . fotograma · F1 depuración · Esc salir",
	])
