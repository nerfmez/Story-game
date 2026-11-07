extends Node3D
## A girl in a summer dress and straw hat who walks around a diorama: WASD (relative to
## the camera), or tap / click the ground to walk there. Built from the kit like the rest
## of the scene (cel-shaded, ink lines), with a simple walk cycle: legs and arms swing,
## the body bobs, the dress sways. She follows the ground of the layout and stops at walls,
## buildings, steep rock and water deeper than her knees.
## The layout gives two callables: ground_at(x, z) -> height, blocked_at(x, z) -> bool.

const Kit := preload("res://scripts/konbini_kit.gd")

const SPEED := 2.2           # metres a second
const MAX_SLOPE := 1.05      # rise over run she can still walk up (stairs, the slope to the sea)
const WADE := 0.3            # deepest water she walks into
const SEA_Y := 0.08

const SKIN := Color(1.0, 0.86, 0.76)
const HAIR := Color(0.3, 0.2, 0.17)
const DRESS := Color(0.97, 0.97, 0.95)
const SASH := Color(0.36, 0.62, 0.9)
const STRAW := Color(0.93, 0.8, 0.5)
const RIBBON := Color(0.88, 0.3, 0.3)

var ground_at: Callable
var blocked_at: Callable
var rig: Node3D               # the camera rig, for the direction of WASD
var has_target := false
var target := Vector3.ZERO
var marker: Node3D
var _route: Array = []       # points still to walk through after target

var _phase := 0.0
var _move := 0.0              # 0 standing .. 1 walking, eased
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _body: Node3D
var _skirt: Node3D

func setup(camera_rig: Node3D, ground: Callable, blocked: Callable) -> void:
	rig = camera_rig
	ground_at = ground
	blocked_at = blocked
	position.y = ground_at.call(position.x, position.z)

func _ready() -> void:
	var k := Kit.new(self)
	k.shadows = true
	_body = _pivot("Body", Vector3(0, 0.0, 0))
	# legs from the hip, sandals
	for side in [-1.0, 1.0]:
		var leg := _pivot("Leg", Vector3(side * 0.07, 0.62, 0), _body)
		k.rod(Vector3.ZERO, Vector3(0, -0.58, 0), 0.042, SKIN, {"node": leg, "seg": 8, "line": 0.6})
		k.box(Vector3(0, -0.6, 0.03), Vector3(0.08, 0.03, 0.17), Color(0.55, 0.35, 0.25), {"node": leg, "line": 0.6})
		_legs.append(leg)
	# the dress: a bodice and a flared skirt that sways, a blue sash at the waist
	k.cyl(Vector3(0, 0.98, 0), 0.13, 0.32, DRESS, {"node": _body, "top": 0.85, "seg": 12, "line": 0.7})
	_skirt = _pivot("Skirt", Vector3(0, 0.84, 0), _body)
	k.cyl(Vector3(0, -0.19, 0), 0.25, 0.38, DRESS, {"node": _skirt, "top": 0.55, "seg": 14, "line": 0.7})
	k.cyl(Vector3(0, 0.86, 0), 0.135, 0.06, SASH, {"node": _body, "seg": 12, "line": 0.5})
	# arms from the shoulder, short sleeves
	for side in [-1.0, 1.0]:
		var arm := _pivot("Arm", Vector3(side * 0.16, 1.1, 0), _body)
		k.ball(Vector3(side * 0.01, -0.03, 0), Vector3(0.06, 0.07, 0.06), DRESS, {"node": arm, "seg": 8, "line": 0.6})
		k.rod(Vector3(side * 0.01, -0.06, 0), Vector3(side * 0.03, -0.42, 0.02), 0.033, SKIN, {"node": arm, "seg": 8, "line": 0.6})
		k.ball(Vector3(side * 0.03, -0.44, 0.02), Vector3.ONE * 0.04, SKIN, {"node": arm, "seg": 8, "line": 0.5})
		_arms.append(arm)
	# head: neck, face, hair with bangs and a ponytail, eyes and a blush
	k.rod(Vector3(0, 1.12, 0), Vector3(0, 1.2, 0), 0.04, SKIN, {"node": _body, "line": 0.0})
	var head := Vector3(0, 1.33, 0.01)
	k.ball(head, Vector3(0.15, 0.16, 0.15), SKIN, {"node": _body, "seg": 14, "line": 0.8})
	k.ball(head + Vector3(0, 0.04, -0.025), Vector3(0.165, 0.16, 0.16), HAIR, {"node": _body, "seg": 14, "line": 0.8})
	k.box(head + Vector3(0, 0.08, 0.12), Vector3(0.24, 0.07, 0.06), HAIR, {"node": _body, "line": 0.5})
	k.ball(head + Vector3(0, -0.02, -0.19), Vector3(0.07, 0.11, 0.06), HAIR, {"node": _body, "seg": 10, "line": 0.6})
	for side in [-1.0, 1.0]:
		k.box(head + Vector3(side * 0.055, 0.0, 0.142), Vector3(0.035, 0.055, 0.01), Color(0.18, 0.14, 0.2), {"node": _body, "line": 0.0})
		k.box(head + Vector3(side * 0.08, -0.05, 0.13), Vector3(0.04, 0.015, 0.01), Color(1.0, 0.62, 0.62), {"node": _body, "line": 0.0})
	# the straw hat with a red ribbon
	k.cyl(head + Vector3(0, 0.13, 0), 0.27, 0.025, STRAW, {"node": _body, "seg": 18, "line": 0.7})
	k.cyl(head + Vector3(0, 0.19, -0.005), 0.13, 0.11, STRAW, {"node": _body, "top": 0.85, "seg": 14, "line": 0.7})
	k.cyl(head + Vector3(0, 0.155, -0.005), 0.133, 0.035, RIBBON, {"node": _body, "seg": 14, "line": 0.0})
	k.finish()
	# a ring on the ground where she is walking to
	marker = Node3D.new()
	marker.name = "WalkTarget"
	marker.visible = false
	var mk := Kit.new(marker)
	mk.torus(Vector3.ZERO, 0.22, 0.02, Color(1.0, 1.0, 1.0), {"line": 0.0, "emit": 0.6})
	mk.finish()
	add_sibling.call_deferred(marker)

