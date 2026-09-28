class_name HealthComponent
extends Node
## Vida reutilizable (jugadores, enemigos, jefes, objetos destruibles).
## Gestiona HP, invulnerabilidad temporal y señales; no sabe nada de animaciones.

signal damaged(amount: int, source: Node)
signal healed(amount: int)
signal health_changed(current: int, maximum: int)
signal died
signal invulnerability_changed(active: bool)

@export var max_health := 3
@export var invulnerability_time := 0.0

var current_health := 0
var is_dead := false
var _invulnerable_timer := 0.0


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta
		if _invulnerable_timer <= 0.0:
			invulnerability_changed.emit(false)


func is_invulnerable() -> bool:
	return _invulnerable_timer > 0.0


## Devuelve true si el daño se aplicó.
func take_damage(amount: int, source: Node = null) -> bool:
	if is_dead or amount <= 0 or is_invulnerable():
		return false
	current_health = maxi(0, current_health - amount)
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		is_dead = true
		died.emit()
	elif invulnerability_time > 0.0:
		start_invulnerability(invulnerability_time)
	return true


## Muerte inmediata (caída al vacío, aplastamiento), ignora la invulnerabilidad.
func kill(source: Node = null) -> void:
	if is_dead:
		return
	var amount := current_health
	current_health = 0
	is_dead = true
	_invulnerable_timer = 0.0
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)
	died.emit()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = mini(max_health, current_health + amount)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func start_invulnerability(seconds: float) -> void:
	var was := is_invulnerable()
	_invulnerable_timer = maxf(_invulnerable_timer, seconds)
	if not was:
		invulnerability_changed.emit(true)


func reset() -> void:
	is_dead = false
	current_health = max_health
	_invulnerable_timer = 0.0
	health_changed.emit(current_health, max_health)
