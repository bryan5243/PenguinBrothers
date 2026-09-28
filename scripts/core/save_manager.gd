extends Node
## Guardado modular en JSON (user://save_data.json).
## Los datos se agrupan por sección ("progress", "settings"); cada sección se fusiona
## con sus valores por defecto al cargar, así las versiones nuevas no rompen partidas viejas.

signal saved
signal loaded

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1

const DEFAULT_DATA := {
	"version": SAVE_VERSION,
	"progress": {
		"unlocked_world": 1,
		"unlocked_level": 1,
		"best_scores": {},
		"high_score": 0,
		"lives": [3, 3],
	},
	"settings": {
		"music_volume": 0.8,
		"sfx_volume": 0.9,
		"fullscreen": false,
		"vibration": true,
		"show_touch_controls": "auto",
		"language": "es",
	},
}

var data: Dictionary = {}


func _ready() -> void:
	load_game()


func load_game() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_merge(data, parsed)
			else:
				push_warning("SaveManager: archivo de guardado inválido, se usan valores por defecto.")
	loaded.emit()


func save_game() -> bool:
	data["version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo escribir %s (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	saved.emit()
	return true


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	var s: Dictionary = data.get(section, {})
	return s.get(key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	if not data.has(section):
		data[section] = {}
	data[section][key] = value


func unlock_level(world: int, level: int) -> void:
	var cur_world := int(get_value("progress", "unlocked_world", 1))
	var cur_level := int(get_value("progress", "unlocked_level", 1))
	if world > cur_world or (world == cur_world and level > cur_level):
		set_value("progress", "unlocked_world", world)
		set_value("progress", "unlocked_level", level)


func record_score(level_key: String, score: int) -> void:
	var best: Dictionary = get_value("progress", "best_scores", {})
	if score > int(best.get(level_key, 0)):
		best[level_key] = score
		set_value("progress", "best_scores", best)
	if score > int(get_value("progress", "high_score", 0)):
		set_value("progress", "high_score", score)


func reset_progress() -> void:
	data["progress"] = DEFAULT_DATA["progress"].duplicate(true)
	save_game()


## Fusión recursiva: conserva claves por defecto que falten en el archivo cargado.
func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if target.has(key) and target[key] is Dictionary and source[key] is Dictionary:
			_merge(target[key], source[key])
		else:
			target[key] = source[key]
