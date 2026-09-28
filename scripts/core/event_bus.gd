extends Node
## Bus de señales global.
## Permite que gameplay, HUD, audio y guardado se comuniquen sin referencias directas
## entre sí (evita dependencias circulares). Solo declara señales; no contiene lógica.

# Navegación
signal scene_change_requested(scene_path: String)

# Jugadores
signal player_spawned(player: Node, player_index: int)
signal player_damaged(player_index: int, amount: int, current_health: int)
signal player_died(player_index: int)
signal player_respawned(player_index: int)
signal lives_changed(player_index: int, lives: int)
signal score_changed(player_index: int, score: int)
signal power_up_collected(player_index: int, power_up_id: StringName)

# Combate y objetos
signal bomb_exploded(position: Vector2, radius: float, owner_index: int)
signal enemy_defeated(enemy_id: StringName, position: Vector2, killer_index: int)
signal boss_health_changed(boss_id: StringName, current: int, maximum: int)
signal boss_defeated(boss_id: StringName)

# Nivel
signal checkpoint_reached(checkpoint_id: StringName, position: Vector2)
signal level_started(world_number: int, level_number: int)
signal level_completed(world_number: int, level_number: int)
signal game_over

# Estado del juego
signal pause_changed(is_paused: bool)
signal input_device_changed(device: int)
