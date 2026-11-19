extends Node
## 全局 run 状态（自动加载为 G）

var run_squads: Array = []
var roster: Array = []
var deck: Array = []
var echoes: Array = []
var pending_echo: Dictionary = {}
var node_id: String = "start"
var act: int = 1
var pressure: int = 0
var total_kills: int = 0
var brains_saved: int = 0
var brains_lost: int = 0
var fragments: int = 0
var log_lines: Array = []
var run_over: bool = false
var run_won: bool = false
var difficulty: float = 1.0
var seen_memorial: Array = []

const START_SQUADS := 2


func _ready() -> void:
	pass


func new_run() -> void:
	roster.clear()
	deck.clear()
	echoes.clear()
	pending_echo = {}
	run_squads.clear()
	node_id = "start"
	act = 1
	pressure = 0
	total_kills = 0
	brains_saved = 0
	brains_lost = 0
	fragments = 0
	log_lines.clear()
	run_over = false
	run_won = false
	seen_memorial.clear()

	# 开局：一名特殊机师 + 一名普通机师，一个编队
	var hero := make_special("undertaker")
	roster.append(hero)
	var g1 := make_generic()
	roster.append(g1)
	var g2 := make_generic()
	roster.append(g2)
	run_squads.append({"members": [hero, g1, g2]})
	_add_log_start()


func _add_log_start() -> void:
	add_log("作战开始。你手里只有两台破坏神，和一条通讯链路。")


func make_special(id: String) -> Dictionary:
	var s: Dictionary = GameData.SPECIALS[id]
	return {
		"callsign": s["callsign"],
		"name": s["name"],
		"trust": s["trust"],
		"special": id,
		"mod": s["mod"].duplicate(),
		"rule": s["rule"],
		"bonus": s["bonus"],
		"defy": s["defy"],
		"config": "",
		"memorial": false,
	}


func make_generic(pref_config: String = "") -> Dictionary:
	var cfg := pref_config
	if cfg == "":
		cfg = GameData.CONFIG_IDS[randi() % GameData.CONFIG_IDS.size()]
	var a: String = GameData.CALLSIGN_A[randi() % GameData.CALLSIGN_A.size()]
	var num := 1 + randi() % 12
	return {
		"callsign": "%s-%02d" % [a, num],
		"name": GameData.PILOT_NAMES[randi() % GameData.PILOT_NAMES.size()],
		"trust": 40 + randi() % 20,
		"special": "",
		"mod": {},
		"rule": "nearest",
		"bonus": "",
		"defy": "",
		"config": cfg,
		"memorial": false,
	}


func squad_of(pilot: Dictionary) -> int:
	for i in range(run_squads.size()):
		if pilot in run_squads[i]["members"]:
			return i
	return -1


func total_mechs() -> int:
	var n := 0
	for s in run_squads:
		n += s["members"].size()
	return n


func all_pilots() -> Array:
	var a := []
	for s in run_squads:
		for m in s["members"]:
			a.append(m)
	return a


func add_pilot(p: Dictionary) -> bool:
	if all_pilots().size() >= 10:
		return false
	# 优先放进最弱的编队
	var best := 0
	var bs := 999
	for i in range(run_squads.size()):
		var n: int = run_squads[i]["members"].size()
		if n < bs:
			bs = n
			best = i
	if run_squads.is_empty():
		run_squads.append({"members": [p]})
	else:
		run_squads[best]["members"].append(p)
	return true


func split_available() -> bool:
	return run_squads.size() < 3 and total_mechs() >= 2


func add_log(s: String) -> void:
	log_lines.append(s)
	if log_lines.size() > 40:
		log_lines.pop_front()


func node_def(id: String) -> Dictionary:
	for n in GameData.CAMPAIGN:
		if n["id"] == id:
			return n
	return {}
