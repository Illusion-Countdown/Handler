class_name BattleScene
extends Node2D
## 一场遭遇。玩家不操作机甲，只下令与提供情报。

signal battle_finished(result: Dictionary)

const DEPLOY_RADIUS := 120.0

var world_size: Vector2
var mechs: Array = []
var legions: Array = []
var squads: Array = []
var fog: FogOfWar
var cam: Camera2D
var hud
var vfx
var units_layer: Node2D
var overlay: Node2D
var world_layer: Node2D

var encounter: Dictionary = {}
var enc_id: String = ""
var waves: Array = []
var wave_idx: int = 0
var wave_t: float = 0.0
var all_spawned: bool = false
var t: float = 0.0
var paused: bool = false
var speed: float = 1.0
var cp: float = 6.0
var cp_t: float = 0.0
var state: String = "fight"
var selected: Squad = null
var pressure: int = 0
var brains_saved: int = 0
var brains_lost: int = 0
var deaths: Array = []
var recoveries: Array = []
var echoes: Array = []
var shake: float = 0.0
var terrain: Array = []
var rng := RandomNumberGenerator.new()
var priority_channel: bool = false
var thermal_t: float = 0.0
var jam_center: Vector2 = Vector2.ZERO
var jam_t: float = 0.0
var hint_text: String = ""
var hint_t: float = 0.0
var elapsed: float = 0.0
var time_limit: float = 0.0
var result_sent: bool = false
var act: int = 1
var used_cards: Array = []


func _ready() -> void:
	world_size = Vector2(GameData.GRID_W, GameData.GRID_H) * GameData.CELL
	rng.randomize()
	_build_layers()
	_build_terrain()
	_build_squads()
	_build_fog()
	_build_camera()
	vfx = preload("res://scripts/vfx.gd").new()
	overlay.add_child(vfx)
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.battle = self
	set_process(true)


func begin() -> void:
	if waves.size() > 0:
		_spawn_wave(0)
	wave_idx = 1
	wave_t = 0.0


func _build_layers() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.35
	env.glow_strength = 1.15
	env.glow_bloom = 0.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.55
	env.glow_hdr_scale = 2.2
	env.glow_bloom = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	world_layer = Node2D.new()
	world_layer.z_index = -10
	add_child(world_layer)
	world_layer.draw.connect(_draw_world)
	units_layer = Node2D.new()
	units_layer.z_index = 0
	add_child(units_layer)
	overlay = Node2D.new()
	overlay.z_index = 20
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)


func _build_terrain() -> void:
	terrain.clear()
	var types := ["urban", "mountain", "plain", "ruin"]
	for i in range(44):
		var r := Rect2(
			rng.randf_range(0.0, world_size.x - 220.0),
			rng.randf_range(0.0, world_size.y - 220.0),
			rng.randf_range(90.0, 260.0),
			rng.randf_range(70.0, 200.0))
		var tp: String = types[rng.randi() % types.size()]
		if i < 3:
			tp = "plain"
		terrain.append({"rect": r, "type": tp})


func _build_fog() -> void:
	fog = FogOfWar.new()
	fog.setup(world_size)
	fog.z_index = 10
	add_child(fog)


func _build_camera() -> void:
	cam = Camera2D.new()
	cam.position = world_size * 0.5
	cam.zoom = Vector2(1.9, 1.9)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(world_size.x)
	cam.limit_bottom = int(world_size.y)
	add_child(cam)
	cam.make_current()


func _build_squads() -> void:
	var idx := 0
	for sdata in G.run_squads:
		var sq := Squad.new()
		sq.battle = self
		sq.index = idx
		sq.label = ["中央", "左翼", "右翼"][min(idx, 2)]
		sq.center = Vector2(world_size.x * 0.5 + (idx - 1) * 70.0, world_size.y * 0.5)
		sq.dest = sq.center
		squads.append(sq)
		idx += 1
	# 注意力均分
	var n: int = max(1, squads.size())
	for sq in squads:
		sq.attention = 1.0 / float(n)
	# 生成机体
	var si := 0
	for sdata in G.run_squads:
		var sq: Squad = squads[si]
		var k := 0
		for m in sdata["members"]:
			var mech := MechUnit.new()
			var c := _pick_config(m)
			mech.setup(c, m, sq.center + Vector2(k * 22.0 - 22.0, 0))
			units_layer.add_child(mech)
			sq.add(mech)
			mechs.append(mech)
			k += 1
		si += 1
	selected = squads[0] if squads.size() > 0 else null


