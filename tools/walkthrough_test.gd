extends Node2D
## walk-through: entrance -> up to 2F -> corridor -> up to 3F (camera at eye height)
var v: SchoolBuildingView
var t := 0.0
const E := 1.6
var keys := [
	[0.0, Vector3(0.57, 1.08, 8.0), Vector3(0.57, 1.08, 0.0)],
	[3.0, Vector3(-1.25, 0.287 + E, -3.3), Vector3(-1.25, 1.2, -6.5)],
	[5.5, Vector3(-1.25, 1.817 + E, -5.4), Vector3(-1.25, 2.6, -9.0)],
	[7.0, Vector3(-1.6, 1.817 + E, -6.15), Vector3(3.0, 3.0, -6.15)],
	[9.5, Vector3(2.3, 3.347 + E, -6.15), Vector3(4.0, 4.5, -6.15)],
	[11.0, Vector3(2.8, 3.347 + E, -6.0), Vector3(2.3, 4.7, 0.0)],
	[13.5, Vector3(1.4, 3.347 + E, -1.3), Vector3(-10.0, 4.7, -1.3)],
	[15.5, Vector3(-1.25, 3.347 + E, -3.3), Vector3(-1.25, 4.3, -6.5)],
	[18.0, Vector3(-1.25, 4.877 + E, -5.4), Vector3(-1.25, 5.7, -9.0)],
	[19.5, Vector3(-1.6, 4.877 + E, -6.15), Vector3(3.0, 6.1, -6.15)],
	[22.0, Vector3(2.3, 6.407 + E, -6.15), Vector3(4.0, 7.6, -6.15)],
	[23.5, Vector3(2.8, 6.407 + E, -6.0), Vector3(2.3, 7.8, 0.0)],
	[26.5, Vector3(1.4, 6.407 + E, -1.3), Vector3(12.0, 7.8, -1.3)],
	[30.0, Vector3(1.4, 6.407 + E, -1.3), Vector3(12.0, 7.8, -1.3)],
]
var shots := {2.6: "w_hall", 4.2: "w_flight1", 6.9: "w_landing", 8.3: "w_flight2", 12.0: "w_2f", 15.4: "w_2f_corr", 16.8: "w_flight3", 20.8: "w_flight4", 29.5: "w_3f"}
func _ready():
	var bg := ColorRect.new(); bg.color = Color(0.55, 0.6, 0.68); bg.size = Vector2(640, 360); add_child(bg)
	v = SchoolBuildingView.new(); add_child(v)
	v.enter(0.6)
	v.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	v.camera.fov = 62.0
	v.camera.keep_aspect = Camera3D.KEEP_HEIGHT
func _process(d):
	t += d
	var i := 0
	while i < keys.size() - 2 and t > keys[i + 1][0]: i += 1
	var a = keys[i]; var b = keys[i + 1]
	var f := smoothstep(0.0, 1.0, clampf((t - a[0]) / (b[0] - a[0]), 0, 1))
	var pos: Vector3 = a[1].lerp(b[1], f)
	var look: Vector3 = a[2].lerp(b[2], f)
	v.camera.position = pos
	v.camera.look_at(look, Vector3.UP)
	for k in shots.keys():
		if t >= k and t - d < k:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%s.png" % shots[k])
	if t > 30.0: get_tree().quit()
