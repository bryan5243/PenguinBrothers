extends Node2D
## Nivel de prueba de los jugadores (Fases 2–3). Suelo, plataformas atravesables, escalera,
## túnel bajo para deslizarse, escalón, un vacío mortal y un panel de depuración.
## Aparecen 1 o 2 pingüinos según el modo de juego. Esc/P/Start vuelve a la pantalla de arranque.

const BOOT_SCREEN := "res://scenes/ui/BootScreen.tscn"
const GAME_OVER_RESTART_DELAY := 2.0

@export var fall_death_y := 900.0

var players: Array[Player] = []
## Jugador 1 (atajo usado por las pruebas y el panel).
var player: Player

@onready var spawner: PlayerSpawner = $PlayerSpawner
@onready var camera: CoopCamera = $CoopCamera
@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	players = spawner.players
	player = players[0]
	for p in players:
		p.fall_death_y = fall_death_y
	EventBus.game_over.connect(_on_game_over)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.PAUSE_ACTION):
		get_viewport().set_input_as_handled()
		GameManager.request_scene(BOOT_SCREEN)


func _process(_delta: float) -> void:
	var lines: Array[String] = []
	for p in players:
		var state: StringName = p.state_machine.current_state.name if p.state_machine.current_state else &"-"
		var status := "eliminado" if GameManager.eliminated[p.player_index] else "%s · vida %d/%d · vidas %d" % [
			state, p.health.current_health, p.health.max_health, GameManager.lives[p.player_index]]
		lines.append("P%d %s: %s · vel (%d, %d)" % [p.player_index + 1, "azul" if p.character == 0 else "rosa",
			status, p.velocity.x, p.velocity.y])
	lines.append("Zoom de cámara: %.2f" % camera.zoom.x)
	debug_label.text = "\n".join(lines)


func _on_game_over() -> void:
	debug_label.text = "Fin de la partida · reiniciando..."
	await get_tree().create_timer(GAME_OVER_RESTART_DELAY).timeout
	if not is_inside_tree():
		return
	GameManager.start_new_game(GameManager.game_mode)
	GameManager.request_scene(scene_file_path)
