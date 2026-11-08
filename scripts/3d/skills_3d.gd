extends RefCounted
## Victor's prison reputation: a skill tree bought with SMOKES (the prison's
## money). Smokes and skills are saved to disk, so they carry over from run
## to run. Every beaten guard pays out smokes.
##
## There are also RUN BONUSES: perks for this run only (e.g. the reward for
## picking a floor theme at the lift). They're wiped when Victor goes down.
##
##   Skills.value("max_hp")      total bonus from skills + this run's perks
##   Skills.add_run_bonus("damage")
##   Skills.earn(3)              add smokes (saved straight away)

const SAVE_PATH := "user://prison_rep.cfg"

## The tree. Each skill raises one stat by `per` for every level bought.
##   branch: which column it sits in     cost: smokes for level 1 (then x2, x3...)
##   needs:  a skill that must be bought first
const TREE := [
	# MUSCLE
	{"id": "thick_skull", "branch": "MUSCLE", "name": "THICK SKULL", "stat": "max_hp", "per": 2.0, "max": 5, "cost": 15,
		"desc": "+2 max health"},
	{"id": "heavy_hands", "branch": "MUSCLE", "name": "HEAVY HANDS", "stat": "damage", "per": 0.15, "max": 5, "cost": 20,
		"desc": "+15% punch damage"},
	{"id": "iron_gut", "branch": "MUSCLE", "name": "IRON GUT", "stat": "armour_start", "per": 1.0, "max": 3, "cost": 40,
		"needs": "thick_skull", "desc": "Start each floor with 1 armour hit"},
	# HUSTLE
	{"id": "light_feet", "branch": "HUSTLE", "name": "LIGHT FEET", "stat": "speed", "per": 0.06, "max": 4, "cost": 15,
		"desc": "+6% run speed"},
	{"id": "deep_pockets", "branch": "HUSTLE", "name": "DEEP POCKETS", "stat": "powerup_time", "per": 0.25, "max": 4, "cost": 20,
		"desc": "Powerups last 25% longer"},
	{"id": "sticky_fingers", "branch": "HUSTLE", "name": "STICKY FINGERS", "stat": "powerup_luck", "per": 0.05, "max": 4, "cost": 25,
		"needs": "deep_pockets", "desc": "Guards drop powerups more often"},
	# GANG: Rally the prisoners, then grow the gang OR make it tougher
	{"id": "rally", "branch": "GANG", "name": "RALLY THE PRISONERS", "stat": "rally", "per": 2.0, "max": 1, "cost": 30,
		"desc": "Press F: nearby prisoners join you (gang of 2)"},
	{"id": "bigger_gang", "branch": "GANG", "name": "BIGGER GANG", "stat": "gang_size", "per": 1.0, "max": 5, "cost": 25,
		"needs": "rally", "desc": "+1 gang member"},
	{"id": "hardened", "branch": "GANG", "name": "HARDENED RECRUITS", "stat": "recruit_power", "per": 0.25, "max": 5, "cost": 25,
		"needs": "rally", "desc": "Recruits hit 25% harder and last longer"},
]

## Perks a run bonus gives (one pick each). Same stat names as the tree.
const RUN_BONUS := {
	"max_hp": {"stat": "max_hp", "amount": 2.0, "name": "+2 MAX HEALTH"},
	"damage": {"stat": "damage", "amount": 0.25, "name": "+25% PUNCH DAMAGE"},
	"speed": {"stat": "speed", "amount": 0.1, "name": "+10% SPEED"},
	"armour_start": {"stat": "armour_start", "amount": 1.0, "name": "START EACH FLOOR WITH ARMOUR"},
	"powerup_luck": {"stat": "powerup_luck", "amount": 0.08, "name": "MORE POWERUP DROPS"},
	"rally": {"stat": "gang_size", "amount": 1.0, "name": "+1 GANG MEMBER"},
	"recruit_power": {"stat": "recruit_power", "amount": 0.2, "name": "+20% RECRUIT POWER"},
}

static var smokes := 0
static var run_smokes := 0       # earned this run (shown on the game over screen)
static var levels := {}          # skill id -> level bought
static var run := {}             # stat -> amount, from this run's bonuses
static var _loaded := false


static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		smokes = cfg.get_value("rep", "smokes", 0)
		levels = cfg.get_value("rep", "levels", {})


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rep", "smokes", smokes)
	cfg.set_value("rep", "levels", levels)
	cfg.save(SAVE_PATH)


static func earn(n: int) -> void:
	load_save()
	smokes += n
	run_smokes += n
	save()


static func level_of(id: String) -> int:
	load_save()
	return levels.get(id, 0)


static func skill(id: String) -> Dictionary:
	for s in TREE:
		if s["id"] == id:
			return s
	return {}


static func cost(id: String) -> int:
	return int(skill(id)["cost"]) * (level_of(id) + 1)


## "" if it can be bought, otherwise why not.
static func why_not(id: String) -> String:
	var s := skill(id)
	if level_of(id) >= int(s["max"]):
		return "MAXED"
	if s.has("needs") and level_of(s["needs"]) == 0:
		return "NEEDS " + skill(s["needs"])["name"]
	if smokes < cost(id):
		return "NOT ENOUGH SMOKES"
	return ""


static func buy(id: String) -> bool:
	if why_not(id) != "":
		return false
	smokes -= cost(id)
	levels[id] = level_of(id) + 1
	save()
	return true


## Total bonus for a stat: from the saved tree plus this run's perks.
static func value(stat: String) -> float:
	load_save()
	var v: float = run.get(stat, 0.0)
	for s in TREE:
		if s["stat"] == stat:
			v += float(s["per"]) * level_of(s["id"])
	return v


static func can_rally() -> bool:
	return value("rally") > 0.0


## How many prisoners can follow Victor at once.
static func gang_size() -> int:
	if not can_rally():
		return 0
	return int(value("rally") + value("gang_size"))


static func add_run_bonus(id: String) -> void:
	var b: Dictionary = RUN_BONUS[id]
	var stat: String = b["stat"]
	var amount := float(b["amount"])
	if id == "rally" and not can_rally():
		stat = "rally"          # not unlocked yet: this run he can rally a gang of 2
		amount = 2.0
	run[stat] = run.get(stat, 0.0) + amount


## Victor went down: the run's perks are gone, the smokes are kept.
static func end_run() -> void:
	run = {}
	run_smokes = 0
