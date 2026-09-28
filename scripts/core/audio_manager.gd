extends Node
## Sistema global de audio: música (menú, nivel, jefe) y efectos con pool de reproductores.
## Los sonidos se registran por clave en SOUND_LIBRARY. Si un archivo todavía no existe,
## se avisa una sola vez y se ignora, así el juego funciona sin audio hasta que se agregue.

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SFX_POOL_SIZE := 12
const MUSIC_FADE_TIME := 0.6

## Clave -> ruta. Completar cuando existan los archivos en audio/music y audio/sfx.
const SOUND_LIBRARY := {
	# Música
	"music_menu": "res://audio/music/menu.ogg",
	"music_world_01": "res://audio/music/world_01.ogg",
	"music_boss": "res://audio/music/boss.ogg",
	# Efectos
	"jump": "res://audio/sfx/jump.wav",
	"land": "res://audio/sfx/land.wav",
	"slide": "res://audio/sfx/slide.wav",
	"bomb_place": "res://audio/sfx/bomb_place.wav",
	"bomb_throw": "res://audio/sfx/bomb_throw.wav",
	"explosion": "res://audio/sfx/explosion.wav",
	"hit": "res://audio/sfx/hit.wav",
	"hurt": "res://audio/sfx/hurt.wav",
	"pickup": "res://audio/sfx/pickup.wav",
	"power_up": "res://audio/sfx/power_up.wav",
	"ui_select": "res://audio/sfx/ui_select.wav",
	"ui_confirm": "res://audio/sfx/ui_confirm.wav",
}

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _warned: Dictionary = {}
var _current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)
	set_bus_volume(MUSIC_BUS, float(SaveManager.get_value("settings", "music_volume", 0.8)))
	set_bus_volume(SFX_BUS, float(SaveManager.get_value("settings", "sfx_volume", 0.9)))


func play_sfx(key: String, pitch := 1.0) -> void:
	var stream := _get_stream(key)
	if stream == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.play()
			return


func play_music(key: String) -> void:
	if key == _current_music and _music_player.playing:
		return
	var stream := _get_stream(key)
	_current_music = key
	if stream == null:
		_music_player.stop()
		return
	var tw := create_tween()
	if _music_player.playing:
		tw.tween_property(_music_player, "volume_db", -40.0, MUSIC_FADE_TIME)
	tw.tween_callback(func() -> void:
		_music_player.stream = stream
		_music_player.volume_db = 0.0
		_music_player.play())


func stop_music() -> void:
	_current_music = ""
	_music_player.stop()


## volume: 0.0 – 1.0 (lineal)
func set_bus_volume(bus_name: StringName, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	volume = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, volume <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.001)))


func _get_stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path: String = SOUND_LIBRARY.get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		if not _warned.has(key):
			_warned[key] = true
			print_verbose("AudioManager: sonido '%s' aún no disponible (%s)" % [key, path])
		return null
	var stream := load(path) as AudioStream
	_cache[key] = stream
	return stream


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")