func _pick_config(m: Dictionary) -> String:
	if m.has("config") and m["config"] != "":
		return m["config"]
	return GameData.CONFIG_IDS[rng.randi() % GameData.CONFIG_IDS.size()]


func map_center() -> Vector2:
	return world_size * 0.5


func squad_count() -> int:
	return squads.size()


func legion_alive() -> int:
	var n := 0
	for e in legions:
		if not e.dead:
			n += 1
	return n


# ---------------- 波次 ----------------
func _spawn_wave(i: int) -> void:
	if i >= waves.size():
		all_spawned = true
		return
	var w: Dictionary = waves[i]
	var count := int(w["count"])
	var bearings: Array = w.get("bearings", [0.0])
	var center := map_center()
	var radius: float = min(world_size.x, world_size.y) * 0.40
	if wave_idx < 3:
		_sfx("sfx_wave", 0.6, -6.0)
		if String(w["type"]) == "armored" or String(w["type"]) == "shepherd":
			_sfx("sfx_alarm", 0.6, -6.0)
	for k in range(count):
		var b: float = float(bearings[k % bearings.size()])
		if count > 1:
			b += rng.randf_range(-0.16, 0.16)
		var pos: Vector2 = center + Vector2.RIGHT.rotated(b) * radius
		pos.x = clamp(pos.x, 30.0, world_size.x - 30.0)
		pos.y = clamp(pos.y, 30.0, world_size.y - 30.0)
		_spawn_legion(String(w["type"]), pos)


func _spawn_legion(kind: String, pos: Vector2, hp_mult: float = 1.0) -> void:
	var e := LegionUnit.new()
	e.setup(kind, pos)
	if hp_mult != 1.0:
		e.max_hp *= hp_mult
		e.hp = e.max_hp
	units_layer.add_child(e)
	legions.append(e)


# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	if state == "over" and not result_sent:
		_over_t += delta
		if _over_t > 3.0:
			_emit_result()
	shadow_update(delta)


func shadow_update(delta: float) -> void:
	if state != "fight":
		return
	var dt := delta * speed
	if paused:
		dt = 0.0
	if dt > 0.0:
		t += dt
		elapsed += dt
		cp_t += dt
		if cp_t >= 45.0:
			cp_t -= 45.0
			cp = min(10.0, cp + 1.0)
		_update_waves(dt)
		_update_orders(dt)
		_update_squads(dt)
		_update_legions(dt)
		_update_combat(dt)
		_update_recoveries(dt)
		_update_fog(dt)
		cp = min(10.0, cp)
		if thermal_t > 0.0:
			thermal_t -= dt
		if jam_t > 0.0:
			jam_t -= dt
		if hint_t > 0.0:
			hint_t -= dt
		_check_end()
	_handle_camera(delta)
	overlay.queue_redraw()


func _update_orders(dt: float) -> void:
	for sq in squads:
		if sq.order.is_empty():
			continue
		sq.order_t -= dt
		if sq.order_t <= 0.0:
			sq.order_t = 0.0
			_apply_order(sq)
			sq.order = {}


func _apply_order(sq: Squad) -> void:
	var od: Dictionary = sq.order
	var er: float = float(od.get("exec", 0.6))
	var ok: bool = randf() < er
	match String(od.get("cmd", "")):
		"move":
			var p: Vector2 = od["pos"]
			if ok:
				sq.dest = p
			else:
				sq.dest = sq.center.lerp(p, 0.45)
				_push_hint("%s：命令执行偏差" % sq.label, 1.6)
			sq.has_dest = true
		"focus":
			var tg = od.get("target")
			if ok:
				sq.focus = tg
			elif randf() < 0.5:
				sq.focus = tg
				_push_hint("%s：听到了，但没完全听懂" % sq.label, 1.6)
			else:
				_push_hint("%s：没有回应" % sq.label, 1.6)
			# 集火命令同时转进攻
			if sq.stance == "hold":
				pass


func _update_waves(dt: float) -> void:
	if wave_idx >= waves.size():
		var alive := 0
		for e in legions:
			if not e.dead:
				alive += 1
		if alive == 0:
			all_spawned = true
		return
	wave_t += dt
	var w: Dictionary = waves[wave_idx]
	if wave_t >= float(w["delay"]):
		_spawn_wave(wave_idx)
		wave_idx += 1
		wave_t = 0.0


func _update_squads(dt: float) -> void:
	for sq in squads:
		sq.update(dt, self)


