class_name FogOfWar
extends Node2D
## 战争迷雾。雾里什么都不画；雾外全部渲染。
## 三层：当前可见(bit) / 记忆(45s，会褪色) / 脉冲照明(6s)

var gw: int = GameData.GRID_W
var gh: int = GameData.GRID_H
var visible_bits: PackedByteArray
var remembered: PackedFloat32Array
var pulsed: PackedFloat32Array
var _img: Image
var _tex: ImageTexture
var _acc: float = 0.0
var _tick_acc: float = 0.0
var _prev_visible: Array = []
var world_size: Vector2

const MEM_FADE := 8.0


func setup(ws: Vector2) -> void:
	world_size = ws
	visible_bits.resize(gw * gh)
	remembered.resize(gw * gh)
	pulsed.resize(gw * gh)
	for i in range(gw * gh):
		visible_bits[i] = 0
		remembered[i] = 0.0
		pulsed[i] = 0.0
	_img = Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 1))
	_tex = ImageTexture.create_from_image(_img)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func begin_frame() -> void:
	for i in _prev_visible:
		visible_bits[i] = 0
	_prev_visible.clear()


func cell_of(p: Vector2) -> int:
	var cx := int(p.x / GameData.CELL)
	var cy := int(p.y / GameData.CELL)
	if cx < 0 or cy < 0 or cx >= gw or cy >= gh:
		return -1
	return cy * gw + cx


func in_bounds(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < world_size.x and p.y < world_size.y


func stamp_mech(m, dt: float) -> void:
	var r: float = m.vision_radius()
	var half: float = m.vision_half_angle()
	var cx := int(m.position.x / GameData.CELL)
	var cy := int(m.position.y / GameData.CELL)
	var rc := int(ceil(r / GameData.CELL))
	var is_scout: bool = m.cfg_id == "recon"
	for y in range(cy - rc, cy + rc + 1):
		if y < 0 or y >= gh:
			continue
		for x in range(cx - rc, cx + rc + 1):
			if x < 0 or x >= gw:
				continue
			var wp := Vector2((x + 0.5) * GameData.CELL, (y + 0.5) * GameData.CELL)
			var d := wp.distance_to(m.position)
			var idx := y * gw + x
			var ok := false
			if d <= GameData.CELL * 2.2:
				ok = true
			elif d <= r:
				var ang := abs(wrapf((wp - m.position).angle() - m.facing, -PI, PI))
				ok = ang <= half
			if ok:
				if visible_bits[idx] == 0:
					_prev_visible.append(idx)
				visible_bits[idx] = 1
				var mem := 45.0 if is_scout else 6.0
				if remembered[idx] < mem:
					remembered[idx] = mem


func stamp_pulse(center: Vector2, radius: float) -> void:
	var cx := int(center.x / GameData.CELL)
	var cy := int(center.y / GameData.CELL)
	var rc := int(ceil(radius / GameData.CELL))
	for y in range(cy - rc, cy + rc + 1):
		if y < 0 or y >= gh:
			continue
		for x in range(cx - rc, cx + rc + 1):
			if x < 0 or x >= gw:
				continue
			var wp := Vector2((x + 0.5) * GameData.CELL, (y + 0.5) * GameData.CELL)
			if wp.distance_to(center) <= radius:
				var idx := y * gw + x
				pulsed[idx] = 6.0
				if visible_bits[idx] == 0:
					_prev_visible.append(idx)
				visible_bits[idx] = 1
				if remembered[idx] < 6.0:
					remembered[idx] = 6.0


func tick(dt: float) -> void:
	_tick_acc += dt
	if _tick_acc >= 0.05:
		var d: float = _tick_acc
		_tick_acc = 0.0
		for i in range(gw * gh):
			if remembered[i] > 0.0:
				remembered[i] = max(0.0, remembered[i] - d)
			if pulsed[i] > 0.0:
				pulsed[i] = max(0.0, pulsed[i] - d)
	_acc += dt
	if _acc >= 0.14:
		_acc = 0.0
		_rebuild()


func _rebuild() -> void:
	# 只写一次字节数组，再交给 Image.set_data —— 避免 2240 次 set_pixel
	var n: int = gw * gh
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in range(n):
		var a := 1.0
		if visible_bits[i] == 1 or pulsed[i] > 0.0:
			a = 0.0
		elif remembered[i] > 0.0:
			a = 1.0 - 0.45 * clamp(remembered[i] / MEM_FADE, 0.0, 1.0)
		var o: int = i * 4
		data[o] = 1
		data[o + 1] = 2
		data[o + 2] = 5
		data[o + 3] = int(clamp(a, 0.0, 1.0) * 255.0)
	# 3x3 盒式模糊（只在字节数组上做，一次）
	var src := data.duplicate()
	for y in range(1, gh - 1):
		var row: int = y * gw
		for x in range(1, gw - 1):
			var s := 0
			for dy in range(-1, 2):
				var r2: int = (y + dy) * gw
				s += src[(r2 + x - 1) * 4 + 3]
				s += src[(r2 + x) * 4 + 3]
				s += src[(r2 + x + 1) * 4 + 3]
			data[(row + x) * 4 + 3] = s / 9
	_img.set_data(gw, gh, false, Image.FORMAT_RGBA8, data)
	_tex.update(_img)
	queue_redraw()


func is_lit(p: Vector2) -> bool:
	var i := cell_of(p)
	if i < 0:
		return false
	return visible_bits[i] == 1 or pulsed[i] > 0.0


func _draw() -> void:
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, world_size), false)
