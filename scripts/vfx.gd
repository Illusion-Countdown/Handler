class_name VFX
extends Node2D
## 瞬时特效：曳光、爆炸、脉冲、闪白。

var tracers: Array = []
var blasts: Array = []
var pulses: Array = []
var flashes: Array = []
var rings: Array = []


func tracer(a: Vector2, b: Vector2, col: Color, life: float = 0.08) -> void:
	tracers.append({"a": a, "b": b, "col": col, "t": life, "max": life})


func explosion(pos: Vector2, col: Color, radius: float) -> void:
	blasts.append({"p": pos, "col": col, "r": radius, "t": 0.35, "max": 0.35})
	rings.append({"p": pos, "col": col, "r": 6.0, "t": 0.45, "max": 0.45, "rmax": radius * 1.6})


func pulse(pos: Vector2, radius: float) -> void:
	pulses.append({"p": pos, "r": radius, "t": 0.8, "max": 0.8})


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
	for x in flashes:
		var f: float = x["t"] / x["max"]
		var sz := get_viewport().get_visible_rect().size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(x["col"].r, x["col"].g, x["col"].b, f * x["col"].a))
