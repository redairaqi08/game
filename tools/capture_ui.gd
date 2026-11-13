extends SceneTree
## Usage: godot --path . --script res://tools/capture_ui.gd -- --output=/absolute/path
var game
var frame := 0
var folder := "/workspace/work"
var menu_only := false
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): folder=argument.trim_prefix("--output=")
		if argument=="--menu-only": menu_only=true
	var scene=load("res://scenes/main.tscn")
	game=scene.instantiate()
	root.add_child(game)
	root.size=Vector2i(1600,900)
func _process(_delta: float) -> bool:
	frame+=1
	if menu_only and frame==5: _capture("sonar_menu.png")
	if menu_only and frame==8: quit(0)
	if menu_only: return false
	match frame:
		25: _capture("sonar_menu.png")
		40: game.ui._open_page("settings")
		55: _capture("sonar_settings.png")
		70: game.start_match({"mode":"tutorial","team_size":1,"difficulty":0,"initial_role":"attack","primary_gadget":"decoy","secondary_gadget":"thorn"})
		110: _capture("sonar_hud.png")
		125: game.ui.map_overlay.show()
		140: _capture("sonar_map.png")
		160: quit(0)
	return false
func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	image.save_png(folder.path_join(filename))
	print("CAPTURE "+folder.path_join(filename))