func _update_legions(dt: float) -> void:
	var target_list := []
	for m in mechs:
		if not m.dead:
			target_list.append(m)
	for e in legions:
		if e.dead:
			continue
		e.update_visual(dt)
		e.stun = max(0.0, e.stun - dt)
		if e.stun > 0.0:
			continue
		if target_list.is_empty():
			continue
		# 选目标
		if e.target == null or e.target.dead:
			e.target = _nearest_mech(e.position, target_list)
		if e.target == null:
			continue
		var to: Vector2 = e.target.position - e.position
		var d: float = to.length()
		var rng_px: float = e.atk_range_px()
		if e.kind == "recovery":
			_update_recovery_ai(e, dt)
			continue
		if d > rng_px * 0.92:
			var step: float = e.speed_px() * dt
			if step > d - rng_px * 0.9:
				step = max(0.0, d - rng_px * 0.9)
			e.position += to.normalized() * step
			e.facing = lerp_angle(e.facing, to.angle(), clamp(dt * 4.0, 0.0, 1.0))
			e.position.x = clamp(e.position.x, 24.0, world_size.x - 24.0)
			e.position.y = clamp(e.position.y, 24.0, world_size.y - 24.0)
		# 蓄力冲击波
		if e.stats.get("charge", false):
			if e.charge > 0.0:
				e.charge -= dt
				if e.charge <= 0.0:
					_shockwave(e)
			else:
				e.charge_cd -= dt
				if e.charge_cd <= 0.0 and d < 130.0:
					e.charge = 2.5
					e.charge_cd = 9.0
		# 攻击
		e.cd -= dt
		if e.cd <= 0.0 and d <= rng_px:
			e.cd = 1.0 / float(e.stats["aspd"])
			_legion_attack(e)


func _update_recovery_ai(e, dt: float) -> void:
	# 回收型：奔向最近的尸体，然后跑向地图边缘
	var goal: Vector2 = e.position
	if e.recovery_t > 0.0:
		e.recovery_t -= dt
		if e.recovery_t <= 0.0:
			# 带走，判失败
			brains_lost += 1
			_echo_of_pending()
			e.dead = true
			e.visible = false
			vfx.explosion(e.position, Color(1.0, 0.7, 0.2), 30.0)
			return
		goal = _nearest_edge(e.position)
	else:
		var corpse = _nearest_corpse(e.position)
		if corpse != null:
			var d: float = e.position.distance_to(corpse["pos"])
			if d < 26.0:
				e.recovery_t = 6.0
				_push_hint("回收型正在运输脑髓 —— 拦住它")
			else:
				goal = corpse["pos"]
		else:
			goal = _nearest_edge(e.position)
	var to: Vector2 = goal - e.position
	if to.length() > 4.0:
		e.position += to.normalized() * e.speed_px() * dt
		e.facing = to.angle()


func _nearest_corpse(p: Vector2):
	var best = null
	var bd := 1e20
	for c in recoveries:
		if c["taken"] or c["saved"]:
			continue
		var d: float = p.distance_to(c["pos"])
		if d < bd:
			bd = d
			best = c
	return best


func _nearest_edge(p: Vector2) -> Vector2:
	var pts := [
		Vector2(0, p.y), Vector2(world_size.x, p.y),
		Vector2(p.x, 0), Vector2(p.x, world_size.y)
	]
	var best: Vector2 = pts[0]
	var bd := 1e20
	for q in pts:
		var d: float = p.distance_to(q)
		if d < bd:
			bd = d
			best = q
	return best


func _echo_of_pending() -> void:
	if G.pending_echo.is_empty():
		return
	G.echoes.append(G.pending_echo)
	echoes.append(G.pending_echo)
	G.pending_echo = {}


func _nearest_mech(p: Vector2, list: Array):
	var best = null
	var bd := 1e20
	for m in list:
		var d: float = p.distance_to(m.position)
		if d < bd:
			bd = d
			best = m
	return best


