extends RefCounted
## The enemy roster: recoloured guards and robots, each with its own trick.
## Deeper floors unlock more types and make everyone tougher.
##
##   base:   which body it uses ("guard" or "robot")
##   tint:   colour multiplied over the Meshy textures (and a faint glow)
##   hp / speed: multipliers on the base guard or robot
##   from:   first floor it can appear on
##   weight: how common it is once unlocked
##   blurb:  shown the first time you meet it

const TYPES := {
	"guard": {
		"base": "guard", "name": "GUARD", "tint": Color(1, 1, 1), "hp": 1.0, "speed": 1.0,
		"from": 1, "weight": 6.0, "blurb": "",
	},
	"riot": {
		"base": "guard", "name": "RIOT GUARD", "tint": Color(1.0, 0.82, 0.35), "hp": 1.8, "speed": 0.8,
		"from": 1, "weight": 2.0, "blurb": "Shield up front. Get round the side or behind.",
	},
	"taser": {
		"base": "guard", "name": "TASER GUARD", "tint": Color(0.35, 1.0, 0.85), "hp": 0.8, "speed": 1.0,
		"from": 2, "weight": 2.0, "blurb": "Keeps its distance and fires darts that slow you.",
	},
	"enforcer": {
		"base": "guard", "name": "ENFORCER", "tint": Color(1.0, 0.35, 0.3), "hp": 2.6, "speed": 0.95,
		"from": 3, "weight": 1.5, "blurb": "Glows red, then charges. Step aside.",
	},
	"gunner": {
		"base": "guard", "name": "GUNNER", "tint": Color(0.75, 0.45, 1.0), "hp": 0.9, "speed": 0.95,
		"from": 2, "weight": 1.8, "blurb": "A red laser marks you, then it fires. Break the line.",
	},
	"grenadier": {
		"base": "guard", "name": "GRENADIER", "tint": Color(0.55, 0.95, 0.3), "hp": 1.1, "speed": 0.9,
		"from": 2, "weight": 1.5, "blurb": "Lobs grenades. Get out of the blinking ring.",
	},
	"turret": {
		"base": "turret", "name": "WALL TURRET", "tint": Color(1, 1, 1), "hp": 1.0, "speed": 0.0,
		"from": 1, "weight": 1.0, "blurb": "Bolted down. Laser first, then bullets. Punch it apart.",
	},
	"robot": {
		"base": "robot", "name": "DETENTION UNIT", "tint": Color(1, 1, 1), "hp": 1.0, "speed": 1.0,
		"from": 1, "weight": 4.0, "blurb": "",
	},
	"shock": {
		"base": "robot", "name": "SHOCK UNIT", "tint": Color(0.45, 0.65, 1.0), "hp": 1.2, "speed": 0.9,
		"from": 2, "weight": 2.0, "blurb": "Charges up and blasts the floor around it. Back off when it glows.",
	},
	"bomb": {
		"base": "robot", "name": "SCRAP BOMBER", "tint": Color(1.0, 0.55, 0.15), "hp": 0.6, "speed": 1.4,
		"from": 3, "weight": 2.0, "blurb": "Rolls in and blows up. It takes other guards with it.",
	},
}


## Picks a type for a guard ("G") or robot ("M") spot on the given floor.
static func pick(base: String, depth: int, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	var options := []
	for id in TYPES:
		var t: Dictionary = TYPES[id]
		if t["base"] != base or depth < t["from"]:
			continue
		var w: float = t["weight"]
		if t["blurb"] == "":
			w = maxf(1.5, w - (depth - 1))        # plain enemies thin out deeper down
		else:
			w += 0.4 * (depth - t["from"])         # special ones get more common
		options.append([id, w])
		total += w
	var roll := rng.randf() * total
	for o in options:
		roll -= o[1]
		if roll <= 0.0:
			return o[0]
	return base
