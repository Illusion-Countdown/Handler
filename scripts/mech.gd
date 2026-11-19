class_name MechUnit
extends Node2D
## 一台破坏神 = 一名机师 + 一套兵装。几何三角，尖端朝向。

var cfg_id: String = "rifle"
var pilot: Dictionary = {}
var stats: Dictionary = {}
var hp: float = 120.0
var max_hp: float = 120.0
var facing: float = 0.0
var cd: float = 0.0
var dead: bool = false
var squad = null
var target = null
var trail: Array[Vector2] = []
var flash: float = 0.0
var stagger: float = 0.0
var slow: float = 0.0
var shield_time: float = 0.0
var overdrive: float = 0.0
var burnout: float = 0.0
var crit_ready: bool = true
var damage_dealt: float = 0.0
var kills: int = 0
var slot_offset: Vector2 = Vector2.ZERO
var wander: float = 0.0

const TRAIL_MAX := 14


func setup(config_id: String, p_pilot: Dictionary, pos: Vector2) -> void:
	cfg_id = config_id
	pilot = p_pilot
	stats = GameData.make_mech_stats(config_id, pilot)
	max_hp = float(stats["hp"])
	hp = max_hp
	position = pos
	facing = 0.0
	wander = randf() * TAU


func base_atk() -> float:
	return float(stats["atk"])


func vision_radius() -> float:
	return float(stats["vision"]) * GameData.CELL


func vision_half_angle() -> float:
	return deg_to_rad(float(stats["vision_angle"]) * 0.5)


func speed_px() -> float:
	var s := float(stats["speed"]) * GameData.CELL * GameData.MOVE_SCALE
	if slow > 0.0:
		s *= 0.78
	return s


func update_visual(dt: float) -> void:
	flash = max(0.0, flash - dt * 3.5)
	slow = max(0.0, slow - dt)
	if trail.is_empty() or trail[0].distance_to(position) > 5.0:
		trail.push_front(position)
		if trail.size() > TRAIL_MAX:
			trail.resize(TRAIL_MAX)
	queue_redraw()


func take_damage(amount: float) -> void:
	if dead:
		return
	var armor := float(stats["armor"])
	if shield_time > 0.0:
		armor += 0.4
	hp -= amount * (1.0 - clamp(armor, 0.0, 0.85))
	flash = 1.0
	if hp <= 0.0:
		hp = 0.0
		dead = true
		visible = false


func hp_frac() -> float:
	return clamp(hp / max_hp, 0.0, 1.0)


func _draw() -> void:
	var col: Color = GameData.CONFIGS[cfg_id]["color"]
	# 拖尾
	if trail.size() >= 2:
		for i in range(trail.size() - 1):
			var t := 1.0 - float(i) / float(trail.size())
			var a := t * t * 0.5
			var w := 2.4 * t + 0.6
			draw_line(trail[i] - position, trail[i + 1] - position,
				Color(col.r, col.g, col.b, a), w)
	# 悬浮环
	if not dead:
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color(col.r, col.g, col.b, 0.16), 1.0)
	# 三角
	var s := 12.0
	var pts := PackedVector2Array()
	pts.append(Vector2(s, 0.0).rotated(facing))
	pts.append(Vector2(-s * 0.72, s * 0.62).rotated(facing))
	pts.append(Vector2(-s * 0.42, 0.0).rotated(facing))
	pts.append(Vector2(-s * 0.72, -s * 0.62).rotated(facing))
	var body := Color(col.r, col.g, col.b, 0.95)
	if flash > 0.0:
		body = body.lerp(Color(1, 1, 1, 1), flash)
	if stagger > 0.0:
		body = body.lerp(Color(1.0, 0.55, 0.35, 1.0), 0.5)
	draw_colored_polygon(pts, body)
	draw_polyline(_closed(pts), Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.85), 1.6, true)
	# 血量条
	var w := 26.0
	var f := hp_frac()
	var by := 16.0
	draw_rect(Rect2(-w * 0.5, by, w, 2.6), Color(0.1, 0.14, 0.2, 0.9))
	var hc := Color(0.55, 0.95, 1.0)
	if f < 0.35:
		hc = Color(1.0, 0.45, 0.35)
	draw_rect(Rect2(-w * 0.5, by, w * f, 2.6), hc)
	if stagger > 0.0:
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 20, Color(1.0, 0.5, 0.3, 0.6), 1.5)


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q
