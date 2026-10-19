extends Node2D
## side-scroller view: Sun walks left/right in front of the block, then along the 2nd-floor corridor
var v: SchoolBuildingView
var hero: Sprite3D
var t := 0.0
const SPEED := 0.85
# segment: [duration, start x, end x, foot y, z, camera distance, camera height above feet]
var segs := [[14.0, -12.0, 10.0, 0.0, 2.2, 8.5, 1.6], [12.0, 9.0, -9.0, 3.76, -1.1, 9.5, 1.5]]
func _ready():
	v = SchoolBuildingView.new(); add_child(v)
	v.camera.fov = 42.0
	hero = Sprite3D.new()
	hero.texture = load("res://assets/characters/hero_walk.png")
	hero.hframes = 18
	hero.pixel_size = 1.72 / 120.0
	hero.centered = false
	hero.offset = Vector2(-34, 0)
	hero.shaded = false
	hero.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	hero.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	v.school.add_child(hero)
func _process(d):
	t += d
	var s := 0
	var tt := t
	while s < segs.size() - 1 and tt > segs[s][0]:
		tt -= segs[s][0]; s += 1
	var g = segs[s]
	var f := clampf(tt / g[0], 0, 1)
	var x: float = lerpf(g[1], g[2], f)
	var dir := signf(g[2] - g[1])
	hero.position = Vector3(x, g[3], g[4])
	hero.flip_h = dir < 0
	hero.frame = int(t * 12.0) % 18
	v.look(Vector3(x, g[3] + g[6], g[4] + g[5]), Vector3(x, g[3] + 1.2, g[4]))
	if t > 26.0: get_tree().quit()
