extends SceneTree
## Regression: a hit at the other end of the map cannot become a global UI cue.
class Observer extends Node3D:
	func eye_position() -> Vector3:
		return global_position + Vector3.UP * 1.5
class Fixture extends Node3D:
	var observer
	func get_observer():
		return observer
class SpyAudio extends "res://scripts/audio.gd":
	var cues: Array = []
	func play_ui(cue: String = "ui", _intensity: float = 1.0) -> void:
		cues.append(cue)
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("run")
func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
func run() -> void:
	var fixture = Fixture.new()
	root.add_child(fixture)
	fixture.observer = Observer.new()
	fixture.add_child(fixture.observer)
	var sound = SpyAudio.new()
	fixture.add_child(sound)
	sound.game = fixture
	sound.enabled = true
	sound.master_volume = 1.0
	sound.play_event("hit", Vector3(100,0,0))
	expect(sound.cues.is_empty(), "remote physical hit does not leak through UI")
	sound.play_event("shot", Vector3(100,0,0))
	expect(sound.cues.is_empty(), "out of range shot remains silent")
	sound.play_event("ready", Vector3.ZERO)
	expect(sound.cues == ["ready"], "own ability ready cue remains available")
	sound.play_event("contact", Vector3.ZERO)
	expect(sound.cues.back() == "contact", "perception service can confirm a valid contact")
	sound.play_event("ui", Vector3.ZERO)
	expect(sound.cues.back() == "ui", "menu feedback remains available")
	sound.master_volume = 0.0
	var count: int = sound.cues.size()
	sound.play_event("ready", Vector3.ZERO)
	expect(sound.cues.size() == count, "master mute also silences UI event path")
	print("AUDIO_TESTS: ", checks, " checks, ", failures, " failures")
	fixture.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
