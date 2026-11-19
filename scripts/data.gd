class_name GameData
extends Node
## 全局静态数据：机体配置、军团、卡牌、角色、战役。
## 数值为起点值，见设计文档第 18 节。

# ---------------- 基础 ----------------
const CELL := 32.0
const MOVE_SCALE := 0.60      # 全局移动速度系数（手感总开关）
const GRID_W := 80
const GRID_H := 56

const MECH_BASE := {
	"hp": 190.0, "atk": 13.0, "aspd": 1.0, "range": 3.8,
	"speed": 2.2, "armor": 0.30, "vision": 4.5, "vision_angle": 120.0, "scout": 2.0,
}

# ---------------- 机体配置 ----------------
const CONFIGS := {
	"melee": {
		"name": "近接型", "short": "近接", "color": Color(0.86, 0.95, 1.0),
		"mod": {"atk": 1.3, "range": 1.6, "speed": 1.06, "hp": 0.95},
		"desc": "高周波刃，贴脸爆发", "quirk": "固守时会脱队前冲",
	},
	"rifle": {
		"name": "射击型", "short": "射击", "color": Color(0.78, 0.92, 1.0),
		"mod": {},
		"desc": "多用途火炮，最稳", "quirk": "执行率 +5",
	},
	"sniper": {
		"name": "狙击型", "short": "狙击", "color": Color(0.70, 0.86, 1.0),
		"mod": {"range": 7.0, "atk": 1.12, "aspd": 0.62, "hp": 0.85},
		"desc": "长身管炮，越远越痛", "quirk": "拒绝进攻令 -15",
	},
	"suppress": {
		"name": "压制型", "short": "压制", "color": Color(0.74, 0.90, 0.98),
		"mod": {"atk": 0.78, "aspd": 1.85, "range": 3.6, "hp": 1.05},
		"desc": "多管机枪，命中减速", "quirk": "死咬同一目标",
	},
	"heavy": {
		"name": "重装型", "short": "重装", "color": Color(0.66, 0.84, 0.96),
		"mod": {"hp": 1.55, "speed": 0.74, "armor": 0.10, "atk": 1.1},
		"desc": "追加装甲，站得住", "quirk": "不会后撤",
	},
	"recon": {
		"name": "侦察型", "short": "侦察", "color": Color(0.55, 0.95, 1.0),
		"mod": {"hp": 0.80, "atk": 0.78, "vision": 3.0, "vision_angle": 24.0, "speed": 1.15},
		"desc": "高性能传感器，留 45 秒记忆", "quirk": "被发现就保命优先",
	},
	"ew": {
		"name": "电子战型", "short": "电子战", "color": Color(0.62, 0.88, 0.92),
		"mod": {"atk": 0.68, "hp": 0.9},
		"desc": "干扰吊舱，撕开敌方协同", "quirk": "开干扰时不能移动",
	},
	"command": {
		"name": "指挥型", "short": "指挥", "color": Color(0.88, 0.96, 1.0),
		"mod": {"atk": 0.6, "hp": 1.0, "vision": 0.5},
		"desc": "通讯中继，命令更快更准", "quirk": "不离开编队中心",
	},
}

const CONFIG_IDS := ["melee", "rifle", "sniper", "suppress", "heavy", "recon", "ew", "command"]

# ---------------- 军团 ----------------
const LEGION := {
	"infantry": {
		"name": "步兵型", "hp": 60.0, "atk": 6.0, "aspd": 1.05, "range": 3.0,
		"speed": 2.55, "armor": 0.0, "danger": 1.0, "size": 9.0,
	},
	"armored": {
		"name": "装甲型", "hp": 150.0, "atk": 11.0, "aspd": 0.5, "range": 3.2,
		"speed": 1.8, "armor": 0.32, "danger": 2.4, "size": 12.0, "charge": true,
	},
	"artillery": {
		"name": "炮击型", "hp": 65.0, "atk": 18.0, "aspd": 0.3, "range": 9.0,
		"speed": 0.85, "armor": 0.0, "danger": 3.2, "size": 11.0,
	},
	"ew": {
		"name": "电子战型", "hp": 60.0, "atk": 4.0, "aspd": 1.0, "range": 4.0,
		"speed": 1.5, "armor": 0.0, "danger": 1.6, "size": 10.0, "jam": true,
	},
	"recovery": {
		"name": "回收型", "hp": 90.0, "atk": 0.0, "aspd": 1.0, "range": 1.0,
		"speed": 1.7, "armor": 0.1, "danger": 0.5, "size": 10.0, "recovery": true,
	},
	"shepherd": {
		"name": "牧羊人", "hp": 340.0, "atk": 18.0, "aspd": 0.7, "range": 5.0,
		"speed": 1.45, "armor": 0.2, "danger": 5.0, "size": 16.0, "boss": true,
	},
}

