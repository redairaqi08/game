extends SceneTree
## Native rendering capture. Run on an available X display with --script.
var view: Node3D
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1600, 1000)
	view = Node3D.new()
	root.add_child(view)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14222b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a3b7b7")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("233c40")
	env.fog_density = 0.007
	env_node.environment = env
	view.add_child(env_node)
	var level: Node3D = load("res://scripts/level.gd").new()
	view.add_child(level)
	level.build(3)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(25, 18, 38)
	camera.fov = 70
	camera.far = 160
	view.add_child(camera)
	camera.look_at(Vector3(0, 7, -2))
	camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var output_path: String = "user://sanctuary.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			output_path = argument.trim_prefix("--capture-output=")
	var error: Error = image.save_png(output_path)
	print("CAPTURE_RESULT ", error)
	quit()
