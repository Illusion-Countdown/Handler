class_name LegionUnit
extends Node2D
## 军团机体：无人兵器。黑色方块，没有驾驶舱。

var kind: String = "infantry"
var stats: Dictionary = {}
var hp: float = 50.0
var max_hp: float = 50.0
var facing: float = 0.0
var cd: float = 0.0
var dead: bool = false
var trail: Array[Vector2] = []
var flash: float = 0.0
var target = null
var marked: float = 0.0          # 剩余标记秒数
var exposed: float = 0.0         # 核心暴露（受伤加成）
var stun: float = 0.0
var charge: float = 0.0          # 蓄力剩余
var charge_cd: float = 6.0
var seen: float = 0.0            # 最近一次被我方看见的时间戳
var slow: float = 0.0
var jam_t: float = 0.0
var revealed: float = 0.0
var slot_angle: float = 0.0
var recovery_t: float = 0.0
var size: float = 11.0

const TRAIL_MAX := 18


func setup(k: String, pos: Vector2) -> void:
	kind = k
	stats = GameData.LEGION[k]
	max_hp = float(stats["hp"])
	hp = max_hp
	size = float(stats.get("size", 9.0))
	position = pos
	facing = randf() * TAU
	slot_angle = randf() * TAU
	charge_cd = randf_range(4.0, 9.0)


func speed_px() -> float:
	var s := float(stats["speed"]) * GameData.CELL * GameData.MOVE_SCALE
	if slow > 0.0:
		s *= 0.6
	return s


func atk_range_px() -> float:
	return float(stats["range"]) * GameData.CELL


func danger() -> float:
	return float(stats.get("danger", 1.0))


func update_visual(dt: float) -> void:
	flash = max(0.0, flash - dt * 3.0)
	marked = max(0.0, marked - dt)
	exposed = max(0.0, exposed - dt)
	slow = max(0.0, slow - dt)
	revealed = max(0.0, revealed - dt)
	if trail.is_empty() or trail[0].distance_to(position) > 6.0:
		trail.push_front(position)
		if trail.size() > TRAIL_MAX:
			trail.resize(TRAIL_MAX)
	queue_redraw()


func take_damage(amount: float) -> void:
	if dead:
		return
	var armor := float(stats["armor"])
	if exposed > 0.0:
		armor -= 0.2
	hp -= amount * (1.0 - clamp(armor, 0.0, 0.8))
	flash = 1.0
	if hp <= 0.0:
		hp = 0.0
		dead = true
		visible = false


func hp_frac() -> float:
	return clamp(hp / max_hp, 0.0, 1.0)


func _draw() -> void:
	var col := Color(1.15, 0.20, 0.13)
	if marked > 0.0:
		col = Color(2.2, 0.9, 0.3)
	if kind == "recovery":
		col = Color(1.0, 0.72, 0.2)
	elif kind == "ew":
		col = Color(0.85, 0.35, 0.55)
	elif kind == "shepherd":
		col = Color(1.0, 0.2, 0.1)

	# 拖尾
	if trail.size() >= 2:
		for i in range(trail.size() - 1):
			var t := 1.0 - float(i) / float(trail.size())
			var a := t * t * 0.42
			draw_line(trail[i] - position, trail[i + 1] - position,
				Color(col.r, col.g, col.b, a), 2.8 * t + 0.6)

	var s := size
	var ang := facing
	# 方块（可旋转）
	var pts := PackedVector2Array()
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c in corners:
		pts.append(Vector2(c.x, c.y).rotated(ang) * s)
	# 外发光（HDR 会吃 bloom）
	draw_circle(Vector2.ZERO, s * 1.45, Color(1.1, 0.12, 0.07, 0.045))
	draw_circle(Vector2.ZERO, s * 1.1, Color(1.2, 0.15, 0.08, 0.06))

	var body := Color(0.36, 0.04, 0.03, 1.0)
	if flash > 0.0:
		body = body.lerp(Color(1.6, 1.6, 1.6, 1.0), flash)
	draw_colored_polygon(pts, body)
	var edge := Color(col.r, col.g, col.b, 1.0)
	if marked > 0.0:
		edge = Color(2.6, 1.1, 0.35, 1.0)
	draw_polyline(_closed(pts), edge, 2.2, true)
	draw_polyline(_closed(pts), Color(edge.r * 1.15, edge.g * 1.1, edge.b * 1.05, 0.35), 0.8, true)

	# 内芯（白热）
	draw_circle(Vector2.ZERO, s * 0.24, Color(1.35, 1.0, 0.75, 0.85))
	draw_circle(Vector2.ZERO, s * 0.12, Color(1.7, 1.6, 1.45, 0.95))

	# 标记括线
	if marked > 0.0:
		var b := s + 4.0
		var l := 5.0
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p := Vector2(sx * b, sy * b)
				draw_line(p, p + Vector2(-sx * l, 0), Color(1.0, 0.85, 0.4, 0.8), 1.4)
				draw_line(p, p + Vector2(0, -sy * l), Color(1.0, 0.85, 0.4, 0.8), 1.4)

	# 蓄力
	if charge > 0.0:
		var f := 1.0 - charge / 2.5
		draw_arc(Vector2.ZERO, s + 12.0, -PI * 0.5, -PI * 0.5 + TAU * clamp(f, 0.0, 1.0),
			28, Color(1.0, 0.4, 0.2, 0.9), 2.4)

	# 血条
	if hp_frac() < 0.999:
		var w := s * 2.2
		var by := -s - 7.0
		draw_rect(Rect2(-w * 0.5, by, w, 2.0), Color(0.08, 0.1, 0.14, 0.85))
		draw_rect(Rect2(-w * 0.5, by, w * hp_frac(), 2.0), Color(1.0, 0.45, 0.3))


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q