# ---------------- 角色 ----------------
const SPECIALS := {
	"undertaker": {
		"name": "辛", "callsign": "Undertaker",
		"mod": {"atk": 1.15}, "trust": 62,
		"rule": "max_danger", "bonus": "focus_never_fails",
		"defy": "ally_bleed_no_retreat",
		"text": "优先打危险度最高；队友濒死时无视撤退令。集火命令永不失败。",
	},
	"wehrwolf": {
		"name": "莱登", "callsign": "Wehrwolf",
		"mod": {"hp": 1.15}, "trust": 58,
		"rule": "nearest", "bonus": "squad_exec_15",
		"defy": "after_ally_death_10s",
		"text": "所在编队执行率 +15。队友阵亡后 10 秒内不听命令。",
	},
	"gunslinger": {
		"name": "可蕾娜", "callsign": "Gunslinger",
		"mod": {"atk": 1.18, "range": 1.5}, "trust": 55,
		"rule": "nearest", "bonus": "first_shot_crit",
		"defy": "spare_ally_abandon_post",
		"text": "每场第一次射击必中且 ×1.5。会为救队友放弃最佳射位。",
	},
	"snowwitch": {
		"name": "安珠", "callsign": "Snow Witch",
		"mod": {"hp": 1.25, "armor": 0.05}, "trust": 60,
		"rule": "protect_bleeding", "bonus": "squad_integrity_30",
		"defy": "body_block_immobile",
		"text": "所在编队崩溃阈值 +30。队友濒死时替其承伤，且自己不能移动。",
	},
	"laughingfox": {
		"name": "西奥", "callsign": "Laughing Fox",
		"mod": {"speed": 1.1}, "trust": 52,
		"rule": "nearest", "bonus": "place_memory_90",
		"defy": "stay_in_marked_zone",
		"text": "可在城区/山区造 1 个 90 秒记忆点。不会离开自己标记的区域。",
	},
}

# 普通机师的呼号池（自动生成，但都是人）
const CALLSIGN_A := ["Sparrow", "Ashen", "Grim", "Falcon", "Rook", "Cinder", "Vale", "Hollow",
	"Ember", "Wren", "Talon", "Mire", "Dusk", "Briar", "Slate", "Crow"]
const PILOT_NAMES := ["莉娜", "索菲", "尤金", "米拉", "诺亚", "艾莲", "卡森", "薇拉",
	"塔娜", "雷奥", "希拉", "但丁", "露娜", "伊森", "玛尔", "琴"]