func _update_combat(dt: float) -> void:
	# 我方开火
	for m in mechs:
		if m.dead:
			continue
		m.cd -= dt
		m.stagger = max(0.0, m.stagger - dt)
		m.slow = max(0.0, m.slow - dt)
		m.shield_time = max(0.0, m.shield_time - dt)
		m.overdrive = max(0.0, m.overdrive - dt)
		m.burnout = max(0.0, m.burnout - dt)
		if m.stagger > 0.0 or m.burnout > 0.0:
			continue
		var tgt = _acquire(m)
		m.target = tgt
		if tgt == null:
			continue
		var d: float = m.position.distance_to(tgt.position)
		var rng_px := float(m.stats["range"]) * GameData.CELL
		if d <= rng_px and m.cd <= 0.0:
			var aspd := float(m.stats["aspd"])
			if m.overdrive > 0.0:
				aspd *= 1.6
			if m.squad != null and m.squad.resonance > 0.0:
				aspd *= 1.25
			m.cd = 1.0 / aspd
			_mech_attack(m, tgt)
		# 朝向
		if tgt != null and d > 2.0:
			m.facing = lerp_angle(m.facing, (tgt.position - m.position).angle(), clamp(dt * 5.0, 0.0, 1.0))
		m.update_visual(dt)
	# 军团受击后清理
	for e in legions:
		if e.dead and e.visible:
			e.visible = false


func enemy_lit(e) -> bool:
	if e.revealed > 0.0:
		return true
	if thermal_t > 0.0:
		return true
	return fog.is_lit(e.position)


func _acquire(m):
	var best = null
	var bd := 1e20
	var roe: String = m.squad.roe if m.squad != null else "nearest"
	var focus = m.squad.focus if m.squad != null else null
	if focus != null and not focus.dead and m.position.distance_to(focus.position) <= float(m.stats["range"]) * GameData.CELL + 260.0:
		return focus
	for e in legions:
		if e.dead:
			continue
		var lit: bool = enemy_lit(e)
		if not lit:
			continue
		var d: float = m.position.distance_to(e.position)
		var score := d
		if roe == "dangerous":
			score = d - e.danger() * 90.0
		if score < bd:
			bd = score
			best = e
	return best


func _mech_attack(m, e) -> void:
	var dmg: float = m.base_atk()
	if m.overdrive > 0.0:
		dmg *= 1.5
	if e.marked > 0.0:
		dmg *= 1.4
	if m.squad != null and m.squad.no_retreat_t > 0.0:
		dmg *= 1.5
	# 侧后
	var rel: float = wrapf((m.position - e.position).angle() - e.facing, -PI, PI)
	if abs(rel) > deg_to_rad(120.0):
		dmg *= 1.2
	# 角色首击
	if m.pilot.get("bonus", "") == "first_shot_crit" and m.crit_ready:
		dmg *= 1.5
		m.crit_ready = false
	e.take_damage(dmg)
	m.damage_dealt += dmg
	var marked_hit: bool = e.marked > 0.0
	vfx.number(e.position + Vector2(randf_range(-8, 8), -e.size - 6), dmg,
		Color(1.0, 0.85, 0.35) if marked_hit else Color(0.8, 0.95, 1.0), marked_hit)
	if e.dead:
		m.kills += 1
		G.total_kills += 1
		vfx.explosion(e.position, Color(1.0, 0.35, 0.2), 16.0 + e.size)
		_sfx("sfx_explosion", 0.07, -4.0)
		shake = max(shake, 0.22)
	vfx.tracer(m.position, e.position, Color(0.75, 0.95, 1.0), 0.07)
	if m.cfg_id == "sniper" or m.cfg_id == "suppress":
		_sfx("sfx_rifle", 0.05, -9.0, 0.72)
	else:
		_sfx("sfx_rifle", 0.04, -9.0, 1.0)
	if m.cfg_id == "sniper":
		vfx.tracer(m.position, e.position, Color(0.9, 1.0, 1.0), 0.12)
	if m.cfg_id == "suppress":
		e.slow = max(e.slow, 3.0)


func _legion_attack(e) -> void:
	var m = e.target
	if m == null or m.dead:
		return
	e.revealed = 1.8
	var dmg: float = float(e.stats["atk"])
	var seen: bool = enemy_lit(e)
	# 偷袭：我方没人看见它
	if not seen and e.seen <= 0.0:
		dmg *= 2.0
		if m.squad != null:
			m.squad.stagger = 2.0
			m.squad.integrity -= 8.0
		vfx.flash(Color(1.0, 0.3, 0.2, 0.5), 0.12)
		_push_hint("被偷袭", 1.2)
		_fx_flash(0.30, Color(1.0, 0.2, 0.15))
		e.seen = 0.01
	# 断后承伤
	if m.squad != null and m.squad.absorb_t > 0.0:
		var guard = _guard_of(m.squad)
		if guard != null and not guard.dead:
			m = guard
			dmg *= 0.6
	m.take_damage(dmg)
	if m.squad != null:
		m.squad.on_member_hurt(dmg)
	vfx.tracer(e.position, m.position, Color(1.0, 0.4, 0.25), 0.08)
	_sfx("sfx_hit", 0.08, -11.0, 1.0)
	if m.dead:
		_on_mech_death(m)


