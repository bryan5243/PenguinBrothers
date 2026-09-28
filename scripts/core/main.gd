extends Node
## Escena raíz persistente. Carga las pantallas (título, pantallas de fase, jefe, GAME OVER,
## victoria, herramientas de prueba) dentro de ScreenRoot cuando alguien emite
## EventBus.scene_change_requested, con una transición arcade (fundido, destello o
## cortina). Los autoloads siguen vivos entre pantallas.

@export_file("*.tscn") var initial_screen := "res://scenes/ui/TitleScreen.tscn"

var current_screen: Node
var _changing := false
var _queued: Array = []

@onready var screen_root: Node = $ScreenRoot
@onready var transition: ScreenTransition = $Transition


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.scene_change_requested.connect(change_to)
	go_to(initial_screen)


## Cambia de pantalla con transición (&"none" = inmediata).
func change_to(scene_path: String, kind: StringName = &"fade") -> void:
	if _changing:
		_queued = [scene_path, kind]
		return
	if kind == &"none" or kind == &"":
		go_to(scene_path)
		return
	_changing = true
	await transition.cover(kind)
	go_to(scene_path)
	await get_tree().process_frame
	await transition.reveal(kind)
	_changing = false
	if not _queued.is_empty():
		var next: Array = _queued
		_queued = []
		change_to(next[0], next[1])


func go_to(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("Main: la escena '%s' no existe." % scene_path)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Main: '%s' no es una escena válida." % scene_path)
		return
	if current_screen:
		current_screen.queue_free()
	GameManager.set_paused(false)
	current_screen = packed.instantiate()
	screen_root.add_child(current_screen)
