class_name VFX
extends Node2D
## 瞬时特效：曳光、爆炸、脉冲、闪白。

var tracers: Array = []
var blasts: Array = []
var pulses: Array = []
var flashes: Array = []
var rings: Array = []
var texts: Array = []
var muzzles: Array = []
var slashes: Array = []
var beams: Array = []
var debris_list: Array = []
var ripples: Array = []


func tracer(a: Vector2, b: Vector2, col: Color, life: float = 0.08) -> void:
	tracers.append({"a": a, "b": b, "col": col, "t": life, "max": life})


func explosion(pos: Vector2, col: Color, radius: float) -> void:
	blasts.append({"p": pos, "col": col, "r": radius, "t": 0.35, "max": 0.35})
	rings.append({"p": pos, "col": col, "r": 6.0, "t": 0.45, "max": 0.45, "rmax": radius * 1.6})


func pulse(pos: Vector2, radius: float) -> void:
	pulses.append({"p": pos, "r": radius, "t": 0.8, "max": 0.8})


func number(pos: Vector2, value: float, col: Color, big: bool = false) -> void:
	texts.append({"p": pos, "v": value, "col": col, "t": 0.75, "max": 0.75, "big": big})


func muzzle(pos: Vector2, ang: float, col: Color) -> void:
	muzzles.append({"p": pos, "a": ang, "col": col, "t": 0.09, "max": 0.09})


func slash(pos: Vector2, ang: float, radius: float, col: Color) -> void:
	slashes.append({"p": pos, "a": ang, "r": radius, "col": col, "t": 0.16, "max": 0.16})


func beam(a: Vector2, b: Vector2, col: Color, w: float = 3.0) -> void:
	beams.append({"a": a, "b": b, "col": col, "w": w, "t": 0.14, "max": 0.14})


func debris(pos: Vector2, col: Color, count: int = 6) -> void:
	for i in range(count):
		var a := randf() * TAU
		var sp := randf_range(40.0, 160.0)
		debris_list.append({"p": pos, "v": Vector2.RIGHT.rotated(a) * sp,
			"col": col, "t": randf_range(0.25, 0.55), "max": 0.55})


func impact(pos: Vector2, col: Color, size: float = 1.0) -> void:
	rings.append({"p": pos, "col": col, "r": 3.0, "t": 0.22, "max": 0.22, "rmax": 26.0 * size})
	for i in range(3):
		var a := randf() * TAU
		var sp := randf_range(60.0, 160.0) * size
		debris_list.append({"p": pos, "v": Vector2.RIGHT.rotated(a) * sp,
			"col": col, "t": randf_range(0.12, 0.3), "max": 0.3})


func ripple(pos: Vector2, col: Color, radius: float) -> void:
	ripples.append({"p": pos, "r": radius, "col": col, "t": 0.5, "max": 0.5})


func flash(col: Color, life: float) -> void:
	flashes.append({"col": col, "t": life, "max": life})


func _process(delta: float) -> void:
	var alive_t := []
	for x in tracers:
		x["t"] -= delta
		if x["t"] > 0.0:
			alive_t.append(x)
	tracers = alive_t
	var alive_b := []
	for x in blasts:
		x["t"] -= delta
		if x["t"] > 0.0:
			alive_b.append(x)
	blasts = alive_b
	var alive_p := []
	for x in pulses:
		x["t"] -= delta
		if x["t"] > 0.0:
			alive_p.append(x)
	pulses = alive_p
	var alive_f := []
	for x in flashes:
		x["t"] -= delta
		if x["t"] > 0.0:
			alive_f.append(x)
	flashes = alive_f
	var alive_r := []
	for x in rings:
		x["t"] -= delta
		if x["t"] > 0.0:
			alive_r.append(x)
	rings = alive_r
	var alive_x := []
	for x in texts:
		x["t"] -= delta
		x["p"] += Vector2(0, -26.0 * delta)
		if x["t"] > 0.0:
			alive_x.append(x)
	texts = alive_x
	for arr in [muzzles, slashes, beams, debris_list, ripples]:
		var keep := []
		for x in arr:
			x["t"] -= delta
			if arr == debris_list:
				x["p"] += x["v"] * delta
				x["v"] *= 0.92
			if x["t"] > 0.0:
				keep.append(x)
		arr.clear()
		for k in keep:
			arr.append(k)
	queue_redraw()


