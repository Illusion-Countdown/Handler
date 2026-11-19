class_name BattleHUD
extends CanvasLayer

var battle = null
var canvas: Control
var font: Font
var t: float = 0.0
var show_help: bool = true

const COL_TEXT := Color(0.80, 0.91, 1.0, 0.95)
const COL_DIM := Color(0.45, 0.58, 0.70, 0.85)
const COL_ACC := Color(0.35, 0.85, 1.0, 1.0)
const COL_WARN := Color(1.0, 0.42, 0.28, 1.0)
const COL_GOLD := Color(1.0, 0.82, 0.35, 1.0)


func _ready() -> void:
	layer = 20
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "PingFang SC", "sans-serif"])
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_hud)


func _process(delta: float) -> void:
	t += delta
	canvas.queue_redraw()


func _txt(pos: Vector2, s: String, size: int, col: Color) -> void:
	canvas.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _txt_r(pos: Vector2, s: String, size: int, col: Color) -> void:
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2(pos.x - w, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(r: Rect2, f: float, col: Color, bg: Color = Color(0.06, 0.09, 0.13, 0.9)) -> void:
	canvas.draw_rect(r, bg)
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(f, 0.0, 1.0), r.size.y)), col)


func _draw_hud() -> void:
	if battle == null:
		return
	var vs: Vector2 = canvas.size
	if vs.x < 10.0:
		vs = Vector2(1600, 900)
	_draw_squads(vs)
	_draw_status(vs)
	_draw_waves(vs)
	_draw_cards(vs)
	_draw_hint(vs)
	_draw_footer(vs)
	_draw_pause(vs)
	_draw_over(vs)


func _draw_over(vs: Vector2) -> void:
	if battle.state != "over":
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.02, 0.05, 0.45))
	canvas.draw_string(font, Vector2(vs.x * 0.5 - 240, vs.y * 0.5), "作 战 结 束",
		HORIZONTAL_ALIGNMENT_CENTER, 480, 40, Color(0.8, 0.95, 1.0))


func _draw_pause(vs: Vector2) -> void:
	if not battle.paused:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.0, 0.02, 0.05, 0.55))
	var cx := vs.x * 0.5
	var cy := vs.y * 0.5
	canvas.draw_string(font, Vector2(cx - 200, cy - 10), "已 暂 停", HORIZONTAL_ALIGNMENT_CENTER,
		400, 46, Color(1.0, 0.86, 0.4))
	canvas.draw_string(font, Vector2(cx - 240, cy + 34), "按 空格 继续作战",
		HORIZONTAL_ALIGNMENT_CENTER, 480, 18, Color(0.8, 0.9, 1.0))
	canvas.draw_string(font, Vector2(cx - 240, cy + 60), "（暂停时 WASD / 滚轮 仍然可以看战场）",
		HORIZONTAL_ALIGNMENT_CENTER, 480, 13, Color(0.5, 0.62, 0.74))


