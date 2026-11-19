extends Node2D
## 应用主控：标题 → 战役 → 战斗 → 战役 → ……

var campaign: CampaignScreen
var battle: BattleScene
var title_layer: Control
var fade: ColorRect
var font: Font
var fx: ScreenFX


func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "PingFang SC", "sans-serif"])
	if not ("windowed" in OS.get_cmdline_user_args()):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	G.new_run()
	fx = ScreenFX.new()
	add_child(fx)
	fx.add_to_group("fx")
	if "test" in OS.get_cmdline_user_args():
		_run_test()
		return
	if "shot" in OS.get_cmdline_user_args():
		_run_shot()
		return
	if "flow" in OS.get_cmdline_user_args():
		_run_flow()
		return
	if "perf" in OS.get_cmdline_user_args():
		_run_perf()
		return
	_show_title()


func _run_perf() -> void:
	print("[PERF] start")
	_start_campaign()
	await get_tree().process_frame
	_on_request_battle("anvil")
	await get_tree().process_frame
	if battle == null:
		print("[PERF] no battle")
		get_tree().quit()
		return
	var samples: Array = []
	for i in range(12):
		await get_tree().create_timer(1.0).timeout
		if battle == null:
			break
		var f: int = Engine.get_frames_per_second()
		samples.append(f)
		print("[PERF] t=", snapped(battle.elapsed, 0.1),
			" fps=", f, " legions=", battle.legion_alive(),
			" objs=", battle.legions.size(), " mechs=", battle.mechs.size())
	var mn := 999
	var sum := 0
	for f in samples:
		mn = min(mn, f)
		sum += f
	print("[PERF] min=", mn, " avg=", int(sum / max(1, samples.size())))
	get_tree().quit()


func _run_flow() -> void:
	print("[FLOW] start")
	G.new_run()
	_start_campaign()
	var guard := 0
	while guard < 60:
		guard += 1
		if campaign == null:
			break
		if campaign.mode == "end":
			print("[FLOW] END run_over=", campaign.run_over)
			break
		if battle != null:
			print("[FLOW] battle ", battle.enc_id, " → 模拟胜利")
			battle.queue_free()
			battle = null
			campaign.visible = true
			campaign.on_battle_finished({"win": true, "lost": 0, "brains_saved": 0, "brains_lost": 0, "time": 1.0})
		elif campaign.mode == "map":
			var av: Array = campaign.available_nodes()
			if av.is_empty():
				print("[FLOW] no available nodes")
				break
			print("[FLOW] enter ", av[0], " deck=", G.deck.size(),
				"squads=", G.run_squads.size(), " mechs=", G.total_mechs())
			campaign._enter_node(av[0])
		elif campaign.mode == "choice":
			print("[FLOW] choice: ", campaign.choice_title, " n=", campaign.choices.size())
			campaign._pick_choice(0)
		await get_tree().process_frame
	print("[FLOW] sfx_played=", Audio.play_count)
	print("[FLOW] done node=", G.node_id, " deck=", G.deck.size(),
		" squads=", G.run_squads.size(), " mechs=", G.total_mechs(),
		" pressure=", G.pressure)
	get_tree().quit()


func _run_test() -> void:
	print("[TEST] start")
	_start_campaign()
	await get_tree().process_frame
	_on_request_battle("skirmish")
	await get_tree().process_frame
	if battle == null:
		print("[TEST] battle null!")
		get_tree().quit()
		return
	print("[TEST] battle started, waves=", battle.waves.size(), " mechs=", battle.mechs.size())
	# 移动指令验收：点一个 300px 外的点，看它是否走到并停下
	var move_from: Vector2 = battle.squads[0].center
	var move_to: Vector2 = move_from + Vector2(300, 0)
	battle._issue_order(battle.squads[0], {"cmd": "move", "pos": move_to})
	print("[MOVE] from=", move_from, " to=", move_to)
	for i in range(1200):
		battle.shadow_update(1.0 / 30.0)
		if battle == null:
			break
		if i % 30 == 0 and battle != null and i < 200:
			print("[MOVE] t=", snapped(battle.elapsed, 0.1),
				" dist=", snapped(battle.squads[0].center.distance_to(move_to), 1.0),
				" has_dest=", battle.squads[0].has_dest)
		if i % 150 == 0 and battle != null:
			var l0 = battle.legions[0] if battle.legions.size() > 0 else null
			var mh := []
			for m in battle.mechs:
				mh.append(snapped(m.hp, 0.1))
			print("[TEST] t=", snapped(battle.elapsed, 0.1),
				" legions=", battle.legions.size(),
				" alive_m=", _alive_mechs(),
				" mech_hp=", mh,
				" L0={hp:", snapped(l0.hp, 0.1) if l0 != null else -1,
				" d:", snapped(l0.position.distance_to(battle.squads[0].center), 1.0) if l0 != null else -1.0,
				" dead:", l0.dead if l0 != null else false, "}")
	if battle != null:
		print("[TEST] final: squads=", battle.squads.size(),
			" mechs=", battle.mechs.size(),
			" legions=", battle.legions.size(),
			" elapsed=", snapped(battle.elapsed, 0.1),
			" state=", battle.state)
		for sq in battle.squads:
			print("  squad ", sq.label, " alive=", sq.size_alive(),
				" integ=", snapped(sq.integrity, 0.1), " exec=", snapped(sq.exec_rate(), 1.0),
				" stance=", sq.stance)
	else:
		print("[TEST] battle 已结算")
	print("[TEST] done")
	get_tree().quit()


