extends Node2D
class_name ArenaFog

@export_range(0.0, 1000.0, 1.0) var inner_fade_width := 360.0
@export_range(0.0, 3000.0, 1.0) var outer_dark_extension := 1400.0
@export_range(0.0, 1.0, 0.01) var darkness := 0.96

@onready var fog_shape: Sprite2D = $FogShape
var arena_radius := 0.0

func _ready() -> void:
	z_index = 4096
	var terrain := get_parent().get_node_or_null("Tiles/Terrain") as TileMapLayer
	if terrain == null or terrain.tile_set == null:
		return
	var used_cells := terrain.get_used_rect()
	if used_cells.size.x <= 0 or used_cells.size.y <= 0:
		return
	var center_cell := used_cells.position + Vector2i(used_cells.size.x / 2, used_cells.size.y / 2)
	global_position = terrain.to_global(terrain.map_to_local(center_cell))
	var tile_size := terrain.tile_set.tile_size
	arena_radius = maxf(minf(used_cells.size.x * tile_size.x, used_cells.size.y * tile_size.y) * 0.5 - 24.0, 0.0)
	if arena_radius <= 0.0:
		return
	var outer_radius := arena_radius + outer_dark_extension
	var inner_radius := maxf(arena_radius - inner_fade_width, 0.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([
		0.0,
		inner_radius / outer_radius,
		arena_radius / outer_radius,
		1.0,
	])
	var transparent_fog := Color(0.008, 0.006, 0.016, 0.0)
	var dark_fog := Color(0.008, 0.006, 0.016, darkness)
	gradient.colors = PackedColorArray([transparent_fog, transparent_fog, dark_fog, dark_fog])
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var radial_texture := GradientTexture2D.new()
	radial_texture.gradient = gradient
	radial_texture.fill = GradientTexture2D.FILL_RADIAL
	radial_texture.fill_from = Vector2(0.5, 0.5)
	radial_texture.fill_to = Vector2(1.0, 0.5)
	radial_texture.width = 1024
	radial_texture.height = 1024
	fog_shape.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog_shape.texture = radial_texture
	fog_shape.scale = Vector2.ONE * (outer_radius * 2.0 / radial_texture.width)
