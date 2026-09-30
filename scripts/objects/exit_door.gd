class_name ExitDoor
extends Node2D
## Puerta de salida de la fase (pantalla B). Cerrada mientras nadie lleve la llave: si el
## portador de la llave llega hasta ella se abre (portal azul), gasta la llave y, un momento
## después, completa la pantalla (y con ella la fase, con su bonificación de tiempo).
## El origen del nodo es el centro de la base de la puerta.

signal opened(door: ExitDoor)

const DATA_PATH := "res://data/items/objective.tres"

enum State { CLOSED, OPEN, ENTERED }

@export var data: ObjectiveData

var state := State.CLOSED
var _shake := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if data == null:
		data = load(DATA_PATH) as ObjectiveData
	add_to_group(&"exit_doors")
	sprite.texture = data.door_closed
	sprite.scale = Vector2.ONE * data.door_scale
	sprite.offset = Vector2(0.0, -data.door_closed.get_height() * 0.5)
	z_index = -4


func reach_rect() -> Rect2:
	return Rect2(global_position + Vector2(-data.door_reach.x, -data.door_reach.y * 2.0),
		Vector2(data.door_reach.x * 2.0, data.door_reach.y * 2.0))


func is_open() -> bool:
	return state != State.CLOSED


## Abre la puerta con la llave `key` (la gasta) y programa el final de la pantalla.
func open_with(key: KeyItem) -> void:
	if state != State.CLOSED:
		return
	state = State.OPEN
	sprite.texture = data.door_open
	sprite.offset = Vector2(0.0, -data.door_open.get_height() * 0.5)
	if key and is_instance_valid(key):
		key.consume()
	AudioManager.play_sfx("door")
	opened.emit(self)
	await get_tree().create_timer(data.enter_delay).timeout
	if state == State.OPEN and is_inside_tree():
		state = State.ENTERED
		StageManager.next_screen()


func _physics_process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		sprite.position.x = sin(_shake * 90.0) * 3.0
	else:
		sprite.position.x = 0.0
	if state != State.CLOSED:
		return
	var rect := reach_rect()
	for key in get_tree().get_nodes_in_group(KeyItem.GROUP):
		var k := key as KeyItem
		if k and k.is_carried() and k.holder and rect.has_point(k.holder.global_position):
			open_with(k)
			return
	# Un jugador sin llave que pulsa arriba delante de la puerta: se sacude («falta la llave»).
	for p in get_tree().get_nodes_in_group(&"players"):
		var pl := p as Player
		if pl and pl.is_alive() and pl.input.up_pressed and rect.has_point(pl.global_position):
			_shake = 0.3