func _guard_of(sq):
	for m in sq.alive():
		if m.cfg_id == "heavy":
			return m
	return sq.alive()[0] if sq.size_alive() > 0 else null


func _shockwave(e) -> void:
	_sfx("sfx_cannon", 0.3, -2.0, 0.9)
	_sfx("sfx_explosion_big", 0.3, -3.0)
	vfx.explosion(e.position, Color(1.0, 0.45, 0.2), 46.0)
	shake = 0.5
	for m in mechs:
		if m.dead:
			continue
		if m.position.distance_to(e.position) < 110.0:
			m.take_damage(float(e.stats["atk"]) * 1.6)
			m.stagger = 1.2
			if m.squad != null:
				m.squad.on_member_hurt(18.0)
			if m.dead:
				_on_mech_death(m)


func _on_mech_death(m) -> void:
	deaths.append(m)
	_fx_flash(0.45, Color(0.5, 0.85, 1.0))
	_sfx("sfx_death_signal", 0.4, -2.0)
	_sfx("sfx_explosion_big", 0.3, -4.0)
	vfx.explosion(m.position, Color(0.6, 0.9, 1.0), 26.0)
	shake = max(shake, 0.4)
	# 大脑回收任务
	m.pilot["memorial"] = true
	var rec := {"pos": m.position, "t": 45.0, "saved": false, "taken": false, "pilot": m.pilot}
	recoveries.append(rec)
	G.pending_echo = m.pilot.duplicate()
	_push_hint("阵亡：%s。脑髓还在，45 秒。" % m.pilot.get("callsign", "?"), 3.0)
	if m.squad != null:
		m.squad.on_member_died(m)


func _update_recoveries(dt: float) -> void:
	for c in recoveries:
		if c["saved"] or c["taken"]:
			continue
		c["t"] -= dt
		if c["t"] <= 0.0:
			c["t"] = 0.0
		# 我方靠近则抢回
		for m in mechs:
			if m.dead:
				continue
			if m.position.distance_to(c["pos"]) < 46.0:
				c["saved"] = true
				c["taken"] = true
				brains_saved += 1
				G.pending_echo = {}
				vfx.explosion(c["pos"], Color(0.4, 1.0, 0.8), 20.0)
				_push_hint("脑髓已回收", 1.6)
				break


func _update_fog(dt: float) -> void:
	fog.begin_frame()
	for m in mechs:
		if m.dead:
			continue
		fog.stamp_mech(m, dt)
	fog.tick(dt)
	for e in legions:
		if e.dead:
			e.visible = false
			continue
		var lit: bool = enemy_lit(e)
		e.visible = lit
		if lit:
			e.seen = 0.0
		else:
			e.seen += dt


func _handle_camera(delta: float) -> void:
	if cam == null:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	if dir.length() > 0.0:
		cam.position += dir.normalized() * 900.0 * delta / cam.zoom.x
	cam.position.x = clamp(cam.position.x, 0.0, world_size.x)
	cam.position.y = clamp(cam.position.y, 0.0, world_size.y)
	if shake > 0.0:
		shake = max(0.0, shake - delta * 2.2)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 14.0
	else:
		cam.offset = Vector2.ZERO


# ---------------- 输入 ----------------
func _unhandled_input(event: InputEvent) -> void:
	if state != "fight":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom = (cam.zoom * 1.12).clamp(Vector2(0.95, 0.95), Vector2(3.4, 3.4))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom = (cam.zoom / 1.12).clamp(Vector2(0.95, 0.95), Vector2(3.4, 3.4))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(_mouse_world())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				paused = not paused
				_sfx("sfx_ui", 0.1, -4.0)
			KEY_Q:
				if selected != null:
					selected.stance = GameData.STANCES[(GameData.STANCES.find(selected.stance) + 1) % 4]
					_push_hint("姿态：%s" % GameData.STANCE_NAME[selected.stance], 1.0)
			KEY_E:
				if selected != null:
					selected.roe = GameData.ROES[(GameData.ROES.find(selected.roe) + 1) % 4]
					_push_hint("交战规则：%s" % GameData.ROE_NAME[selected.roe], 1.0)
			KEY_R:
				_recover(selected)
			KEY_TAB:
				if squads.size() > 1:
					var i := (squads.find(selected) + 1) % squads.size()
					selected = squads[i]
			KEY_1, KEY_2, KEY_3:
				var idx: int = event.keycode - KEY_1
				if idx < squads.size():
					selected = squads[idx]
			KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8:
				_play_card_idx(event.keycode - KEY_F1)


