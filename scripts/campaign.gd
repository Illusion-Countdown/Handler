class_name CampaignScreen
extends Control
## 战役地图 / 探索 / 休整 / 战后结算。固定流程，可选分支。

signal request_battle(enc_id: String)
signal run_finished(won: bool)

const NODE_POS := {
	"n1": Vector2(0.50, 0.92), "n2": Vector2(0.50, 0.82),
	"n3": Vector2(0.29, 0.70), "n3b": Vector2(0.71, 0.70),
	"n4": Vector2(0.50, 0.58), "n5": Vector2(0.50, 0.46),
	"n6": Vector2(0.29, 0.34), "n6b": Vector2(0.71, 0.34),
	"n7": Vector2(0.50, 0.22), "n8": Vector2(0.50, 0.10),
}

var font: Font
var t: float = 0.0
var mode: String = "map"          # map / choice / end
var choices: Array = []
var choice_title: String = ""
var choice_body: String = ""
var flash_msg: String = ""
var flash_t: float = 0.0
var last_result: Dictionary = {}
var run_over: bool = false
var run_won: bool = false
var pending_enc: String = ""


func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "PingFang SC", "sans-serif"])
	mode = "map"
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_on_resize)


func _on_resize() -> void:
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	t += delta
	if flash_t > 0.0:
		flash_t -= delta
	queue_redraw()


func available_nodes() -> Array:
	if G.node_id == "start":
		return ["n1"]
	var cur := G.node_def(G.node_id)
	if cur.is_empty():
		return []
	return cur.get("next", [])


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := get_local_mouse_position()
		if mode == "map":
			for id in available_nodes():
				if mp.distance_to(_node_pos(id)) < 34.0:
					_enter_node(id)
					return
		elif mode == "choice":
			for i in range(choices.size()):
				if _choice_rect(i).has_point(mp):
					_pick_choice(i)
					return
		elif mode == "end":
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if mode == "end":
				get_tree().quit()
			elif mode == "map":
				var av := available_nodes()
				if av.size() > 0:
					_enter_node(av[0])
		elif mode == "choice":
			var n: int = event.keycode - KEY_1
			if n >= 0 and n < choices.size():
				_pick_choice(n)


func _node_pos(id: String) -> Vector2:
	if id == "start":
		return Vector2(0.5 * size.x, 0.99 * size.y)
	var f: Vector2 = NODE_POS.get(id, Vector2(0.5, 0.5))
	return Vector2(f.x * size.x, f.y * size.y)


func _enter_node(id: String) -> void:
	var n := G.node_def(id)
	if n.is_empty():
		return
	G.node_id = id
	G.act = int(n.get("act", G.act))
	_ui_sound("sfx_ui")
	var ty: String = n.get("type", "battle")
	match ty:
		"battle", "boss":
			request_battle.emit(String(n["enc"]))
		"explore":
			_open_explore(n)
		"rest":
			_open_rest(n)


# ---------------- 地图 ----------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.014, 0.026))
	_draw_bg_grid()
	if mode == "map":
		_draw_map()
	elif mode == "choice":
		_draw_choice()
	elif mode == "end":
		_draw_end()
	_draw_header()
	if flash_t > 0.0:
		draw_string(font, Vector2(size.x * 0.5 - 220, size.y - 60), flash_msg,
			HORIZONTAL_ALIGNMENT_LEFT, 440, 16, Color(1.0, 0.82, 0.35, min(1.0, flash_t)))


func _draw_bg_grid() -> void:
	var s := 64.0
	var col := Color(0.05, 0.1, 0.16, 0.22)
	var x := fmod(t * 4.0, s)
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
		x += s
	var y := fmod(t * 2.0, s)
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
		y += s


