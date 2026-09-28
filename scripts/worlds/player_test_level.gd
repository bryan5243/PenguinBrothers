extends Node2D
## Nivel de prueba del jugador (Fase 2). Suelo, plataformas atravesables, escalera,
## túnel bajo para deslizarse, escalón, un vacío mortal y un panel de depuración.
## Esc/P/Start vuelve a la pantalla de arranque.

const BOOT_SCREEN := "res://scenes/ui/BootScreen.tscn"
const GAME_OVER_RESTART_DELAY := 2.0

@export var fall_death_y := 900.0

@onready var player: Player = $Player
@onready var debug_label: Label = $DebugLayer/DebugLabel


func _ready() -> void:
	if GameManager.lives[0] <= 0:
		GameManager.start_new_game(GameManager.GameMode.SOLO)
	player.fall_death_y = fall_death_y
	EventBus.game_over.connect(_on_game_over)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputManager.PAUSE_ACTION):
		get_viewport().set_input_as_handled()
		GameManager.request_scene(BOOT_SCREEN)


func _process(_delta: float) -> void:
	var state: StringName = player.state_machine.current_state.name if player.state_machine.current_state else &"-"
	debug_label.text = "Estado: %s   Velocidad: (%d, %d)   Suelo: %s\nVida: %d/%d   Vidas: %d   Animación: %s" % [
		state, player.velocity.x, player.velocity.y, "sí" if player.is_on_floor() else "no",
		player.health.current_health, player.health.max_health, GameManager.lives[player.player_index],
		player.animator.animation,
	]


func _on_game_over() -> void:
	debug_label.text = "Fin de la partida · reiniciando..."
	await get_tree().create_timer(GAME_OVER_RESTART_DELAY).timeout
	GameManager.start_new_game(GameManager.GameMode.SOLO)
	GameManager.request_scene(scene_file_path)