func _mouse_world() -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


func _on_left_click(wp: Vector2) -> void:
	# 选编队 / 下令
	var best: Squad = null
	var bd := 1e20
	for sq in squads:
		var d: float = wp.distance_to(sq.center)
		if d < bd:
			bd = d
			best = sq
	if bd < 70.0 / cam.zoom.x:
		selected = best
		return
	if selected == null:
		return
	# 点敌人 = 集火
	var tgt = null
	var td := 1e20
	for e in legions:
		if e.dead:
			continue
		var d: float = wp.distance_to(e.position)
		if d < td:
			td = d
			tgt = e
	if tgt != null and td < 34.0 / cam.zoom.x:
		if fog.is_lit(tgt.position) or thermal_t > 0.0:
			_issue_order(selected, {"cmd": "focus", "target": tgt})
		else:
			_push_hint("看不见那个目标", 1.0)
		return
	_issue_order(selected, {"cmd": "move", "pos": wp})


func _on_right_click() -> void:
	if state != "fight":
		return
	var wp := _mouse_world()
	# 半径随距离最近编队衰减
	var alt := 7.0
	var bd := 1e20
	for sq in squads:
		bd = min(bd, sq.center.distance_to(wp))
	var dist_cells := bd / GameData.CELL
	var radius_cells: float = max(4.0, 7.0 - dist_cells * 0.1)
	fog.stamp_pulse(wp, radius_cells * GameData.CELL)
	vfx.pulse(wp, radius_cells * GameData.CELL)
	_sfx("sfx_scan", 0.15, -2.0)
	_sfx("sfx_pulse", 0.15, -6.0, 1.1)
	# 标记范围内敌人
	for e in legions:
		if e.dead:
			continue
		if e.position.distance_to(wp) <= radius_cells * GameData.CELL:
			e.marked = 25.0


func _issue_order(sq: Squad, data: Dictionary) -> void:
	if sq.broken:
		_push_hint("编队已崩溃，先收容", 1.2)
		return
	var er := sq.exec_rate() / 100.0
	sq.order = data.duplicate()
	sq.order["exec"] = er
	sq.order["at"] = t
	sq.order_t = 0.0
	sq.feedback_t = 0.45
	_apply_order(sq)
	sq.order = {}
	_sfx("sfx_command", 0.06, -2.0)


func _resolve_orders() -> void:
	pass


func card_ids() -> Array:
	return G.deck


func _play_card_idx(idx: int) -> void:
	if idx < 0 or idx >= G.deck.size():
		return
	var cid: String = G.deck[idx]
	var card: Dictionary = GameData.CARDS[cid]
	if cid in used_cards:
		_push_hint("这张牌本场已经用过了", 1.2)
		return
	if cp < float(card["cost"]):
		_push_hint("指令点不足", 1.0)
		_sfx("sfx_deny", 0.15, -3.0)
		return
	if selected == null and card["kind"] == "squad":
		_push_hint("先选中一个编队", 1.0)
		return
	cp -= float(card["cost"])
	used_cards.append(cid)
	_sfx("sfx_confirm", 0.12, -2.0)
	_apply_card(cid)
	_audio("confirm")


func _apply_card(cid: String) -> void:
	match cid:
		"no_retreat":
			selected.no_retreat_t = 15.0
			if selected.size_alive() > 0:
				var m = selected.alive()[0]
				m.pilot["trust"] = max(0.0, float(m.pilot.get("trust", 50)) - 8.0)
			_push_hint("不惜代价：15 秒", 1.5)
		"rear_guard":
			selected.absorb_t = 8.0
			_push_hint("断后：8 秒", 1.5)
		"overload":
			for m in selected.alive():
				m.overdrive = 5.0
				m.burnout = 35.0
			_push_hint("过载：5 秒", 1.5)
		"thermal":
			thermal_t = 5.0
			_push_hint("热成像：5 秒", 1.5)
		"triangulate":
			var n := 0
			for e in legions:
				if not e.dead and not fog.is_lit(e.position):
					n += 1
			_push_hint("迷雾中还有 %d 个信号源" % n, 3.0)
		"jam":
			jam_center = selected.center
			jam_t = 8.0
			_push_hint("信号干扰：8 秒", 1.5)
		"break_charge":
			var hit := false
			for e in legions:
				if not e.dead and e.charge > 0.0 and fog.is_lit(e.position):
					e.charge = 0.0
					e.stun = 3.0
					e.exposed = 3.0
					hit = true
					vfx.explosion(e.position, Color(1.0, 0.9, 0.4), 22.0)
			_push_hint("破冲击波" if hit else "没有正在蓄力的目标", 1.5)
		"merge":
			if squads.size() < 2:
				_push_hint("只有一个编队", 1.2)
				return
			var other: Squad = null
			var bd := 1e20
			for sq in squads:
				if sq == selected:
					continue
				var d: float = sq.center.distance_to(selected.center)
				if d < bd:
					bd = d
					other = sq
			if other == null:
				return
			for m in other.members:
				selected.add(m)
			squads.erase(other)
			selected.resonance = 10.0
			selected.center = (selected.center + other.center) * 0.5
			_push_hint("合流：同步共振 10 秒", 1.6)
		"priority":
			priority_channel = true
			_push_hint("下一条命令零延迟", 1.4)
		"silence":
			selected.silence_t = 8.0
			_push_hint("静默：8 秒", 1.4)