func _draw_map() -> void:
	var cur_id := G.node_id
	var avail := available_nodes()
	for id in avail:
		_dashed(_node_pos(cur_id), _node_pos(id), Color(0.3, 0.8, 1.0, 0.45), 2.0)
	for n in GameData.CAMPAIGN:
		var id: String = n["id"]
		var p := _node_pos(id)
		var done := _is_past(id)
		var is_cur := id == cur_id
		var is_av := id in avail
		var col := Color(0.22, 0.3, 0.38, 0.5)
		if done:
			col = Color(0.3, 0.5, 0.6, 0.55)
		if is_av:
			col = Color(0.45, 0.9, 1.0, 1.0)
		if is_cur:
			col = Color(1.0, 0.85, 0.35, 1.0)
		_diamond(p, 18.0 if is_av else 14.0, col)
		var icon: String = {"battle": "▲", "boss": "✖", "explore": "◆", "rest": "■"}.get(n["type"], "·")
		draw_string(font, p + Vector2(-6, 6), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.05, 0.08, 0.1, 0.95) if is_av else col)
		draw_string(font, p + Vector2(-40, 36), String(n["name"]), HORIZONTAL_ALIGNMENT_CENTER, 80, 12,
			col if (is_av or is_cur) else Color(0.3, 0.38, 0.45, 0.7))
		if is_cur:
			var r := 26.0 + sin(t * 3.0) * 3.0
			draw_arc(p, r, 0.0, TAU, 32, Color(1.0, 0.85, 0.35, 0.5), 1.6)
		if is_av:
			var r2 := 24.0 + sin(t * 4.0) * 2.0
			draw_arc(p, r2, 0.0, TAU, 32, Color(0.45, 0.9, 1.0, 0.35), 1.2)
			if get_local_mouse_position().distance_to(p) < 34.0:
				_draw_brief(n, p)
	draw_string(font, Vector2(40, size.y - 34), "点击发光的节点推进。Enter 走推荐路线。",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.58, 0.7, 0.8))


func _draw_brief(n: Dictionary, p: Vector2) -> void:
	var txt: String = String(n.get("brief", ""))
	var w := 420.0
	var r := Rect2(p.x + 40, p.y - 40, w, 76)
	if r.position.x + w > size.x - 20:
		r.position.x = p.x - w - 40
	draw_rect(r, Color(0.02, 0.05, 0.08, 0.94))
	draw_rect(r, Color(0.35, 0.8, 1.0, 0.5), false, 1.2)
	draw_string(font, r.position + Vector2(14, 26), "%s · %s" % [n["name"], _type_name(n["type"])],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.94, 1.0))
	draw_string(font, r.position + Vector2(14, 50), txt, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 12,
		Color(0.6, 0.72, 0.82))


func _type_name(t: String) -> String:
	return {"battle": "遭遇战", "boss": "决战", "explore": "探索", "rest": "休整"}.get(t, t)


func _is_past(id: String) -> bool:
	var order := ["n1", "n2", "n3", "n3b", "n4", "n5", "n6", "n6b", "n7", "n8"]
	var ai := order.find(id)
	var ci := order.find(G.node_id)
	return ai >= 0 and ci >= 0 and ai < ci


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := a.distance_to(b)
	var n := int(d / 14.0)
	for i in range(n):
		if i % 2 == 1:
			continue
		var p0 := a.lerp(b, float(i) / float(max(1, n)))
		var p1 := a.lerp(b, float(i + 1) / float(max(1, n)))
		draw_line(p0, p1, col, w)


func _diamond(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	draw_colored_polygon(pts, Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.9))
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, col, 1.8)


# ---------------- 选择 ----------------
func _open_explore(n: Dictionary) -> void:
	mode = "choice"
	choice_title = "%s · 探索" % n["name"]
	choice_body = "废墟的轮廓在雷达上只是一块空白。你要花多少时间？"
	choices = [
		{"t": "深入搜索", "d": "压力 +14，必定拿到 2 张卡牌", "act": "deep"},
		{"t": "谨慎搜刮", "d": "压力 +6，拿到 1 张卡牌 + 补给", "act": "careful"},
		{"t": "直接通过", "d": "压力 +2，什么都拿不到", "act": "skip"},
	]


func _open_rest(n: Dictionary) -> void:
	mode = "choice"
	choice_title = "%s · 休整" % n["name"]
	choice_body = "后方。灯是亮的，但没人说话。"
	choices = [
		{"t": "整备", "d": "压力 -20，全队信任 +4", "act": "repair"},
		{"t": "招募", "d": "加入一名普通机师", "act": "recruit"},
	]
	if G.run_squads.size() < 3 and G.total_mechs() >= 3:
		choices.append({"t": "重组编队", "d": "把一个编队拆成两支", "act": "split"})


