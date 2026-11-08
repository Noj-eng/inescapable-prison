extends RefCounted
## In-run experience, like the 2D game: beaten enemies drop XP, XP fills the
## bar, and every level-up offers a choice of three super-villain abilities.
## It carries on from floor to floor and resets when Victor goes down.
## (Separate from smokes and the Prison Rep tree, which last forever.)

const MAX_RANK := 5

## Every ability you can pick when levelling up. Each can be taken 5 times.
##   stats: added to Victor's stats per rank (same names as skills_3d.gd)
const ABILITIES := {
	"titan_fists": {"name": "TITAN FISTS", "text": "Your punches land like wrecking balls. +30% damage.",
		"stats": {"damage": 0.3}},
	"hyper_reflexes": {"name": "HYPER REFLEXES", "text": "Your nerves fire like a machine. Punch 15% faster.",
		"stats": {"punch_speed": 0.15}},
	"kinetic_reach": {"name": "KINETIC REACH", "text": "A wall of force rides ahead of every blow. Punch range +20%.",
		"stats": {"reach": 0.2}},
	"iron_hide": {"name": "IRON HIDE", "text": "Your skin hardens like steel. +3 max health, heal 3.",
		"stats": {"max_hp": 3.0}},
	"blur_step": {"name": "BLUR STEP", "text": "Move 12% faster than the guards can follow.",
		"stats": {"speed": 0.12}},
	"magnetic_pull": {"name": "MAGNETIC PULL", "text": "Drag XP toward you from much further away.",
		"stats": {"magnet": 1.0}},
	"dark_vitality": {"name": "DARK VITALITY", "text": "Feed on fear. Heal 1 health every few knockouts (more often each rank).",
		"stats": {"vitality": 1.0}},
	"seismic_slam": {"name": "SEISMIC SLAM", "text": "Every 3rd punch splits the floor with a shockwave that hits everything around you.",
		"stats": {"seismic": 1.0}},
	"storm_caller": {"name": "STORM CALLER", "text": "Lightning arcs from you to the nearest enemy every few seconds.",
		"stats": {"storm": 1.0}},
	"telekinetic_storm": {"name": "TELEKINETIC STORM", "text": "Your mind spins shards of broken casing around you. They cut whoever gets close.",
		"stats": {"shards": 1.0}},
}

static var level := 1
static var xp := 0
static var ranks := {}          # ability id -> times taken
static var pending := 0         # level-ups waiting for a choice
static var knockouts := 0


static func needed() -> int:
	return 6 + (level - 1) * 5


## Returns how many levels were gained.
static func add(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= needed():
		xp -= needed()
		level += 1
		gained += 1
	pending += gained
	return gained


static func stat(name: String) -> float:
	var v := 0.0
	for id in ranks:
		v += float(ABILITIES[id]["stats"].get(name, 0.0)) * int(ranks[id])
	return v


## Three different abilities that aren't maxed out yet.
static func offer(rng: RandomNumberGenerator) -> Array:
	var pool := []
	for id in ABILITIES:
		if int(ranks.get(id, 0)) < MAX_RANK:
			pool.append(id)
	var out := []
	while out.size() < 3 and pool.size() > 0:
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out


static func take(id: String) -> void:
	ranks[id] = int(ranks.get(id, 0)) + 1
	pending = maxi(0, pending - 1)


static func reset() -> void:
	level = 1
	xp = 0
	ranks = {}
	pending = 0
	knockouts = 0