func _recover(sq) -> void:
	if sq == null:
		return
	if not sq.broken:
		_push_hint("这个编队没有崩溃", 1.2)
		return
	if sq.recover_cd > 0.0:
		_push_hint("收容冷却中 %.0f 秒" % sq.recover_cd, 1.2)
		return
	if sq.size_alive() == 0:
		return
	sq.recovering = 2.5
	_push_hint("%s：收容中…" % sq.label, 2.5)
	_sfx("sfx_confirm", 0.2, -3.0)


func _push_hint(text: String, dur: float = 2.0) -> void:
	hint_text = text
	hint_t = dur


var _sfx_last: Dictionary = {}


func _sfx(n: String, gap: float = 0.05, vol: float = -3.0, pitch: float = 1.0) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_sfx_last.get(n, -99.0)) < gap:
		return
	_sfx_last[n] = now
	var a = get_node_or_null("/root/Audio")
	if a != null:
		a.play(n, vol, pitch + randf_range(-0.07, 0.07))


func _fx_flash(strength: float, col: Color) -> void:
	var f = get_tree().get_first_node_in_group("fx")
	if f != null:
		f.hit_flash(strength, col)


func _audio(name: String) -> void:
	var a = get_node_or_null("/root/Audio")
	if a != null:
		a.play(name)


# ---------------- 结算 ----------------
func _check_end() -> void:
	if result_sent:
		return
	var alive_m := 0
	for m in mechs:
		if not m.dead:
			alive_m += 1
	if alive_m == 0:
		_finish(false)
		return
	if all_spawned:
		var alive_e := 0
		for e in legions:
			if not e.dead:
				alive_e += 1
		if alive_e == 0:
			_finish(true)


var _pending_res: Dictionary = {}
var _over_t: float = 0.0


func _finish(win: bool) -> void:
	if state == "over":
		return
	state = "over"
	var lost := 0
	for m in mechs:
		if m.dead:
			lost += 1
	G.brains_saved += brains_saved
	G.brains_lost += brains_lost
	_pending_res = {
		"win": win,
		"lost": lost,
		"brains_saved": brains_saved,
		"brains_lost": brains_lost,
		"time": elapsed,
	}
	await get_tree().create_timer(1.4, true, false, true).timeout
	_emit_result()


func _emit_result() -> void:
	if result_sent:
		return
	result_sent = true
	battle_finished.emit(_pending_res)


# ---------------- 绘制 ----------------
func _draw_world() -> void:
	var ws := world_size
	world_layer.draw_rect(Rect2(Vector2.ZERO, ws), Color(0.012, 0.02, 0.035))
	# 六边形网格（低透明度）
	var s := 34.0
	var h := s * sqrt(3.0) * 0.5
	var x := 0.0
	var col := Color(0.13, 0.26, 0.38, 0.42)
	while x < ws.x + s:
		var y := 0.0
		var odd := int(x / (s * 1.5)) % 2 == 1
		if odd:
			y = h
		while y < ws.y + h:
			_hex(x, y, s * 0.94, col)
			y += h * 2.0
		x += s * 1.5
	# 地形
	for t in terrain:
		var r: Rect2 = t["rect"]
		var c := Color(0.16, 0.21, 0.28, 0.95)
		match t["type"]:
			"urban": c = Color(0.20, 0.23, 0.30, 1.0)
			"mountain": c = Color(0.14, 0.22, 0.30, 1.0)
			"ruin": c = Color(0.22, 0.17, 0.16, 1.0)
		world_layer.draw_rect(r, c)
		world_layer.draw_rect(r, Color(0.26, 0.46, 0.62, 0.7), false, 1.4)
		if t["type"] == "urban":
			var step := 26.0
			var gx := r.position.x
			while gx < r.position.x + r.size.x:
				world_layer.draw_line(Vector2(gx, r.position.y), Vector2(gx, r.position.y + r.size.y),
					Color(0.1, 0.13, 0.17, 0.35), 1.0)
				gx += step
			var gy := r.position.y
			while gy < r.position.y + r.size.y:
				world_layer.draw_line(Vector2(r.position.x, gy), Vector2(r.position.x + r.size.x, gy),
					Color(0.1, 0.13, 0.17, 0.35), 1.0)
				gy += step
	# 边界
	world_layer.draw_rect(Rect2(Vector2.ZERO, ws), Color(0.16, 0.4, 0.55, 0.5), false, 2.0)