func _draw_squads(vs: Vector2) -> void:
	var y := 22.0
	for sq in battle.squads:
		var w := 268.0
		var h := 84.0
		var panel := Rect2(20.0, y, w, h)
		canvas.draw_rect(panel, Color(0.03, 0.06, 0.09, 0.82))
		var edge := COL_ACC if sq == battle.selected else Color(0.16, 0.28, 0.36, 0.9)
		canvas.draw_rect(panel, edge, false, 1.4)
		if sq.broken:
			canvas.draw_rect(panel, Color(1.0, 0.3, 0.2, 0.10))
		var name: String = sq.label
		_txt(Vector2(panel.position.x + 12, y + 24), "%s · %d 台" % [name, sq.size_alive()], 17, COL_TEXT)
		# 功能读数
		var role := _role_of(sq)
		_txt_r(Vector2(panel.position.x + w - 12, y + 24), role, 14, COL_ACC)
		# 完整性
		_bar(Rect2(panel.position.x + 12, y + 34, w - 24, 5), sq.integrity / 100.0,
			Color(0.35, 0.9, 0.75) if sq.integrity > 30 else COL_WARN)
		# 姿态 / ROE
		var st: String = GameData.STANCE_NAME.get(sq.stance, sq.stance)
		var roe: String = GameData.ROE_NAME.get(sq.roe, sq.roe)
		_txt(Vector2(panel.position.x + 12, y + 60), "姿态 " + st + "   规则 " + roe, 13, COL_DIM)
		# 执行率
		var er: float = sq.exec_rate()
		_txt(Vector2(panel.position.x + 12, y + 76), "执行率 %d%%" % int(er), 13,
			COL_GOLD if er > 70.0 else COL_WARN)
		# 注意力
		var aw := 90.0
		_bar(Rect2(panel.position.x + w - 12 - aw, y + 70, aw, 4), sq.attention * float(battle.squads.size()) * 0.5,
			Color(0.55, 0.75, 1.0))
		_txt_r(Vector2(panel.position.x + w - 12, y + 60), "注意", 11, COL_DIM)
		# 命令在途
		if sq.order_t > 0.0:
			var f: float = 1.0 - sq.order_t / 3.0
			_bar(Rect2(panel.position.x + 12, y + h - 3, w - 24, 2), f, COL_GOLD)
		y += h + 10.0


func _role_of(sq) -> String:
	var fire := 0.0
	var sense := 0.0
	var tough := 0.0
	for m in sq.alive():
		fire += float(m.stats["atk"]) * float(m.stats["aspd"])
		sense += float(m.stats["vision"])
		tough += float(m.stats["hp"]) * (1.0 + float(m.stats["armor"]))
	if fire >= sense * 3.0 and fire >= tough * 0.22:
		return "输出"
	if sense * 3.0 > fire and sense >= tough * 0.5:
		return "侦察"
	if tough > fire * 4.0:
		return "防御"
	return "均衡"


func _draw_status(vs: Vector2) -> void:
	var x := vs.x - 300.0
	_txt(Vector2(x, 34), "第 %d 段战线" % battle.act, 15, COL_DIM)
	var p: int = battle.pressure
	_txt(Vector2(x, 58), "压力", 13, COL_DIM)
	_bar(Rect2(x + 44, 48, 200, 7), float(p) / 100.0,
		COL_WARN if p > 60 else Color(0.55, 0.75, 1.0))
	_txt_r(Vector2(vs.x - 24, 58), "%d" % p, 13, COL_TEXT)
	# 指令点
	_txt(Vector2(x, 88), "指令点", 13, COL_DIM)
	_bar(Rect2(x + 44, 78, 200, 7), battle.cp / 10.0, COL_GOLD)
	_txt_r(Vector2(vs.x - 24, 88), "%d / 10" % int(battle.cp), 13, COL_TEXT)
	# 时间与状态
	var mm := int(battle.elapsed) / 60
	var ss := int(battle.elapsed) % 60
	_txt(Vector2(x, 112), "作战时间 %02d:%02d" % [mm, ss], 13, COL_DIM)
	if battle.paused:
		_txt_r(Vector2(vs.x - 24, 112), "暂停", 13, COL_GOLD)
	# 脑髓
	_txt(Vector2(x, 134), "回收 %d   丢失 %d" % [battle.brains_saved, battle.brains_lost], 13,
		Color(0.5, 0.95, 0.75) if battle.brains_lost == 0 else COL_WARN)
	_txt(Vector2(x, 156), "%d FPS  ·  %d 军团" % [Engine.get_frames_per_second(), battle.legion_alive()], 11,
		Color(0.32, 0.42, 0.52))