func _pick_choice(i: int) -> void:
	var c: Dictionary = choices[i]
	_ui_sound("sfx_confirm")
	var act: String = c.get("act", "")
	match act:
		"deep":
			G.pressure += 14
			var got := []
			for k in range(2):
				var cid := _random_new_card()
				if cid != "":
					G.deck.append(cid)
					got.append(GameData.CARDS[cid]["name"])
			if got.is_empty():
				G.fragments += 2
				_flash("牌库已满，获得 2 枚碎片")
			else:
				_flash("回收：%s" % "、".join(got))
		"careful":
			G.pressure += 6
			var cid2 := _random_new_card()
			if cid2 != "":
				G.deck.append(cid2)
				_flash("回收：%s" % GameData.CARDS[cid2]["name"])
			else:
				G.fragments += 2
				_flash("获得 2 枚碎片")
		"skip":
			G.pressure += 2
			_flash("你从废墟旁边绕了过去。")
		"repair":
			G.pressure = max(0, G.pressure - 20)
			for p in G.all_pilots():
				p["trust"] = min(100.0, float(p["trust"]) + 4.0)
			_flash("整备完成。压力 -20，全队信任 +4")
		"recruit":
			if G.total_mechs() >= 10:
				_flash("名册已满")
			else:
				var np := G.make_generic()
				G.add_pilot(np)
				_flash("加入：%s（%s）" % [np["callsign"], GameData.CONFIGS[np["config"]]["name"]])
		"loot":
			G.pressure += 4
			var g2 := []
			for k in range(2):
				var c3 := _random_new_card()
				if c3 != "":
					G.deck.append(c3)
					g2.append(GameData.CARDS[c3]["name"])
			if g2.is_empty():
				G.fragments += 2
				_flash("牌库已满，+2 碎片")
			else:
				_flash("回收资料：%s" % "、".join(g2))
		"split":
			_split_squad()
	advance()


func _split_squad() -> void:
	if G.run_squads.size() >= 3:
		_flash("编队数量已达上限")
		return
	var target: Dictionary = G.run_squads[0]
	for s in G.run_squads:
		if s["members"].size() > target["members"].size():
			target = s
	if target["members"].size() < 2:
		_flash("人不够，拆不出第二队")
		return
	var moved: Array = []
	var half: int = int(target["members"].size() / 2)
	for i in range(half):
		moved.append(target["members"].pop_back())
	G.run_squads.append({"members": moved})
	_flash("拆分完成：%d 个编队" % G.run_squads.size())


func advance() -> void:
	choices = []
	if available_nodes().is_empty():
		run_won = true
		run_over = false
		mode = "end"
		return
	mode = "map"


func _random_new_card() -> String:
	var pool := []
	for cid in GameData.CARD_IDS:
		if not (cid in G.deck):
			pool.append(cid)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


func _choice_rect(i: int) -> Rect2:
	var w := 560.0
	var h := 92.0
	var total: float = choices.size() * (h + 14.0)
	var y0: float = (size.y - total) * 0.5 + 40.0
	return Rect2(size.x * 0.5 - w * 0.5, y0 + i * (h + 14.0), w, h)