# ---------------- 卡牌 ----------------
# kind: squad / global / merge
const CARDS := {
	"no_retreat": {
		"name": "不惜代价", "cost": 3, "kind": "squad", "rare": 2,
		"text": "15 秒内无视伤亡、不撤退、火力 ×1.5。之后信任 -8。",
		"tag": "牺牲",
	},
	"rear_guard": {
		"name": "断后", "cost": 2, "kind": "squad", "rare": 2,
		"text": "8 秒内不能移动，但承担全队 60% 伤害。",
		"tag": "牺牲",
	},
	"overload": {
		"name": "过载", "cost": 3, "kind": "squad", "rare": 2,
		"text": "伤害 ×2 持续 5 秒；之后 30 秒无法攻击。",
		"tag": "牺牲",
	},
	"thermal": {
		"name": "热成像", "cost": 3, "kind": "global", "rare": 2,
		"text": "全图敌人 5 秒以热源显示；同时暴露我方位置。",
		"tag": "信息",
	},
	"triangulate": {
		"name": "三角定位", "cost": 1, "kind": "global", "rare": 1,
		"text": "显示迷雾中还有多少个信号源。",
		"tag": "信息",
	},
	"jam": {
		"name": "信号干扰", "cost": 3, "kind": "squad", "rare": 2,
		"text": "编队周围 8 秒：敌方不能呼叫增援、不能共享感知。",
		"tag": "反制",
	},
	"break_charge": {
		"name": "破冲击波", "cost": 2, "kind": "global", "rare": 2,
		"text": "取消视野内正在蓄力的冲击波，使其硬直 3 秒并暴露核心。",
		"tag": "反制",
	},
	"merge": {
		"name": "合流", "cost": 2, "kind": "merge", "rare": 1,
		"text": "合并最近的两个编队；10 秒同步共振（执行率 100%、射速 +25%）。",
		"tag": "结构",
	},
	"priority": {
		"name": "优先信道", "cost": 1, "kind": "global", "rare": 1,
		"text": "下一条命令零延迟。",
		"tag": "时序",
	},
	"silence": {
		"name": "静默", "cost": 1, "kind": "squad", "rare": 1,
		"text": "8 秒脱离敌方锁定；期间不能下命令。",
		"tag": "时序",
	},
}

const CARD_IDS := ["no_retreat", "rear_guard", "overload", "thermal", "triangulate",
	"jam", "break_charge", "merge", "priority", "silence"]

# ---------------- 姿态 / 交战规则 ----------------
const STANCES := ["attack", "hold", "maneuver", "withdraw"]
const STANCE_NAME := {"attack": "进攻", "hold": "固守", "maneuver": "机动", "withdraw": "撤离"}
const ROES := ["nearest", "dangerous", "visible_only", "survive"]
const ROE_NAME := {"nearest": "最近", "dangerous": "最危险", "visible_only": "只打视野内", "survive": "保命优先"}

# ---------------- 战役 ----------------
# 固定流程，可选分支。type: battle / explore / rest / boss
const CAMPAIGN := [
	{"id": "n1", "name": "接触", "type": "battle", "act": 1, "next": ["n2"],
		"enc": "skirmish", "brief": "第一段战线。两机对六机。"},
	{"id": "n2", "name": "废墟", "type": "explore", "act": 1, "next": ["n3", "n3b"],
		"brief": "城市废墟。补给与卡牌都在里面，时间在外面。"},
	{"id": "n3", "name": "钳形", "type": "battle", "act": 1, "next": ["n4"],
		"enc": "pincer", "brief": "两翼同时升温。"},
	{"id": "n3b", "name": "前哨", "type": "battle", "act": 1, "next": ["n4"],
		"enc": "outpost", "brief": "绕开废墟，直接打前哨站。人少，目标硬。"},
	{"id": "n4", "name": "休整", "type": "rest", "act": 2, "next": ["n5"],
		"brief": "后方。维修、招募、删牌，三选一。"},
	{"id": "n5", "name": "铁砧", "type": "battle", "act": 2, "next": ["n6", "n6b"],
		"enc": "anvil", "brief": "正面被钉住，侧翼安静得可怕。"},
	{"id": "n6", "name": "伏击", "type": "battle", "act": 2, "next": ["n7"],
		"enc": "silence", "brief": "没有一个信号。它们已经在了。"},
	{"id": "n6b", "name": "护送", "type": "battle", "act": 2, "next": ["n7"],
		"enc": "escort", "brief": "回收型正在往外运东西。别让它走。"},
	{"id": "n7", "name": "休整", "type": "rest", "act": 2, "next": ["n8"],
		"brief": "最后一次喘息。"},
	{"id": "n8", "name": "牧羊人", "type": "boss", "act": 3, "next": [],
		"enc": "boss", "brief": "它用的脑髓，是你的人。"},
]

