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