func _draw_choice() -> void:
	draw_string(font, Vector2(size.x * 0.5 - 260, size.y * 0.5 - 120), choice_title,
		HORIZONTAL_ALIGNMENT_CENTER, 520, 26, Color(0.85, 0.94, 1.0))
	draw_string(font, Vector2(size.x * 0.5 - 260, size.y * 0.5 - 88), choice_body,
		HORIZONTAL_ALIGNMENT_CENTER, 520, 14, Color(0.55, 0.68, 0.8))
	for i in range(choices.size()):
		var r := _choice_rect(i)
		var hover := r.has_point(get_local_mouse_position())
		draw_rect(r, Color(0.03, 0.06, 0.09, 0.95))
		draw_rect(r, Color(1.0, 0.85, 0.35, 0.9) if hover else Color(0.25, 0.45, 0.58, 0.8), false, 1.6)
		var c: Dictionary = choices[i]
		draw_string(font, r.position + Vector2(18, 34), "%d. %s" % [i + 1, c["t"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.96, 1.0))
		draw_string(font, r.position + Vector2(18, 62), String(c["d"]),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 13, Color(0.55, 0.68, 0.8))


# ---------------- 头部 ----------------
func _draw_header() -> void:
	draw_string(font, Vector2(40, 48), "HANDLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Color(0.75, 0.92, 1.0))
	draw_string(font, Vector2(40, 72), "第 %d 段战线" % G.act, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.45, 0.58, 0.7))
	var x := size.x - 420.0
	var items := [
		["压力", "%d" % G.pressure],
		["编队", "%d" % G.run_squads.size()],
		["机体", "%d" % G.total_mechs()],
		["卡牌", "%d" % G.deck.size()],
		["回收", "%d" % G.brains_saved],
	]
	for i in range(items.size()):
		var p := Vector2(x + i * 84.0, 48)
		draw_string(font, p, items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.52, 0.64))
		draw_string(font, p + Vector2(0, 22), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
			Color(0.85, 0.94, 1.0))
	draw_rect(Rect2(x, 82, 400, 3), Color(0.1, 0.14, 0.2))
	draw_rect(Rect2(x, 82, 400.0 * clamp(G.pressure / 100.0, 0, 1), 3),
		Color(1.0, 0.42, 0.28) if G.pressure > 55 else Color(0.4, 0.75, 1.0))


# ---------------- 战后 ----------------
func on_battle_finished(res: Dictionary) -> void:
	last_result = res
	if not res["win"]:
		run_over = true
		run_won = false
		mode = "end"
		return
	var lost := int(res.get("lost", 0))
	if lost > 0:
		_remove_dead()
	if G.run_squads.is_empty():
		run_over = true
		run_won = false
		mode = "end"
		return
	G.fragments += 1
	_open_reward(lost)


func _remove_dead() -> void:
	for sq in G.run_squads:
		var keep := []
		for m in sq["members"]:
			if not bool(m.get("memorial", false)):
				keep.append(m)
		sq["members"] = keep
	var clean := []
	for sq in G.run_squads:
		if sq["members"].size() > 0:
			clean.append(sq)
	G.run_squads = clean


func _open_reward(lost: int) -> void:
	mode = "choice"
	choice_title = "战后"
	choice_body = "本场损失 %d 台。你有一次选择。" % lost
	choices = [
		{"t": "补充机体", "d": "招募一名普通机师", "act": "recruit"},
		{"t": "整备", "d": "压力 -14，全队信任 +3", "act": "repair"},
		{"t": "回收资料", "d": "从残骸里捞出 2 张卡牌", "act": "loot"},
	]
	if G.run_squads.size() < 3 and G.total_mechs() >= 3:
		choices.append({"t": "重组编队", "d": "把一个编队拆成两支", "act": "split"})


func _ui_sound(n: String) -> void:
	var a = get_node_or_null("/root/Audio")
	if a != null:
		a.play(n, -4.0)


func _flash(s: String) -> void:
	flash_msg = s
	flash_t = 2.6
	G.add_log(s)


func _draw_end() -> void:
	var txt := "全灭" if not run_won else "战役完成"
	draw_string(font, Vector2(size.x * 0.5 - 200, size.y * 0.4), txt,
		HORIZONTAL_ALIGNMENT_CENTER, 400, 44, Color(1.0, 0.45, 0.32))
	var lines := [
		"推进到：%s" % G.node_def(G.node_id).get("name", "—"),
		"击破军团：%d 台" % G.total_kills,
		"回收脑髓：%d" % G.brains_saved,
		"丢失脑髓：%d" % G.brains_lost,
		"",
		"按 Enter 结束",
	]
	var y := size.y * 0.4 + 60
	for l in lines:
		draw_string(font, Vector2(size.x * 0.5 - 200, y), l, HORIZONTAL_ALIGNMENT_CENTER, 400, 16,
			Color(0.7, 0.82, 0.9))
		y += 30
