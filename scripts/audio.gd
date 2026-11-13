extends Node
## Original, bounded 3D soundscape. Gameplay audibility is also checked against
## the active observer so a loud mix cannot reveal a contact outside its range.

const VOICE_LIMIT: int = 24
const AUDIO_DIR: String = "res://assets/audio/"
const RANGES: Dictionary = {
	"walk": 8.0, "sprint": 20.0, "crouch": 3.0, "slide": 22.0,
	"jump": 5.0, "land": 18.0, "shot": 35.0, "pistol": 27.0,
	"impact": 12.0, "reload": 7.0, "ping": 22.0,
	"gadget": 8.0, "trap": 26.0, "jam": 12.0, "ambient": 8.0, "extraction": 30.0,
	"extract_complete": 30.0, "death": 12.0
}
const ALIASES: Dictionary = {
	"walk_step": "walk", "footstep": "walk", "step": "walk", "walking": "walk",
	"run": "sprint", "run_step": "sprint", "running": "sprint", "decoy": "sprint",
	"crouch_step": "crouch", "crouched": "crouch", "landing": "land",
	"fire": "shot", "rifle": "shot", "gunshot": "shot", "shoot": "shot",
	"active_ping": "ping", "sensor_ping": "ping", "choir": "ping",
	"mine": "trap", "bell": "trap", "thorn": "trap", "ear": "trap",
	"veil": "jam", "gadget_place": "gadget", "gadget_activation": "gadget",
	"extract": "extraction", "extraction_start": "extraction"
}

var game
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var priorities: Array[int] = []
var ages: Array[float] = []
var ambience: AudioStreamPlayer
var score: AudioStreamPlayer
var ui_voice: AudioStreamPlayer
var master_volume: float = 0.8
var enabled: bool = true
var _clock: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(game_ref) -> void:
	game = game_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 754210
	enabled = DisplayServer.get_name() != "headless" and AudioServer.get_driver_name() != "Dummy"
	if not enabled:
		return
	_load_library()
	for index: int in range(VOICE_LIMIT):
		var voice: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		voice.name = "AcousticVoice%02d" % index
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 3.0
		voice.max_distance = 35.0
		voice.panning_strength = 1.15
		voice.max_db = 0.0
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(voice)
		voices.append(voice)
		priorities.append(0)
		ages.append(0.0)
	ambience = _loop_player("ambience", "HollowAmbience")
	score = _loop_player("menu_score", "TrameScore")
	ui_voice = AudioStreamPlayer.new()
	ui_voice.name = "InterfaceTone"
	add_child(ui_voice)
	set_volume(float(game.settings.get("volume", 0.8)))


func _load_library() -> void:
	var names: Array[String] = [
		"rifle", "pistol", "ping", "ping_charge", "contact", "ready", "reload",
		"impact", "hit", "land", "jump", "slide", "gadget", "trap", "jam",
		"extraction", "extract_complete", "death", "ui", "ambience", "menu_score"
	]
	for material: String in ["stone", "metal", "crystal", "water", "dust", "organic"]:
		for variation: int in range(1, 4):
			names.append("step_%s_%d" % [material, variation])
	for asset: String in names:
		var path: String = AUDIO_DIR + asset + ".wav"
		if ResourceLoader.exists(path):
			streams[asset] = load(path)


