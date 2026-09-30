class_name DropTable
extends Resource
## Botín de un objeto destruible o de un enemigo: con probabilidad `drop_chance` suelta
## `rolls` objetos elegidos por peso entre `items`.

@export var items: Array[PowerUpData] = []
## Peso de cada objeto (misma posición que en `items`; si falta, vale 1).
@export var weights: Array[float] = []
@export_range(0.0, 1.0) var drop_chance := 0.5
@export var rolls := 1


## Objetos que suelta esta vez (puede ser una lista vacía).
func roll(rng: RandomNumberGenerator) -> Array[PowerUpData]:
	var out: Array[PowerUpData] = []
	if items.is_empty() or rng.randf() >= drop_chance:
		return out
	for i in rolls:
		out.append(_pick(rng))
	return out


func _pick(rng: RandomNumberGenerator) -> PowerUpData:
	var total := 0.0
	for i in items.size():
		total += weights[i] if i < weights.size() else 1.0
	var r := rng.randf() * total
	for i in items.size():
		r -= weights[i] if i < weights.size() else 1.0
		if r <= 0.0:
			return items[i]
	return items.back()