# 遭遇定义：waves = [{type, count, bearing, delay}]
const ENCOUNTERS := {
	"skirmish": {
		"name": "接触", "pressure": 0, "time_limit": 0.0,
		"waves": [
			{"type": "infantry", "count": 5, "delay": 1.2, "bearings": [0.0]},
			{"type": "infantry", "count": 4, "delay": 10.0, "bearings": [2.3]},
			{"type": "infantry", "count": 3, "delay": 20.0, "bearings": [4.2]},
		],
	},
	"pincer": {
		"name": "钳形", "pressure": 6, "time_limit": 0.0,
		"waves": [
			{"type": "infantry", "count": 5, "delay": 1.5, "bearings": [0.0]},
			{"type": "infantry", "count": 5, "delay": 7.0, "bearings": [3.14]},
			{"type": "armored", "count": 2, "delay": 18.0, "bearings": [1.4]},
			{"type": "infantry", "count": 4, "delay": 26.0, "bearings": [4.6]},
		],
	},
	"outpost": {
		"name": "前哨", "pressure": 8, "time_limit": 0.0,
		"waves": [
			{"type": "infantry", "count": 3, "delay": 2.0, "bearings": [0.0]},
			{"type": "armored", "count": 1, "delay": 10.0, "bearings": [0.8]},
			{"type": "artillery", "count": 1, "delay": 16.0, "bearings": [2.2]},
		],
	},
	"anvil": {
		"name": "铁砧", "pressure": 10, "time_limit": 0.0,
		"waves": [
			{"type": "armored", "count": 2, "delay": 2.0, "bearings": [0.0]},
			{"type": "infantry", "count": 6, "delay": 8.0, "bearings": [0.9]},
			{"type": "infantry", "count": 6, "delay": 12.0, "bearings": [2.4]},
			{"type": "artillery", "count": 2, "delay": 24.0, "bearings": [1.6]},
		],
	},
	"silence": {
		"name": "静默", "pressure": 10, "time_limit": 0.0,
		"waves": [
			{"type": "infantry", "count": 10, "delay": 6.0, "bearings": [0.6, 2.5]},
			{"type": "ew", "count": 1, "delay": 14.0, "bearings": [1.6]},
			{"type": "armored", "count": 2, "delay": 22.0, "bearings": [3.9]},
		],
	},
	"escort": {
		"name": "护送", "pressure": 8, "time_limit": 60.0,
		"waves": [
			{"type": "recovery", "count": 1, "delay": 1.0, "bearings": [0.3]},
			{"type": "infantry", "count": 6, "delay": 4.0, "bearings": [0.3]},
			{"type": "armored", "count": 2, "delay": 16.0, "bearings": [2.6]},
		],
	},
	"boss": {
		"name": "牧羊人", "pressure": 14, "time_limit": 0.0,
		"waves": [
			{"type": "shepherd", "count": 1, "delay": 2.0, "bearings": [0.0]},
			{"type": "infantry", "count": 8, "delay": 6.0, "bearings": [0.7, 2.4]},
			{"type": "armored", "count": 3, "delay": 18.0, "bearings": [1.6]},
			{"type": "infantry", "count": 8, "delay": 26.0, "bearings": [4.0]},
			{"type": "artillery", "count": 2, "delay": 34.0, "bearings": [2.9]},
		],
	},
}


static func make_mech_stats(config_id: String, pilot: Dictionary) -> Dictionary:
	var c: Dictionary = CONFIGS.get(config_id, CONFIGS["rifle"])
	var mod: Dictionary = c.get("mod", {})
	var s := {}
	for k in MECH_BASE:
		s[k] = float(MECH_BASE[k])
	for k in mod:
		if k in ["vision_angle"]:
			s[k] = s[k] + float(mod[k])
		else:
			s[k] = s[k] * float(mod[k]) if k != "armor" else s[k] + float(mod[k])
	# 角色特殊修正
	var pmod: Dictionary = pilot.get("mod", {})
	for k in pmod:
		if k == "armor":
			s[k] = s[k] + float(pmod[k])
		elif k == "vision_angle":
			s[k] = s[k] + float(pmod[k])
		else:
			s[k] = s[k] * float(pmod[k])
	return s