func _loop_player(asset: String, node_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	add_child(player)
	if streams.has(asset):
		var original: AudioStream = streams[asset]
		var stream: AudioStreamWAV = original.duplicate() as AudioStreamWAV
		if stream:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
			player.stream = stream
			player.volume_db = -30.0
			player.play()
	return player


func set_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	if not enabled or game == null:
		return
	_clock += delta
	var in_round: bool = game.phase == "playing"
	var paused: bool = get_tree().paused
	var volume_db: float = linear_to_db(maxf(master_volume, 0.0001))
	if is_instance_valid(ambience):
		ambience.volume_db = lerpf(ambience.volume_db, volume_db - (22.0 if in_round else 19.0), minf(delta * 2.0, 1.0))
	if is_instance_valid(score):
		# Music leaves the tactical mix during live rounds, and swells in menus.
		var target: float = volume_db - (44.0 if in_round and not paused else 15.0)
		score.volume_db = lerpf(score.volume_db, target, minf(delta * 1.8, 1.0))
	for voice: AudioStreamPlayer3D in voices:
		voice.stream_paused = paused


func play_event(category: String, origin: Vector3, intensity: float = 1.0) -> void:
	if not enabled or master_volume < 0.001 or game == null:
		return
	var kind: String = str(ALIASES.get(category, category))
	if kind in ["contact", "ping_contact", "ping_ready", "ready", "ui", "ping_charge"]:
		var cue: String = "contact" if kind == "ping_contact" else ("ready" if kind == "ping_ready" else kind)
		play_ui(cue, intensity)
		return
	var observer = game.get_observer()
	if not is_instance_valid(observer):
		return
	var listener: Vector3 = observer.eye_position()
	var distance: float = listener.distance_to(origin)
	var nominal_range: float = float(RANGES.get(kind, 10.0))
	var occluded: bool = _is_occluded(listener, origin)
	# Acoustics has already gated hearing and supplied an estimated origin.
	# Do not gate it again against an unrelated true source or jam state.
	var effective_range: float = nominal_range + 4.0
	if distance > maxf(effective_range, 2.5):
		return
	var asset: String = kind
	var gain: float = 0.0
	var priority: int = 2
	if kind in ["walk", "sprint", "crouch"]:
		asset = "step_%s_%d" % [_surface_at(origin), _rng.randi_range(1, 3)]
		gain = {"walk": -3.0, "sprint": 0.0, "crouch": -13.0}[kind]
		priority = 1
	elif kind == "ambient":
		asset = "gadget"
		gain = -15.0
		priority = 0
	elif kind == "shot":
		asset = "rifle"
		priority = 4
	elif kind in ["ping", "trap", "extraction", "extract_complete"]:
		priority = 3
	if not streams.has(asset):
		asset = "gadget"
	var index: int = _allocate_voice(priority)
	if index < 0:
		return
	var voice: AudioStreamPlayer3D = voices[index]
	voice.stop()
	voice.stream = streams[asset]
	voice.global_position = origin
	voice.max_distance = maxf(effective_range, 3.0)
	voice.unit_size = 2.8 if priority <= 1 else 4.2
	voice.pitch_scale = _rng.randf_range(0.96, 1.04) if kind not in ["ping", "extraction", "extract_complete"] else 1.0
	voice.volume_db = linear_to_db(maxf(master_volume * clampf(intensity, 0.0, 1.4), 0.0001)) + gain - (8.0 if occluded else 0.0)
	voice.attenuation_filter_cutoff_hz = 1900.0 if occluded else 18000.0
	voice.attenuation_filter_db = -12.0 if occluded else -7.0
	priorities[index] = priority
	ages[index] = _clock
	voice.play()


func play_ui(cue: String = "ui", intensity: float = 1.0) -> void:
	if not enabled or not is_instance_valid(ui_voice) or not streams.has(cue):
		return
	ui_voice.stream = streams[cue]
	ui_voice.volume_db = linear_to_db(maxf(master_volume * intensity, 0.0001)) - 9.0
	ui_voice.play()


func _allocate_voice(priority: int) -> int:
	var oldest: float = INF
	var candidate: int = -1
	for index: int in range(voices.size()):
		if not voices[index].playing:
			return index
		if priorities[index] <= priority and ages[index] < oldest:
			oldest = ages[index]
			candidate = index
	return candidate


func _is_occluded(listener: Vector3, origin: Vector3) -> bool:
	if listener.distance_squared_to(origin) < 0.3:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(listener, origin + Vector3.UP * 0.12, 1)
	return not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _surface_at(origin: Vector3) -> String:
	if not is_instance_valid(game.level):
		return "stone"
	# The authored level's named zones provide a stable material sound palette.
	# No false contact data is introduced: footsteps retain their true category.
	var zone: String = str(game.level.get_zone(origin)).to_lower()
	if "can" in zone or "silence" in zone:
		return "water"
	if "crist" in zone or "jardin" in zone:
		return "crystal"
	if "atelier" in zone or "passer" in zone:
		return "metal"
	if "crypte" in zone:
		return "dust"
	return "stone"