func _hex(cx: float, cy: float, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var a := PI / 3.0 * float(i)
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	pts.append(pts[0])
	world_layer.draw_polyline(pts, col, 1.0)


func _draw_overlay() -> void:
	# 编队标记
	for sq in squads:
		var c: Color = Color(0.55, 0.95, 1.0)
		if sq.broken:
			c = Color(1.0, 0.4, 0.3)
		elif sq == selected:
			c = Color(1.0, 1.0, 1.0)
		overlay.draw_arc(sq.center, 40.0, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.16), 1.1)
		if sq == selected:
			overlay.draw_arc(sq.center, 46.0, 0.0, TAU, 32, Color(1, 1, 1, 0.22), 1.3)
		# 命令回执
		if sq.feedback_t > 0.0:
			var f: float = 1.0 - sq.feedback_t / 0.45
			overlay.draw_arc(sq.center, 30.0 + f * 46.0, 0.0, TAU, 36,
				Color(0.45, 0.92, 1.0, (1.0 - f) * 0.9), 2.6)
		# 编队光晕
		for k in range(3, 0, -1):
			overlay.draw_circle(sq.center, 26.0 * k, Color(0.25, 0.62, 0.85, 0.035))
		# 方位提示
		_draw_warning(sq)
	# 回收标记
	for c in recoveries:
		if c["saved"] or c["taken"]:
			continue
		var p: Vector2 = c["pos"]
		var a := 0.4 + 0.3 * sin(t * 4.0)
		overlay.draw_circle(p, 15.0, Color(1.0, 0.85, 0.35, 0.18 * a))
		overlay.draw_arc(p, 15.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.35, 0.8), 1.6)
		overlay.draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Color(1.0, 0.85, 0.35, 0.9), 1.6)
		overlay.draw_line(p + Vector2(0, -6), p + Vector2(0, 6), Color(1.0, 0.85, 0.35, 0.9), 1.6)
	# 干扰区
	if jam_t > 0.0:
		overlay.draw_arc(jam_center, 170.0, 0.0, TAU, 40, Color(0.6, 0.4, 1.0, 0.35), 2.0)
	# 镜头边框提示
	pass


func _draw_warning(sq: Squad) -> void:
	var detect := 13.5 * GameData.CELL
	var buckets := {}
	for e in legions:
		if e.dead:
			continue
		var d: float = e.position.distance_to(sq.center)
		if d > detect:
			continue
		if enemy_lit(e):
			continue
		var ang: float = (e.position - sq.center).angle()
		var bucket := int(round(ang / (PI / 4.0)))
		if not buckets.has(bucket):
			buckets[bucket] = {"n": 0, "d": d, "a": bucket * PI / 4.0}
		buckets[bucket]["n"] += 1
		buckets[bucket]["d"] = min(buckets[bucket]["d"], d)
	for b in buckets.values():
		var near: float = 1.0 - clamp(b["d"] / detect, 0.0, 1.0)
		var w := 0.30 + near * 0.18
		var alpha := 0.10 + near * 0.5
		var r := 62.0 + near * 26.0
		var pts := PackedVector2Array()
		var steps := 8
		for i in range(steps + 1):
			var a: float = b["a"] - w + (2.0 * w) * float(i) / float(steps)
			var rr := r + sin(a * 3.0 + t * 2.0) * 4.0
			pts.append(sq.center + Vector2.RIGHT.rotated(a) * rr)
		if pts.size() > 1:
			overlay.draw_polyline(pts, Color(1.0, 0.32, 0.22, alpha), 2.0 + near * 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		pass
