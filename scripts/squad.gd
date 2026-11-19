class_name Squad
extends Node2D
## 编队：唯一可操作单位。玩家的所有命令都落在它身上。

signal broke(squad)
signal recovered(squad)
signal member_died(mech)

var members: Array = []
var battle = null
var stance: String = "hold"
var roe: String = "nearest"
var center: Vector2 = Vector2.ZERO
var dest: Vector2 = Vector2.ZERO
var has_dest: bool = false
var facing: float = 0.0
var integrity: float = 100.0
var max_integrity: float = 100.0
var broken: bool = false
var recovering: float = 0.0
var recover_cd: float = 0.0
var focus = null
var focus_power: float = 1.3
var formation_t: float = 0.0
var index: int = 0
var label: String = "中央"
var attention: float = 1.0
var stagger: float = 0.0
var absorb: float = 0.0          # 断后：替全队承伤
var absorb_t: float = 0.0
var no_retreat_t: float = 0.0
var resonance: float = 0.0      # 合流同步共振
var feedback_t: float = 0.0     # 命令回执（视觉反馈）
var grace: float = 0.0          # 收容后的宽限
var stall_t: float = 0.0
var last_dl: float = 1e9
var silence_t: float = 0.0
var jammed_t: float = 0.0
var order: Dictionary = {}      # 当前在途命令
var order_t: float = 0.0
var last_loss: float = 0.0
var member_lost: float = 0.0

const FORMATIONS := {
	1: [Vector2.ZERO],
	2: [Vector2(-16, 0), Vector2(16, 0)],
	3: [Vector2(0, -18), Vector2(-17, 14), Vector2(17, 14)],
}


func add(mech) -> void:
	members.append(mech)
	mech.squad = self
	_recalc_center()
	_refresh_label()


func alive() -> Array:
	var a := []
	for m in members:
		if not m.dead:
			a.append(m)
	return a


func size_alive() -> int:
	return alive().size()


func _refresh_label() -> void:
	pass


func _recalc_center() -> void:
	var a := alive()
	if a.is_empty():
		return
	var c := Vector2.ZERO
	for m in a:
		c += m.position
	c = c / float(a.size())
	# 中心永远只由"指令"驱动：不跟随成员位置，避免任何形式的漂移/绕圈
	# （成员被挤开时，会自己走回队形槽位）


func strength() -> float:
	var total := 0.0
	for m in members:
		total += m.hp_frac()
	return total / max(1.0, float(members.size()))


func update(dt: float, battle) -> void:
	stagger = max(0.0, stagger - dt)
	recover_cd = max(0.0, recover_cd - dt)
	absorb_t = max(0.0, absorb_t - dt)
	no_retreat_t = max(0.0, no_retreat_t - dt)
	resonance = max(0.0, resonance - dt)
	feedback_t = max(0.0, feedback_t - dt)
	formation_t = max(0.0, formation_t - dt)
	silence_t = max(0.0, silence_t - dt)
	_recalc_center()

	if recovering > 0.0:
		recovering -= dt
		if recovering <= 0.0:
			broken = false
			grace = 7.0
			recover_cd = 30.0
			emit_signal("recovered", self)
		_update_members(dt)
		return

	# 完整性直接由机体血量推导
	grace = max(0.0, grace - dt)
	integrity = strength() * 100.0

	if broken:
		if has_dest:
			_move_squad(dt, battle)
		_update_members(dt)
		return

	# 崩溃判定：平均血量跌破 32%
	if integrity <= 32.0 and grace <= 0.0:
		broken = true
		dest = _retreat_point(battle)
		has_dest = true
		emit_signal("broke", self)
		return

	_move_squad(dt, battle)
	_update_members(dt)


func _retreat_point(battle) -> Vector2:
	var dir: Vector2 = (center - battle.map_center()).normalized()
	if dir.length() < 0.1:
		dir = Vector2.DOWN
	return center + dir * 420.0


func _nearest_enemy(battle):
	var best = null
	var bd := 1e20
	if battle.fog == null:
		return null
	for e in battle.legions:
		if e.dead:
			continue
		if not battle.fog.is_lit(e.position):
			continue
		var d := center.distance_to(e.position)
		if d < bd:
			bd = d
			best = e
	return best