func _draw() -> void:
	for x in tracers:
		var f: float = x["t"] / x["max"]
		draw_line(x["a"], x["b"], Color(x["col"].r, x["col"].g, x["col"].b, f), 2.0)
	for x in blasts:
		var f: float = x["t"] / x["max"]
		var r: float = x["r"] * (1.0 - f * 0.6)
		draw_circle(x["p"], r * f, Color(x["col"].r, x["col"].g, x["col"].b, f * 0.55))
	for x in rings:
		var f: float = 1.0 - x["t"] / x["max"]
		var r: float = lerp(x["r"], x["rmax"], f)
		draw_arc(x["p"], r, 0.0, TAU, 32, Color(x["col"].r, x["col"].g, x["col"].b, (1.0 - f) * 0.8), 2.0)
	for x in pulses:
		var f: float = 1.0 - x["t"] / x["max"]
		draw_arc(x["p"], x["r"] * (0.2 + f * 0.8), 0.0, TAU, 48,
			Color(0.4, 0.85, 1.0, (1.0 - f) * 0.5), 2.0)
	# 枪口焰
	for x in muzzles:
		var f: float = x["t"] / x["max"]
		var d: Vector2 = Vector2.RIGHT.rotated(x["a"])
		var p: Vector2 = x["p"]
		var tri := PackedVector2Array([
			p + d * 16.0,
			p + d.rotated(0.55) * 6.0,
			p + d.rotated(-0.55) * 6.0])
		draw_colored_polygon(tri, Color(1.0, 0.95, 0.7, f * 0.9))
		draw_circle(p, 7.0 * f, Color(x["col"].r, x["col"].g, x["col"].b, f * 0.5))
	# 近战斩击
	for x in slashes:
		var f: float = x["t"] / x["max"]
		var a0: float = x["a"] - 0.9 + (1.0 - f) * 0.6
		draw_arc(x["p"], x["r"] * (0.7 + 0.4 * (1.0 - f)), a0, a0 + 1.6, 18,
			Color(x["col"].r, x["col"].g, x["col"].b, f), 3.0)
	# 光束
	for x in beams:
		var f: float = x["t"] / x["max"]
		draw_line(x["a"], x["b"], Color(x["col"].r, x["col"].g, x["col"].b, f), x["w"] * (0.4 + f))
		draw_line(x["a"], x["b"], Color(1.0, 1.0, 1.0, f * 0.8), x["w"] * 0.35)
	# 碎片
	for x in debris_list:
		var f: float = x["t"] / x["max"]
		draw_rect(Rect2(x["p"], Vector2(2.5, 2.5)), Color(x["col"].r, x["col"].g, x["col"].b, f))
	# 电磁涟漪
	for x in ripples:
		var f: float = 1.0 - x["t"] / x["max"]
		draw_arc(x["p"], x["r"] * f, 0.0, TAU, 28,
			Color(x["col"].r, x["col"].g, x["col"].b, (1.0 - f) * 0.7), 2.0)
	var fnt := ThemeDB.fallback_font
	for x in texts:
		var a: float = clamp(x["t"] / x["max"], 0.0, 1.0)
		var sz: int = 20 if x["big"] else 14
		var s := "%d" % int(x["v"])
		draw_string(fnt, x["p"] + Vector2(-8, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz,
			Color(x["col"].r, x["col"].g, x["col"].b, a))
	for x in flashes:
		var f: float = x["t"] / x["max"]
		var sz := get_viewport().get_visible_rect().size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(x["col"].r, x["col"].g, x["col"].b, f * x["col"].a))
