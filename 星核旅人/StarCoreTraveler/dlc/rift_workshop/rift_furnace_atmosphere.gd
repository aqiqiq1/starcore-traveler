class_name RiftFurnaceAtmosphere
extends IndoorAtmosphereBase

## DLC2 world-front atmosphere: a local warm smoke plume and a few embers at
## the entry forge.  It is deliberately small (about 150x100 px around the
## forge mouth) and sits in the middle-lower band of the screen; it is not a
## full-screen wash and there is no black silhouette.
##
## Everything is drawn at whole-pixel positions.  The layer fades out when the
## player comes within 40 px and never draws over the player clearance box or
## the phase-bridge hazard band.

const SMOKE: Texture2D = preload(
	"res://dlc/rift_workshop/assets/interior/rift_furnace_smoke_96x48.png"
)
const PUFF_SIZE: Vector2 = Vector2(96.0, 48.0)
const FORGE_X: float = 46.0

const PUFFS: Array = [
	{"offset": Vector2(-48.0, 188.0), "alpha": 0.21, "phase": 0.0, "sway": 1.4, "bob": 1.0},
	{"offset": Vector2(-60.0, 172.0), "alpha": 0.19, "phase": 2.1, "sway": 1.8, "bob": 1.2},
	{"offset": Vector2(-30.0, 156.0), "alpha": 0.17, "phase": 4.2, "sway": 1.2, "bob": 0.8},
	{"offset": Vector2(-42.0, 140.0), "alpha": 0.14, "phase": 1.3, "sway": 1.6, "bob": 1.0},
]

# x offset from the forge centre, start height, rise speed, phase, alpha.
const EMBERS: Array = [
	[-14.0, 235.0, 6.0, 1.0, 0.20],
	[-6.0, 233.0, 8.0, 12.0, 0.22],
	[2.0, 235.0, 5.0, 23.0, 0.18],
	[9.0, 232.0, 7.0, 7.0, 0.21],
	[16.0, 234.0, 9.0, 31.0, 0.19],
	[23.0, 230.0, 4.5, 18.0, 0.17],
	[-22.0, 235.0, 5.5, 28.0, 0.20],
]

var _time: float = 0.0
var _items: Array[Dictionary] = []


func _ready() -> void:
	super._ready()
	# The bridge hall's five wisps and the open pit are the only damage field
	# the plume could reach; keep a conservative rectangle around them.
	add_hazard_rect(Rect2(700.0, 214.0, 260.0, 76.0))


func _process(delta: float) -> void:
	_time += delta
	super._process(delta)


func _rebuild_effects() -> void:
	_items.clear()
	for puff: Dictionary in PUFFS:
		var phase: float = float(puff["phase"])
		var sway: float = roundf(sin(_time * 0.35 + phase) * float(puff["sway"]))
		var bob: float = roundf(sin(_time * 0.22 + phase * 1.7) * float(puff["bob"]))
		var origin: Vector2 = puff["offset"]
		var rect: Rect2 = Rect2(
			Vector2(roundf(FORGE_X + origin.x + sway), roundf(origin.y + bob)),
			PUFF_SIZE
		)
		var alpha: float = float(puff["alpha"])
		if _emit(rect, alpha):
			_items.append({"kind": "smoke", "rect": rect, "alpha": alpha})
	for index: int in range(EMBERS.size()):
		var ember: Array = EMBERS[index]
		var rise: float = fmod(_time * float(ember[2]) + float(ember[3]), 44.0)
		var ex: float = FORGE_X + float(ember[0]) \
			+ roundf(sin(_time * 0.8 + float(ember[3])) * 1.0)
		var ey: float = float(ember[1]) - rise
		var rect: Rect2 = Rect2(Vector2(roundf(ex), roundf(ey)), Vector2.ONE)
		var alpha: float = float(ember[4])
		if _emit(rect, alpha):
			var color: Color = Color("#f0a85e") if index % 2 == 0 \
				else Color("#ffd9a0")
			_items.append({
				"kind": "ember", "rect": rect, "alpha": alpha, "color": color
			})


func _draw() -> void:
	for item: Dictionary in _items:
		var rect: Rect2 = item["rect"]
		var alpha: float = float(item["alpha"])
		if String(item["kind"]) == "smoke":
			draw_texture_rect(
				SMOKE, rect, false,
				Color(1.0, 0.90, 0.78, _draw_alpha(alpha))
			)
		else:
			var color: Color = item["color"]
			draw_rect(rect, Color(color, _draw_alpha(alpha)))


func get_effect_bounds() -> Rect2:
	return Rect2(FORGE_X - 72.0, 138.0, 168.0, 100.0)