func _move_squad(dt: float, battle) -> void:
	var spd := 2.35 * GameData.CELL * GameData.MOVE_SCALE
	if silence_t > 0.0:
		spd *= 0.7
	var tgt := center
	# 移动完全由玩家点击决定：不再自动冲向敌人
	if has_dest:
		tgt = dest
		if center.distance_to(dest) < 18.0:
			center = dest
			has_dest = false
			tgt = center
	elif stance == "withdraw" and not broken:
		tgt = _retreat_point(battle)
	elif stance == "maneuver":
		var e = _nearest_enemy(battle)
		if e != null and center.distance_to(e.position) < 240.0:
			tgt = center + (center - e.position).normalized() * 55.0

	var to := tgt - center
	var dl := to.length()
	# 停滞检测：1.2 秒没有靠近就认为到了（防止绕障无限打转）
	if has_dest:
		if dl < last_dl - 0.6:
			last_dl = dl
			stall_t = 0.0
		else:
			stall_t += dt
			if stall_t > 1.2:
				has_dest = false
				stall_t = 0.0
				dl = 0.0
				to = Vector2.ZERO
	else:
		stall_t = 0.0
		last_dl = 1e9
	if dl > 16.0:
		var step := to.normalized() * spd * dt
		if step.length() > dl:
			step = to
		center += step
		# 只有真的在赶路时才转向，否则会在目的地原地旋转
		if dl > 34.0:
			facing = lerp_angle(facing, to.angle(), clamp(dt * 5.0, 0.0, 1.0))
	center.x = clamp(center.x, 40.0, GameData.GRID_W * GameData.CELL - 40.0)
	center.y = clamp(center.y, 40.0, GameData.GRID_H * GameData.CELL - 40.0)
	if battle != null:
		center = battle.resolve_obstacle(center, 36.0)


func _update_members(dt: float) -> void:
	var a := alive()
	var n := a.size()
	if n == 0:
		return
	var form: Array = FORMATIONS.get(n, [])
	var base := center
	var fw := Vector2.RIGHT.rotated(facing)
	var side := Vector2(-fw.y, fw.x)
	var speed := 2.4 * GameData.CELL
	for i in range(n):
		var m = a[i]
		m.stagger = stagger
		var off: Vector2 = form[i] if i < form.size() else Vector2.ZERO
		var want: Vector2 = base + fw * off.x + side * off.y
		if broken or recovering > 0.0:
			want = m.position + (base - m.position).normalized() * 40.0
		var to: Vector2 = want - m.position
		if to.length() > 3.0:
			var mv: Vector2 = to.normalized() * min(float(m.stats["speed"]) * GameData.CELL * GameData.MOVE_SCALE * 1.15, speed) * dt
			if mv.length() > to.length():
				mv = to
			m.position += mv
		m.facing = lerp_angle(m.facing, facing, clamp(dt * 8.0, 0.0, 1.0))
		m.position.x = clamp(m.position.x, 24.0, GameData.GRID_W * GameData.CELL - 24.0)
		m.position.y = clamp(m.position.y, 24.0, GameData.GRID_H * GameData.CELL - 24.0)


func on_member_hurt(dmg: float) -> void:
	member_lost += dmg
	last_loss = 0.0


func on_member_died(mech) -> void:
	integrity = max(0.0, integrity - 25.0)
	member_lost = 0.0
	emit_signal("member_died", mech)


func exec_rate() -> float:
	var n := 1
	if battle != null:
		n = max(1, int(battle.squads.size()))
	var trust := 50.0
	for m in members:
		if m.pilot.has("trust"):
			trust = max(trust, float(m.pilot["trust"]))
	var base := 68.0 + 0.28 * trust + (attention - 1.0 / float(n)) * 100.0
	# 指挥型加成
	for m in alive():
		if m.cfg_id == "command":
			base += 10.0
	if resonance > 0.0:
		base = 100.0
	return clamp(base, 15.0, 95.0)


func order_delay() -> float:
	return 0.0


func _draw() -> void:
	if broken:
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.3, 0.5), 2.0)