func _draw_waves(vs: Vector2) -> void:
	var x := 24.0
	var y := vs.y - 150.0
	canvas.draw_rect(Rect2(x - 10, y - 18, 300, 140), Color(0.02, 0.04, 0.06, 0.7))
	for m in battle.mechs:
		var name: String = m.pilot.get("callsign", "?")
		var alive: bool = not m.dead
		var col := Color(0.55, 0.95, 1.0, 0.9) if alive else Color(0.35, 0.2, 0.2, 0.8)
		_txt(Vector2(x, y), name.substr(0, 12), 11, col if alive else COL_WARN)
		# 波形
		var wx := x + 92.0
		var ww := 170.0
		var pts := PackedVector2Array()
		for i in range(24):
			var fx := float(i) / 23.0
			var amp: float = (1.2 + 2.6 * m.hp_frac()) if alive else 0.4
			var v: float = sin(t * 9.0 + i * 0.9 + m.get_instance_id() % 7) * amp
			if alive and m.hp_frac() < 0.35:
				v += sin(t * 23.0 + i) * 2.0
			if not alive:
				v = randf_range(-1.0, 1.0) * 2.6
			pts.append(Vector2(wx + fx * ww, y - 4.0 + v))
		if pts.size() > 1:
			canvas.draw_polyline(pts, col, 1.2)
		if not alive:
			canvas.draw_line(Vector2(wx, y - 4), Vector2(wx + ww, y - 4), Color(0.6, 0.25, 0.2, 0.5), 1.0)
		y += 19.0


func _draw_cards(vs: Vector2) -> void:
	var deck: Array = battle.card_ids()
	if deck.is_empty():
		_txt(Vector2(vs.x - 24, vs.y - 40), "（还没有卡牌 —— 去废墟里找）", 13, COL_DIM)
		return
	var n := deck.size()
	var cw := 156.0
	var ch := 62.0
	var gap := 8.0
	var total: float = n * cw + (n - 1) * gap
	var x: float = vs.x - 24.0 - total
	var y: float = vs.y - ch - 56.0
	for i in range(n):
		var cid: String = deck[i]
		var c: Dictionary = GameData.CARDS[cid]
		var r := Rect2(x + i * (cw + gap), y, cw, ch)
		var used: bool = cid in battle.used_cards
		var afford: bool = battle.cp >= float(c["cost"]) and not used
		var bg := Color(0.04, 0.07, 0.10, 0.9) if afford else Color(0.03, 0.04, 0.05, 0.9)
		canvas.draw_rect(r, bg)
		var edge := COL_GOLD if afford else Color(0.18, 0.2, 0.24, 0.9)
		canvas.draw_rect(r, edge, false, 1.2)
		_txt(Vector2(r.position.x + 8, r.position.y + 18), "F%d" % (i + 1), 10, COL_DIM)
		_txt(Vector2(r.position.x + 30, r.position.y + 19), String(c["name"]), 14,
			COL_TEXT if afford else COL_DIM)
		_txt_r(Vector2(r.position.x + cw - 8, r.position.y + 19), "%d" % int(c["cost"]), 13,
			COL_GOLD if afford else COL_DIM)
		var tag: String = c.get("tag", "")
		if used:
			tag = "已用"
		_txt(Vector2(r.position.x + 8, r.position.y + 36), tag, 10, COL_DIM)
		var desc: String = c["text"]
		canvas.draw_string(font, Vector2(r.position.x + 8, r.position.y + 52), desc.substr(0, 13),
			HORIZONTAL_ALIGNMENT_LEFT, cw - 16, 10, COL_DIM)
		if not afford:
			canvas.draw_rect(r, Color(0, 0, 0, 0.42))


func _draw_hint(vs: Vector2) -> void:
	if battle.hint_text == "":
		return
	var s: String = battle.hint_text
	var w: float = 20.0 + s.length() * 16.0
	canvas.draw_rect(Rect2(vs.x * 0.5 - w * 0.5, 116, w, 32), Color(0.02, 0.05, 0.08, 0.85))
	_txt(Vector2(vs.x * 0.5 - w * 0.5 + 10, 138), s, 15, COL_GOLD)


func _draw_footer(vs: Vector2) -> void:
	var s := "左键 选编队/集火/前进    右键 点亮迷雾    Q 姿态   E 规则   R 收容   空格 暂停   滚轮 缩放"
	_txt(Vector2(340, vs.y - 18), s, 12, COL_DIM)
