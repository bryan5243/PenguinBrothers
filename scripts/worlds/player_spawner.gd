class_name PlayerSpawner
extends Node2D
## Crea los jugadores de la partida según el modo (individual: 1, cooperativo: 2).
## Los puntos de aparición son los Marker2D hijos llamados "P1" y "P2".
## Los jugadores se añaden como hijos de este nodo, que debe estar en el origen del nivel.

signal players_spawned(players: Array[Player])

const CHARACTERS: Array[Player.Character] = [Player.Character.BLUE_PENGUIN, Player.Character.PINK_PENGUIN]

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
## Separación usada si falta el marcador del jugador 2.
@export var fallback_offset := Vector2(60.0, 0.0)

var players: Array[Player] = []


func _ready() -> void:
	spawn_players()


func spawn_players() -> Array[Player]:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	for i in GameManager.player_count():
		var player := player_scene.instantiate() as Player
		player.player_index = i
		player.character = CHARACTERS[i]
		player.name = "Player%d" % (i + 1)
		player.position = _spawn_point(i)
		add_child(player)
		players.append(player)
	players_spawned.emit(players)
	return players


func _spawn_point(index: int) -> Vector2:
	var marker := get_node_or_null("P%d" % (index + 1)) as Marker2D
	if marker:
		return marker.position
	var first := get_node_or_null("P1") as Marker2D
	return (first.position if first else Vector2.ZERO) + fallback_offset * index
