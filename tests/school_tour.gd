extends Node2D
## tour: around outside, in at the entrance, up the stairs to the 3rd floor, along its corridor
var v: SchoolBuildingView
var t := 0.0
const E := 1.6
var keys := [
	[0.0, Vector3(0, 1.6, 30), Vector3(0, 5, 0)],
	[4.0, Vector3(26, 14, 22), Vector3(0, 4, -3)],
	[8.0, Vector3(-28, 6, 14), Vector3(-6, 4, -3)],
	[12.0, Vector3(-30, 8, -24), Vector3(0, 5, -5)],
	[16.0, Vector3(0, E, 12), Vector3(0, 1.6, 0)],
	[19.0, Vector3(-0.9, 0.46 + E, -1.0), Vector3(-1.8, 1.8, -6)],
	[21.0, Vector3(-1.8, 0.46 + E, -2.6), Vector3(-1.8, 2.6, -7)],
	[24.0, Vector3(-1.8, 2.11 + E, -5.8), Vector3(-1.8, 3.4, -9)],
	[25.5, Vector3(-1.0, 2.11 + E, -6.4), Vector3(0.0, 3.0, 0)],
	[28.5, Vector3(-0.1, 3.76 + E, -2.8), Vector3(-0.1, 5.4, 4)],
	[30.0, Vector3(-0.6, 3.76 + E, -1.3), Vector3(-15, 5.2, -1.3)],
	[33.0, Vector3(-6.0, 3.76 + E, -1.3), Vector3(-25, 5.2, -1.3)],
	[36.0, Vector3(-1.8, 3.76 + E, -2.4), Vector3(-1.8, 5.8, -7)],
	[39.0, Vector3(-1.8, 5.4 + E, -5.8), Vector3(-1.8, 6.7, -9)],
	[40.5, Vector3(-1.0, 5.4 + E, -6.4), Vector3(0.0, 6.3, 0)],
	[43.5, Vector3(-0.1, 7.04 + E, -2.8), Vector3(-0.1, 8.6, 4)],
	[45.0, Vector3(0.5, 7.04 + E, -1.3), Vector3(15, 8.4, -1.3)],
	[48.0, Vector3(8.0, 7.04 + E, -1.3), Vector3(25, 8.4, -1.3)],
	[49.0, Vector3(8.0, 7.04 + E, -1.3), Vector3(25, 8.4, -1.3)],
]
var shots := {0.2: "t00_front", 4.0: "t01_aerial", 8.0: "t02_left", 12.0: "t03_back", 16.0: "t04_court",
	19.0: "t05_hall", 22.5: "t06_flightA", 25.5: "t07_landing", 27.5: "t08_flightB", 30.5: "t09_2f",
	37.5: "t10_flight2", 44.0: "t11_3f_arrive", 47.5: "t12_3f"}
func _ready():
	var bg := ColorRect.new(); bg.color = Color(0.55, 0.6, 0.68); bg.size = Vector2(640, 360); add_child(bg)
	v = SchoolBuildingView.new(); add_child(v)
func _process(d):
	t += d
	var i := 0
	while i < keys.size() - 2 and t > keys[i + 1][0]: i += 1
	var a = keys[i]; var b = keys[i + 1]
	var f := smoothstep(0.0, 1.0, clampf((t - a[0]) / (b[0] - a[0]), 0, 1))
	v.look(a[1].lerp(b[1], f), a[2].lerp(b[2], f))
	for k in shots.keys():
		if t >= k and t - d < k:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT") + "/%s.png" % shots[k])
	if t > 49.0: get_tree().quit()