func _alive_mechs() -> int:
	if battle == null:
		return -1
	var n := 0
	for m in battle.mechs:
		if not m.dead:
			n += 1
	return n


# ---------------- 截图 ----------------
func _save_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/" + name + ".png")
	print("[SHOT] ", name)


func _run_shot() -> void:
	print("[SHOT] start")
	Engine.time_scale = 5.0
	# 1. 标题
	_show_title()
	for i in range(6):
		await get_tree().process_frame
	await _save_shot("01_title")
	_clear_world()
	# 2. 战役地图
	_start_campaign()
	for i in range(10):
		await get_tree().process_frame
	await _save_shot("02_campaign")
	# 3. 战斗
	campaign.visible = false
	_on_request_battle("pincer")
	for i in range(4):
		await get_tree().process_frame
	if battle != null:
		_advance_to(2.0)
		await _wait_battle_t(2.0)
		await _save_shot("03_battle_early")
		await _wait_battle_t(14.0)
		await _save_shot("04_battle_mid")
		await _wait_battle_t(26.0)
		await _save_shot("05_battle_late")
		battle.cam.zoom = Vector2(3.2, 3.2)
		battle.cam.position = battle.squads[0].center
		for i in range(5):
			await get_tree().process_frame
		await _save_shot("06_zoom_in")
		battle.cam.zoom = Vector2(0.5, 0.5)
		for i in range(5):
			await get_tree().process_frame
		await _save_shot("07_zoom_out")
	print("[SHOT] done")
	get_tree().quit()


func _advance_to(t: float) -> void:
	pass


func _wait_battle_t(t: float) -> void:
	var guard := 0
	while battle != null and battle.elapsed < t and battle.state == "fight" and guard < 1500:
		guard += 1
		await get_tree().process_frame
	for i in range(3):
		await get_tree().process_frame


func _clear_world() -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	if campaign != null:
		campaign.queue_free()
		campaign = null
	if title_layer != null:
		title_layer.queue_free()
		title_layer = null


func _show_title() -> void:
	_clear_world()
	var t := Control.new()
	t.size = get_viewport_rect().size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.draw.connect(_draw_title.bind(t))
	add_child(t)
	title_layer = t


func _draw_title(c: Control) -> void:
	var vs := c.size
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.006, 0.011, 0.02))
	# 背景网格
	var s := 72.0
	var off := fmod(Time.get_ticks_msec() * 0.008, s)
	var col := Color(0.05, 0.1, 0.16, 0.25)
	var x := off
	while x < vs.x:
		c.draw_line(Vector2(x, 0), Vector2(x, vs.y), col, 1.0)
		x += s
	var y := off * 0.5
	while y < vs.y:
		c.draw_line(Vector2(0, y), Vector2(vs.x, y), col, 1.0)
		y += s
	# 标题
	var cx := vs.x * 0.5
	c.draw_string(font, Vector2(cx - 240, vs.y * 0.38), "HANDLER", HORIZONTAL_ALIGNMENT_CENTER,
		480, 76, Color(0.82, 0.95, 1.0))
	c.draw_string(font, Vector2(cx - 240, vs.y * 0.38 + 38), "你只能下令，不能操作他们。",
		HORIZONTAL_ALIGNMENT_CENTER, 480, 18, Color(0.45, 0.6, 0.72))
	# 脉冲动画
	var r := 40.0 + sin(Time.get_ticks_msec() * 0.003) * 10.0
	c.draw_arc(Vector2(cx, vs.y * 0.38 - 26), r, 0, TAU, 48, Color(0.3, 0.8, 1.0, 0.25), 2.0)
	c.draw_string(font, Vector2(cx - 240, vs.y * 0.72), "按 Enter 开始作战",
		HORIZONTAL_ALIGNMENT_CENTER, 480, 20, Color(1.0, 0.85, 0.35, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)))
	c.draw_string(font, Vector2(cx - 300, vs.y - 60),
		"WASD 移动镜头 · 滚轮 缩放 · 左键 下令 · 右键 点亮迷雾 · Q/E 姿态与规则 · F1-F9 卡牌",
		HORIZONTAL_ALIGNMENT_CENTER, 600, 12, Color(0.35, 0.45, 0.55))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var m := DisplayServer.window_get_mode()
			if m == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if battle == null and (campaign == null or campaign.mode == "map"):
				_start_campaign()


func _start_campaign() -> void:
	var a = get_node_or_null("/root/Audio")
	if a != null:
		a.play("sfx_radio_open", -3.0)
	_clear_world()
	campaign = CampaignScreen.new()
	add_child(campaign)
	campaign.request_battle.connect(_on_request_battle)
	campaign.run_finished.connect(_on_run_finished)


func _on_request_battle(enc_id: String) -> void:
	if campaign != null:
		campaign.visible = false
	battle = BattleScene.new()
	add_child(battle)
	battle.enc_id = enc_id
	var ed: Dictionary = GameData.ENCOUNTERS[enc_id]
	battle.encounter = ed
	battle.waves = ed["waves"]
	battle.act = G.act
	battle.pressure = G.pressure
	battle.battle_finished.connect(_on_battle_finished)
	battle.begin()


func _on_battle_finished(res: Dictionary) -> void:
	if battle != null:
		battle.queue_free()
		battle = null
	if campaign != null:
		campaign.visible = true
		campaign.on_battle_finished(res)
		if campaign.mode == "end":
			campaign.run_finished.emit(false)


func _on_run_finished(won: bool) -> void:
	pass