func _pivot(name: String, at: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = at
	(parent if parent != null else self).add_child(n)
	return n

## Walks to a point on the ground, through any points given before it.
func walk_to(p: Vector3, via: Array = []) -> void:
	_route = via.duplicate()
	_route.append(p)
	_next()
	marker.position = p + Vector3(0, 0.03, 0)
	marker.visible = true

func _next() -> void:
	target = _route.pop_front()
	has_target = true

func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	var key := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): key.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): key.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): key.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): key.y -= 1.0
	if key != Vector2.ZERO and rig != null:
		var y := deg_to_rad(float(rig.get("yaw")))
		var forward := Vector3(-sin(y), 0, -cos(y))
		var right := Vector3(cos(y), 0, -sin(y))
		dir = (right * key.x + forward * key.y).normalized()
		has_target = false
		_route.clear()
		marker.visible = false
	elif has_target:
		var to := target - position
		to.y = 0.0
		if to.length() < 0.12:
			if _route.is_empty():
				has_target = false
				marker.visible = false
			else:
				_next()
		else:
			dir = to.normalized()
	var moving := dir != Vector3.ZERO and _try_move(dir * SPEED * delta)
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-delta * 12.0))
	if dir != Vector3.ZERO and not moving and has_target:
		has_target = false   # something is in the way
		marker.visible = false
	_move = lerpf(_move, 1.0 if moving else 0.0, 1.0 - exp(-delta * 10.0))
	position.y = lerpf(position.y, ground_at.call(position.x, position.z), 1.0 - exp(-delta * 20.0))
	_animate(delta)

## Moves by step if the way is open; slides along a wall if only one axis is blocked.
func _try_move(step: Vector3) -> bool:
	for s in [step, Vector3(step.x, 0, 0), Vector3(0, 0, step.z)]:
		if s.length() < 0.0005:
			continue
		var to: Vector3 = position + s
		if _can_stand(to, s.length()):
			position.x = to.x
			position.z = to.z
			return true
	return false

func _can_stand(p: Vector3, dist: float) -> bool:
	if blocked_at.call(p.x, p.z):
		return false
	var g: float = ground_at.call(p.x, p.z)
	if g < SEA_Y - WADE:
		return false
	var here: float = ground_at.call(position.x, position.z)
	return absf(g - here) <= maxf(dist, 0.01) * MAX_SLOPE + 0.02

func _animate(delta: float) -> void:
	_phase += delta * (2.0 + SPEED * 3.2 * _move)
	var swing := sin(_phase) * 0.55 * _move
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8
	_arms[0].rotation.z = -0.08
	_arms[1].rotation.z = 0.08
	# a bob at each step, a little breathing while standing
	_body.position.y = absf(sin(_phase)) * 0.035 * _move + sin(_phase * 0.5) * 0.004 * (1.0 - _move)
	_skirt.rotation.x = -swing * 0.12
	_skirt.rotation.z = sin(_phase * 0.5) * 0.03
