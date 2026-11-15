class_name PrototypeBackground
extends CanvasLayer

## Low-contrast cloud/ruin atmosphere assembled from the approved Szadi
## background silhouettes plus a code-generated sky gradient and mist bands.
## The silhouettes are background dressing only; they are not collision maps.

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const FAR_TEXTURE: Texture2D = preload("res://assets/map/background2.png")
const NEAR_TEXTURE: Texture2D = preload("res://assets/map/background4.png")


func _ready() -> void:
	layer = -10
	var root: Control = Control.new()
	root.name = "BackgroundRoot"
	root.size = VIEW_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_add_sky(root)
	_add_sun(root)
	_add_silhouette(root, FAR_TEXTURE, Vector2(0.0, 104.0), Vector2(640.0, 280.0), Color(0.38, 0.57, 0.58, 0.42))
	_add_silhouette(root, NEAR_TEXTURE, Vector2(-8.0, 174.0), Vector2(656.0, 236.0), Color(0.18, 0.34, 0.36, 0.40))
	_add_cloud_band(root)
	_add_haze(root)


func _add_sky(root: Control) -> void:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color("#07141b"),
		Color("#102d35"),
		Color("#2a5150"),
		Color("#132b30"),
	])
	var sky_texture: GradientTexture2D = GradientTexture2D.new()
	sky_texture.width = 4
	sky_texture.height = 360
	sky_texture.gradient = gradient
	sky_texture.fill_from = Vector2(0.0, 0.0)
	sky_texture.fill_to = Vector2(0.0, 1.0)

	var sky: TextureRect = TextureRect.new()
	sky.texture = sky_texture
	sky.position = Vector2.ZERO
	sky.size = VIEW_SIZE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)


func _add_sun(root: Control) -> void:
	var halo: Polygon2D = Polygon2D.new()
	halo.polygon = _ellipse(Vector2(60.0, 60.0), 32)
	halo.position = Vector2(486.0, 94.0)
	halo.color = Color(0.74, 0.91, 0.82, 0.035)
	root.add_child(halo)

	var core: Polygon2D = Polygon2D.new()
	core.polygon = _ellipse(Vector2(32.0, 32.0), 32)
	core.position = Vector2(486.0, 94.0)
	core.color = Color(0.80, 0.94, 0.85, 0.060)
	root.add_child(core)


func _add_silhouette(
	root: Control,
	texture: Texture2D,
	position: Vector2,
	size: Vector2,
	tint: Color
) -> void:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.position = position
	rect.size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rect)


func _add_cloud_band(root: Control) -> void:
	_add_cloud(root, Vector2(130.0, 260.0), Vector2(185.0, 15.0), 0.055)
	_add_cloud(root, Vector2(390.0, 270.0), Vector2(225.0, 18.0), 0.050)
	_add_cloud(root, Vector2(555.0, 250.0), Vector2(150.0, 12.0), 0.045)
	_add_cloud(root, Vector2(250.0, 292.0), Vector2(240.0, 20.0), 0.040)
	_add_cloud(root, Vector2(540.0, 306.0), Vector2(190.0, 22.0), 0.035)
	# A brighter cloud-sea shelf is visible through the 416..496 pit gap.
	_add_cloud(root, Vector2(456.0, 332.0), Vector2(215.0, 34.0), 0.16)
	_add_cloud(root, Vector2(456.0, 350.0), Vector2(260.0, 28.0), 0.12)
	_add_cloud(root, Vector2(70.0, 344.0), Vector2(160.0, 24.0), 0.07)
	_add_cloud(root, Vector2(580.0, 340.0), Vector2(160.0, 24.0), 0.07)


func _add_cloud(root: Control, cloud_position: Vector2, radius: Vector2, alpha: float) -> void:
	var cloud: Polygon2D = Polygon2D.new()
	cloud.polygon = _ellipse(radius, 28)
	cloud.position = cloud_position
	cloud.color = Color(0.74, 0.90, 0.86, alpha)
	root.add_child(cloud)


func _add_haze(root: Control) -> void:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.44, 0.68, 0.66, 0.0),
		Color(0.50, 0.73, 0.70, 0.070),
		Color(0.58, 0.78, 0.74, 0.16),
	])
	var mist_texture: GradientTexture2D = GradientTexture2D.new()
	mist_texture.width = 4
	mist_texture.height = 140
	mist_texture.gradient = gradient
	mist_texture.fill_from = Vector2(0.0, 0.0)
	mist_texture.fill_to = Vector2(0.0, 1.0)

	var mist: TextureRect = TextureRect.new()
	mist.texture = mist_texture
	mist.position = Vector2(0.0, 220.0)
	mist.size = Vector2(640.0, 140.0)
	mist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mist.stretch_mode = TextureRect.STRETCH_SCALE
	mist.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mist)


func _ellipse(radius: Vector2, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
