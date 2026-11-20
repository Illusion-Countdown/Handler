class_name LegionUnit
extends Node2D
## 军团机体：无人兵器。
## 参考视频的写法：深色填充 + 粗亮描边 + 短拖尾，靠形状和颜色区分兵种，不靠大光晕。

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
var marked: float = 0.0
var exposed: float = 0.0
var stun: float = 0.0
var charge: float = 0.0
var charge_cd: float = 6.0
var seen: float = 0.0
var slow: float = 0.0
var jam_t: float = 0.0
var recovery_t: float = 0.0
var revealed: float = 0.0
var slot_angle: float = 0.0
var size: float = 12.0

const TRAIL_MAX := 12


func setup(k: String, pos: Vector2) -> void:
	kind = k
	stats = GameData.LEGION[k]
	max_hp = float(stats["hp"])
	hp = max_hp
	size = float(stats.get("size", 12.0))
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
	if trail.is_empty() or trail[0].distance_to(position) > 8.0:
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


func _palette() -> Array:
	match kind:
		"armored":
			return [Color(1.0, 0.62, 0.12), Color(0.42, 0.22, 0.04)]   # 琥珀重装
		"artillery":
			return [Color(1.0, 0.88, 0.16), Color(0.40, 0.34, 0.03)]   # 黄色远火
		"ew":
			return [Color(0.95, 0.30, 0.92), Color(0.34, 0.06, 0.34)]  # 品红电子战
		"recovery":
			return [Color(1.0, 0.70, 0.20), Color(0.38, 0.26, 0.05)]   # 橙黄回收
		"shepherd":
			return [Color(1.0, 0.14, 0.08), Color(0.42, 0.04, 0.02)]   # BOSS 血红
		_:
			return [Color(1.0, 0.24, 0.14), Color(0.40, 0.06, 0.04)]   # 步兵红


func _shape_points(kind_name: String, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind_name:
		"infantry", "artillery":
			# 三角形（尖端朝前）
			pts.append(Vector2(s, 0.0).rotated(facing))
			pts.append(Vector2(-s * 0.78, s * 0.72).rotated(facing))
			pts.append(Vector2(-s * 0.78, -s * 0.72).rotated(facing))
		"armored":
			# 厚边框方形（正方，不旋转）
			pts.append(Vector2(-s * 0.85, -s * 0.85))
			pts.append(Vector2(s * 0.85, -s * 0.85))
			pts.append(Vector2(s * 0.85, s * 0.85))
			pts.append(Vector2(-s * 0.85, s * 0.85))
		"ew":
			# 菱形
			pts.append(Vector2(0.0, -s).rotated(facing * 0.3))
			pts.append(Vector2(s, 0.0).rotated(facing * 0.3))
			pts.append(Vector2(0.0, s).rotated(facing * 0.3))
			pts.append(Vector2(-s, 0.0).rotated(facing * 0.3))
		"recovery":
			# 六边形
			for i in range(6):
				var a: float = TAU * float(i) / 6.0 + facing * 0.3
				pts.append(Vector2(cos(a), sin(a)) * s)
		"shepherd":
			# 大八边形
			for i in range(8):
				var a2: float = TAU * float(i) / 8.0 + facing * 0.15
				pts.append(Vector2(cos(a2), sin(a2)) * s)
		_:
			pts.append(Vector2(s, 0.0).rotated(facing))
			pts.append(Vector2(-s * 0.78, s * 0.72).rotated(facing))
			pts.append(Vector2(-s * 0.78, -s * 0.72).rotated(facing))
	return pts


func _draw() -> void:
	var pal: Array = _palette()
	var edge: Color = pal[0]
	var fill: Color = pal[1]
	if marked > 0.0:
		edge = edge.lerp(Color(1.0, 0.92, 0.45), 0.6)
	if flash > 0.0:
		fill = fill.lerp(Color(1.0, 1.0, 1.0), flash * 0.8)

	# 拖尾：细、短、跟本体同色
	if trail.size() >= 2:
		for i in range(trail.size() - 1):
			var t: float = 1.0 - float(i) / float(trail.size())
			draw_line(trail[i] - position, trail[i + 1] - position,
				Color(edge.r, edge.g, edge.b, t * t * 0.45), 2.2 * t + 0.5)

	var pts := _shape_points(kind, size)
	draw_colored_polygon(pts, fill)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	# 厚描边（参考图的关键）
	draw_polyline(closed, edge, 3.4, true)

	# 内芯：一个小亮点，不加光晕
	if kind != "armored":
		draw_circle(Vector2.ZERO, size * 0.16, Color(edge.r, edge.g, edge.b, 0.95))

	# 重装：额外的内框
	if kind == "armored":
		var inner := PackedVector2Array()
		var s2: float = size * 0.42
		inner.append(Vector2(-s2, -s2))
		inner.append(Vector2(s2, -s2))
		inner.append(Vector2(s2, s2))
		inner.append(Vector2(-s2, s2))
		inner.append(inner[0])
		draw_polyline(inner, Color(edge.r, edge.g, edge.b, 0.55), 1.6, true)

	# BOSS：外圈与核心
	if kind == "shepherd":
		draw_arc(Vector2.ZERO, size * 1.25, 0.0, TAU, 32, Color(edge.r, edge.g, edge.b, 0.45), 2.0)
		draw_arc(Vector2.ZERO, size * 0.55, 0.0, TAU, 24, Color(edge.r, edge.g, edge.b, 0.9), 2.4)
		if exposed > 0.0:
			draw_arc(Vector2.ZERO, size * 1.55, 0.0, TAU, 40, Color(1.0, 0.95, 0.6, 0.85), 2.6)

	# 标记括线
	if marked > 0.0:
		var b: float = size + 5.0
		var l: float = 6.0
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p: Vector2 = Vector2(sx * b, sy * b)
				draw_line(p, p + Vector2(-sx * l, 0), Color(1.0, 0.9, 0.45, 0.9), 1.8)
				draw_line(p, p + Vector2(0, -sy * l), Color(1.0, 0.9, 0.45, 0.9), 1.8)

	# 蓄力
	if charge > 0.0:
		var f: float = 1.0 - charge / 2.5
		draw_arc(Vector2.ZERO, size + 14.0, -PI * 0.5, -PI * 0.5 + TAU * clamp(f, 0.0, 1.0),
			28, Color(1.0, 0.55, 0.2, 0.9), 3.0)

	# 血条
	if hp_frac() < 0.999:
		var w: float = size * 2.2
		var by: float = -size - 9.0
		draw_rect(Rect2(-w * 0.5, by, w, 2.6), Color(0.06, 0.07, 0.1, 0.9))
		draw_rect(Rect2(-w * 0.5, by, w * hp_frac(), 2.6), edge)
