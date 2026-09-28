extends Node
## Escena raíz persistente. Carga pantallas (menú, niveles, pruebas) dentro de ScreenRoot
## cuando alguien emite EventBus.scene_change_requested; los autoloads siguen vivos.

@export_file("*.tscn") var initial_screen := "res://scenes/ui/BootScreen.tscn"

var current_screen: Node

@onready var screen_root: Node = $ScreenRoot


func _ready() -> void:
	EventBus.scene_change_requested.connect(go_to)
	go_to(initial_screen)


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
