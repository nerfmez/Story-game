extends SceneTree
## Renders what the classroom's windows (scenes/classroom_3d_pixel.tscn, PR13) look out on, from this
## school model, as two flat views the classroom shows a few metres outside its walls.
##
## The classroom (10.8 x 12 m, floor y 0) sits in a 2nd-floor bay of the left wing: its corridor wall
## (classroom x +5.4) on the model's corridor wall (z -2.5), its board end (classroom z -6) toward +x.
## So classroom (x, y, z) = model (BAY_X - z, FLOORS[1] + y, CORRIDOR_Z - 5.4 + x). Each view is rendered
## from the classroom's middle at eye height through a plane CARD_DISTANCE out, the size of that plane,
## so from the middle of the room the view lines up with the model; near clipping drops the model's own
## walls between the room and the plane.
##
## Usage: godot --path . --rendering-driver opengl3 -s res://tools/render_classroom_views.gd -- OUT_DIR

const BAY_X := -11.2                         # model x of the classroom's middle (between two pillars)
const CORRIDOR_Z := -2.5                     # SchoolModel3D.Z_WALL
const EYE := 2.0                             # classroom y of the views' centre
const CARD_DISTANCE := 9.4                   # from the classroom's middle to each view plane
const CARD_SIZE := Vector2(16.0, 7.0)        # metres, as placed in the classroom
const PIXELS := Vector2i(1024, 448)
const VIEWS := [
	# name, model yaw (looking +z = out over the corridor, -z = out of the back windows), near clip
	["view_corridor", PI, 5.5],
	["view_back", 0.0, 1.7],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var view := SchoolBuildingView.new()
	root.add_child(view)
	view.size = PIXELS
	var cam := view.camera
	cam.fov = rad_to_deg(2.0 * atan(CARD_SIZE.y * 0.5 / CARD_DISTANCE))
	var eye := Vector3(BAY_X, SchoolModel3D.FLOORS[1] + EYE, CORRIDOR_Z - 5.4)
	for v: Array in VIEWS:
		cam.position = eye
		cam.rotation = Vector3(0.0, float(v[1]), 0.0)
		cam.near = float(v[2])
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = view.get_child(0).get_texture().get_image()
		image.save_png(out.path_join(str(v[0]) + ".png"))
		print("CLASSROOM_VIEW ", image.get_size(), " ", out.path_join(str(v[0]) + ".png"))
	quit(0)
