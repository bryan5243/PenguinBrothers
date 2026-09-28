class_name Player
extends CharacterBody2D
## Pingüino jugable. Este script solo coordina sus componentes:
##   PlayerInput   -> qué quiere hacer el jugador este frame
##   StateMachine  -> qué hace (estados Idle, Run, Jump... se agregan en la Fase 2)
##   PlayerAnimator-> cómo se ve (separado de la lógica)
##   HealthComponent -> vida, daño e invulnerabilidad
## La física concreta de cada acción vive en los estados, no aquí.

signal facing_changed(direction: int)

enum Character { BLUE_PENGUIN, PINK_PENGUIN }

@export_range(0, 1) var player_index := 0
@export var character: Character = Character.BLUE_PENGUIN
@export var config: PlayerConfig

var input: PlayerInput
var facing := 1:
	set(value):
		if value != 0 and value != facing:
			facing = signi(value)
			if animator:
				animator.set_facing(facing)
			facing_changed.emit(facing)
var spawn_position := Vector2.ZERO
## Objeto cargado sobre la cabeza (barril, bomba). Lo gestionan los estados de carga.
var carried_object: Node2D = null

@onready var state_machine: StateMachine = $StateMachine
@onready var animator: PlayerAnimator = $Animator
@onready var health: HealthComponent = $Health


func _ready() -> void:
	if config == null:
		config = PlayerConfig.new()
	input = PlayerInput.new(player_index)
	spawn_position = global_position
	health.max_health = config.max_health
	health.invulnerability_time = config.invulnerability_time
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	animator.setup(character)
	EventBus.player_spawned.emit(self, player_index)


func _physics_process(_delta: float) -> void:
	# Los estados leen `input` en su physics_update, que corre después de este nodo.
	input.update()


## Gravedad común para todos los estados aéreos.
func apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)


func is_carrying() -> bool:
	return carried_object != null and is_instance_valid(carried_object)


func take_damage(amount: int, source: Node = null) -> void:
	health.take_damage(amount, source)


func _on_damaged(amount: int, source: Node) -> void:
	EventBus.player_damaged.emit(player_index, amount, health.current_health)
	if source is Node2D:
		var dir := signf(global_position.x - (source as Node2D).global_position.x)
		velocity = Vector2((dir if dir != 0.0 else -facing) * config.knockback.x, config.knockback.y)
	if state_machine.states.has(&"Hurt"):
		state_machine.transition_to(&"Hurt")


func _on_died() -> void:
	EventBus.player_died.emit(player_index)
	if state_machine.states.has(&"Dead"):
		state_machine.transition_to(&"Dead")
