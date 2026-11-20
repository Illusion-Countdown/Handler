class_name MechUnit
extends Node2D
## 一台破坏神 = 一名机师 + 一套兵装。
## 参考视频：白/青实心三角 + 粗亮描边 + 短拖尾，不用大光晕。

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
var sweep_cd: float = 3.0

const TRAIL_MAX := 16


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
	sweep_cd = max(0.0, sweep_cd - dt)
	if trail.is_empty() or trail[0].distance_to(position) > 7.0:
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


func m_overdrive() -> bool:
	return overdrive > 0.0


func _draw() -> void:
	var base: Color = GameData.CONFIGS[cfg_id]["color"]
	var edge := Color(base.r * 0.72, base.g * 0.88, base.b * 1.0)
	var fill := Color(0.05, 0.16, 0.22, 1.0)
	if m_overdrive():
		edge = Color(1.0, 0.72, 0.25)
		fill = Color(0.35, 0.18, 0.02, 1.0)
	if flash > 0.0:
		fill = fill.lerp(Color(1.0, 1.0, 1.0), flash * 0.85)
	if stagger > 0.0:
		edge = edge.lerp(Color(1.0, 0.45, 0.3), 0.6)

	# 拖尾
	if trail.size() >= 2:
		for i in range(trail.size() - 1):
			var t: float = 1.0 - float(i) / float(trail.size())
			draw_line(trail[i] - position, trail[i + 1] - position,
				Color(edge.r, edge.g, edge.b, t * t * 0.5), 2.4 * t + 0.6)

	# 机体：三角
	var s := 13.0
	var pts := PackedVector2Array()
	pts.append(Vector2(s, 0.0).rotated(facing))
	pts.append(Vector2(-s * 0.74, s * 0.66).rotated(facing))
	pts.append(Vector2(-s * 0.40, 0.0).rotated(facing))
	pts.append(Vector2(-s * 0.74, -s * 0.66).rotated(facing))
	draw_colored_polygon(pts, fill)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, edge, 3.4, true)

	# 核心点
	draw_circle(Vector2.ZERO, 2.4, Color(edge.r * 1.3, edge.g * 1.4, edge.b * 1.5, 1.0))

	# 血量条
	var w := 26.0
	var f := hp_frac()
	var by := 18.0
	draw_rect(Rect2(-w * 0.5, by, w, 3.0), Color(0.05, 0.08, 0.12, 0.95))
	var hc := Color(0.55, 0.95, 1.0)
	if f < 0.35:
		hc = Color(1.0, 0.45, 0.3)
	draw_rect(Rect2(-w * 0.5, by, w * f, 3.0), hc)

	if stagger > 0.0:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(1.0, 0.5, 0.3, 0.65), 2.0)
