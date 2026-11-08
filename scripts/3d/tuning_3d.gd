extends RefCounted
## Easy-to-tweak numbers for the 3D test. Change a value, save, press F6.
## Speeds are in metres per second (Victor is 2.2 m tall).

# --- Victor --------------------------------------------------------------------
const VICTOR_SPEED := 6.2          # was 4.2 (walking pace)
const VICTOR_PUNCH_SLOWDOWN := 0.5 # fraction of speed kept while punching

# --- Guards --------------------------------------------------------------------
const GUARD_SPEED := 4.8           # was 2.6
const GUARD_WAKE_DISTANCE := 12.0  # how close Victor gets before they charge

# --- Detention Unit robot --------------------------------------------------------
const ROBOT_SPEED := 4.4           # was 2.4
const ROBOT_SWING_WINDUP := 0.45   # seconds the baton is raised before it falls

# --- Aftershocks (the quake isn't over) ------------------------------------------
const AFTERSHOCK_MIN_GAP := 8.0    # seconds between tremors, at least...
const AFTERSHOCK_MAX_GAP := 15.0   # ...and at most
const AFTERSHOCK_SHAKE := 0.45     # camera shake strength

# --- Light -----------------------------------------------------------------------
const AMBIENT_LIGHT := 0.7         # base light everywhere (was 0.4): higher = less black
const EXPOSURE := 1.2              # overall brightness of the camera
const LAMP_BRIGHTNESS := 14.0      # overhead lamps
const VICTOR_LIGHT := 1.3          # a soft light that follows Victor so he never gets lost

# --- Procedural prison floors -----------------------------------------------------
const LEVEL_PROCEDURAL := true     # false = the hand-made Cell Block C map
const LEVEL_SEED := 0              # 0 = a new prison every run; any other number = the same layout every time
const LEVEL_BLOCKS_X := 7          # floor size in room-blocks across (each about 26 m)
const LEVEL_BLOCKS_Y := 6          # ...and down
const LEVEL_WINDING := 0.7         # 0 = many shortcuts, 1 = one long winding route
const ENEMY_DENSITY := 2.8         # guards/robots per room, on average
const ROBOT_SHARE := 0.25          # fraction of enemies that are robots
const CALM_RADIUS := 4.0           # metres Victor can move from the start before the alarm goes off
const ALARM_RADIUS := 60.0         # the alarm sends every enemy within this many metres after him
