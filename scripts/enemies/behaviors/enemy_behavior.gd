class_name EnemyBehavior
extends RefCounted
## Comportamiento de un enemigo (estrategia). Los estados genéricos (Patrol, Chase, Attack,
## Special...) le preguntan qué hacer; cada tipo de enemigo sobrescribe solo lo suyo.
## Se elige a partir de EnemyData.behavior en create().

var enemy: Enemy
var data: EnemyData


static func create(for_enemy: Enemy) -> EnemyBehavior:
	var b: EnemyBehavior
	match for_enemy.data.behavior:
		EnemyData.Behavior.SHELL:
			b = ShellBehavior.new()
		EnemyData.Behavior.FLYER:
			b = FlyerBehavior.new()
		EnemyData.Behavior.SWIMMER:
			b = ShooterBehavior.new()
		_:
			b = WalkerBehavior.new()
	b.enemy = for_enemy
	b.data = for_enemy.data
	b.setup()
	return b


func setup() -> void:
	pass


func patrol(_delta: float) -> void:
	pass


func chase(delta: float, _target: Player) -> void:
	patrol(delta)


func can_attack(_target: Player) -> bool:
	return false


func start_attack(_target: Player) -> void:
	pass


## Se llama cada frame durante el ataque; devuelve true cuando termina.
func attack(_delta: float, _target: Player) -> bool:
	return true


## ¿Quiere pasar al estado Special (esconderse, etc.)?
func wants_special() -> bool:
	return false


## Cada frame en Special; devuelve true cuando termina.
func special(_delta: float) -> bool:
	return true


func on_hurt() -> void:
	pass


## Daño que recibe realmente (armaduras, caparazón...).
func modify_damage(amount: int, _source: Node) -> int:
	return amount


## Un golpe no le hizo nada (p. ej. rebotó en el caparazón).
func on_blocked() -> void:
	pass


func deals_contact_damage() -> bool:
	return true
