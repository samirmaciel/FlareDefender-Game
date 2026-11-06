extends CharacterBody2D
class_name PlayerController

enum HeldItem { NONE, AXE, GOLD, HAMMER, KNIFE, MEAT, PICKAXE, WOOD }

signal held_item_changed(item: HeldItem)

@export var move_speed := 240.0
@export var sprint_speed := 360.0
@export var sprint_animation_speed_scale := 1.6
@export var held_item: HeldItem = HeldItem.HAMMER
@export var sentinel_scene: PackedScene = preload("res://Entities/sentinel_level1_weapon.tscn")
@export_range(0.0, 200.0, 1.0) var construction_corner_radius := 64.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: PlayerStats = $PlayerStats

var facing_left := false
var is_interacting := false
var sentinel_preview: SentinelLevel1Weapon
var arena_center := Vector2.ZERO
var arena_radius := 0.0
var construction_area: Area2D
var construction_area_overlay: Polygon2D
var construction_area_outline: Node2D

const IDLE_ANIMATIONS := {
	HeldItem.NONE: "Idle",
	HeldItem.AXE: "Idle Axe",
	HeldItem.GOLD: "Idle Gold",
	HeldItem.HAMMER: "Idle Hammer",
	HeldItem.KNIFE: "Idle Knife",
	HeldItem.MEAT: "Idle Meat",
	HeldItem.PICKAXE: "Idle Pickaxe",
	HeldItem.WOOD: "Idle Wood",
}

const MOVE_ANIMATIONS := {
	HeldItem.NONE: "Run",
	HeldItem.AXE: "Run Axe",
	HeldItem.GOLD: "Run Gold",
	HeldItem.HAMMER: "Run Hammer",
	HeldItem.KNIFE: "Run Knife",
	HeldItem.MEAT: "Run Meat",
	HeldItem.PICKAXE: "Run Pickaxe",
	HeldItem.WOOD: "Run Wood",
}

const ACTION_ANIMATIONS := {
	HeldItem.AXE: "Interact Axe",
	HeldItem.HAMMER: "Interact Hammer",
	HeldItem.KNIFE: "Interact Knife",
	HeldItem.PICKAXE: "Interact Pickaxe",
}
const CONSTRUCTION_AREA_OUTLINE_SCRIPT = preload("res://Scripts/construction_area_outline.gd")

const TREE_OCCLUDED_ALPHA := 0.4
const TREE_OCCLUSION_RADIUS := 80.0
const DEPTH_SORT_OFFSET := 1030

func _ready() -> void:
	add_to_group("player")
	_setup_arena_boundary()
	_setup_construction_area()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.flip_h = false
	# Item interactions should finish so the controller can return to idle/run.
	for animation_name in ACTION_ANIMATIONS.values():
		animated_sprite.sprite_frames.set_animation_loop(animation_name, false)
	_play_if_needed(IDLE_ANIMATIONS[held_item])

func equip_item(item: HeldItem) -> void:
	if held_item == item:
		return
	held_item = item
	held_item_changed.emit(held_item)
	if not is_interacting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_play_if_needed(IDLE_ANIMATIONS[held_item])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			_start_sentinel_placement()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE and is_instance_valid(sentinel_preview):
			_cancel_sentinel_placement()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and is_instance_valid(sentinel_preview):
		if event.button_index == MOUSE_BUTTON_LEFT:
			sentinel_preview.global_position = get_global_mouse_position()
			_update_sentinel_placement_validity()
			if sentinel_preview.is_placement_valid:
				sentinel_preview.confirm_placement()
				sentinel_preview = null
				_set_construction_area_visible(false)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_sentinel_placement()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not is_interacting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_start_interaction()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(sentinel_preview):
		sentinel_preview.global_position = get_global_mouse_position()
		_update_sentinel_placement_validity()
	_update_tree_sort_order()
	var direction := Vector2.ZERO
	direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	direction.x -= float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	direction.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	direction.y -= float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	direction = direction.normalized()

	if is_interacting and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_interacting = false
	if is_interacting:
		velocity = Vector2.ZERO
		stats.update_stamina(false, _delta)
		move_and_slide()
		_clamp_to_arena()
		return

	if absf(direction.x) > 0.01:
		facing_left = direction.x < 0.0
		animated_sprite.flip_h = facing_left

	var sprint_requested := Input.is_key_pressed(KEY_SHIFT) and not direction.is_zero_approx()
	var sprinting := sprint_requested and stats.can_sprint()
	stats.update_stamina(sprinting, _delta)

	var current_speed := sprint_speed if sprinting else move_speed
	velocity = direction * current_speed
	move_and_slide()
	_clamp_to_arena()
	_update_animation(direction, sprinting)

func _setup_arena_boundary() -> void:
	var terrain := get_tree().current_scene.get_node_or_null("Tiles/Terrain") as TileMapLayer
	if terrain == null or terrain.tile_set == null:
		return
	var used_cells := terrain.get_used_rect()
	if used_cells.size.x <= 0 or used_cells.size.y <= 0:
		return
	var center_cell := used_cells.position + Vector2i(used_cells.size.x / 2, used_cells.size.y / 2)
	arena_center = terrain.to_global(terrain.map_to_local(center_cell))
	var tile_size := terrain.tile_set.tile_size
	arena_radius = minf(used_cells.size.x * tile_size.x, used_cells.size.y * tile_size.y) * 0.5 - 24.0
	arena_radius = maxf(arena_radius, 0.0)

func _setup_construction_area() -> void:
	construction_area = get_tree().current_scene.get_node_or_null("ConstructionPlayerArea") as Area2D
	if construction_area == null:
		push_warning("Player has no ConstructionPlayerArea; sentinel placement is disabled.")
		return
	var collision_shape := construction_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		push_warning("ConstructionPlayerArea needs a CollisionShape2D to define its buildable area.")
		return
	var polygon := _polygon_for_shape(collision_shape.shape)
	if polygon.is_empty():
		push_warning("ConstructionPlayerArea uses a shape that has no placement preview renderer.")
		return
	construction_area_overlay = Polygon2D.new()
	construction_area_overlay.name = "ConstructionAreaPreview"
	construction_area_overlay.polygon = polygon
	construction_area_overlay.color = Color(1.0, 1.0, 1.0, 0.24)
	construction_area_overlay.z_index = 50
	construction_area_overlay.visible = false
	collision_shape.add_child(construction_area_overlay)
	construction_area_outline = CONSTRUCTION_AREA_OUTLINE_SCRIPT.new() as Node2D
	construction_area_outline.name = "ConstructionAreaDashedBorder"
	construction_area_outline.z_index = 51
	construction_area_outline.call("set_outline", polygon)
	construction_area_outline.visible = false
	collision_shape.add_child(construction_area_outline)
	if collision_shape.shape is RectangleShape2D:
		var rounded_shape := ConvexPolygonShape2D.new()
		rounded_shape.points = polygon
		collision_shape.shape = rounded_shape

func _polygon_for_shape(shape: Shape2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		for index in range(96):
			var angle := TAU * float(index) / 96.0
			points.append(Vector2(cos(angle), sin(angle)) * circle.radius)
	elif shape is RectangleShape2D:
		points = _rounded_rectangle_polygon((shape as RectangleShape2D).size, construction_corner_radius)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var top_center := -capsule.height * 0.5 + capsule.radius
		var bottom_center := capsule.height * 0.5 - capsule.radius
		for index in range(33):
			var angle := PI + PI * float(index) / 32.0
			points.append(Vector2(cos(angle), sin(angle)) * capsule.radius + Vector2(0.0, top_center))
		for index in range(33):
			var angle := PI * float(index) / 32.0
			points.append(Vector2(cos(angle), sin(angle)) * capsule.radius + Vector2(0.0, bottom_center))
	elif shape is ConvexPolygonShape2D:
		points = (shape as ConvexPolygonShape2D).points
	return points

func _rounded_rectangle_polygon(size: Vector2, radius: float) -> PackedVector2Array:
	var half_size := size * 0.5
	var corner_radius := clampf(radius, 0.0, minf(half_size.x, half_size.y))
	var points := PackedVector2Array()
	var corner_data := [
		[Vector2(-half_size.x + corner_radius, -half_size.y + corner_radius), PI],
		[Vector2(half_size.x - corner_radius, -half_size.y + corner_radius), PI * 1.5],
		[Vector2(half_size.x - corner_radius, half_size.y - corner_radius), 0.0],
		[Vector2(-half_size.x + corner_radius, half_size.y - corner_radius), PI * 0.5],
	]
	for corner in corner_data:
		var center: Vector2 = corner[0]
		var start_angle: float = corner[1]
		for point_index in range(7):
			var angle := start_angle + PI * 0.5 * float(point_index) / 6.0
			points.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)
	return points

func _set_construction_area_visible(is_visible: bool) -> void:
	if is_instance_valid(construction_area_overlay):
		construction_area_overlay.visible = is_visible
	if is_instance_valid(construction_area_outline):
		construction_area_outline.visible = is_visible

func _update_sentinel_placement_validity() -> void:
	if not is_instance_valid(sentinel_preview):
		return
	var is_valid := _is_position_inside_construction_area(sentinel_preview.global_position)
	sentinel_preview.set_placement_valid(is_valid)

func _is_position_inside_construction_area(world_position: Vector2) -> bool:
	if not is_instance_valid(construction_area) or not is_instance_valid(construction_area_overlay):
		return false
	var world_polygon := PackedVector2Array()
	for point in construction_area_overlay.polygon:
		world_polygon.append(construction_area_overlay.to_global(point))
	return Geometry2D.is_point_in_polygon(world_position, world_polygon)

func _cancel_sentinel_placement() -> void:
	if is_instance_valid(sentinel_preview):
		sentinel_preview.queue_free()
		sentinel_preview = null
	_set_construction_area_visible(false)

func _clamp_to_arena() -> void:
	if arena_radius <= 0.0:
		return
	var offset := global_position - arena_center
	if offset.length_squared() <= arena_radius * arena_radius:
		return
	var outward := offset.normalized()
	global_position = arena_center + outward * arena_radius
	var outward_speed := velocity.dot(outward)
	if outward_speed > 0.0:
		velocity -= outward * outward_speed

func _start_sentinel_placement() -> void:
	if is_instance_valid(sentinel_preview):
		_cancel_sentinel_placement()
		return
	sentinel_preview = sentinel_scene.instantiate() as SentinelLevel1Weapon
	get_tree().current_scene.add_child(sentinel_preview)
	sentinel_preview.start_placement_preview()
	sentinel_preview.global_position = get_global_mouse_position()
	_set_construction_area_visible(true)
	_update_sentinel_placement_validity()

func _update_tree_sort_order() -> void:
	var player_feet_y := global_position.y
	var player_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_collision:
		player_feet_y += player_collision.position.y
		if player_collision.shape is CapsuleShape2D:
			player_feet_y += (player_collision.shape as CapsuleShape2D).height * 0.5
		elif player_collision.shape is RectangleShape2D:
			player_feet_y += (player_collision.shape as RectangleShape2D).size.y * 0.5
	# Use the same world-depth scale as enemies and trees so all three sort
	# consistently, even when an orc moves behind a tree.
	z_index = _depth_sort_index(player_feet_y)

	for node in get_tree().get_nodes_in_group("harvestable_trees"):
		if not is_instance_valid(node):
			continue
		var tree := node as HarvestableTree
		var tree_base_y := tree.global_position.y
		tree.z_index = _depth_sort_index(tree_base_y)
		tree.tree_sprite.z_index = 0
		tree.stump_sprite.z_index = 0
		var character_is_behind_tree := global_position.distance_to(tree.global_position) <= TREE_OCCLUSION_RADIUS and player_feet_y < tree_base_y
		for enemy_node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy_node) or not enemy_node is Orc1Enemy:
				continue
			var enemy := enemy_node as Orc1Enemy
			var enemy_feet_y := enemy.get_feet_y()
			if enemy.global_position.distance_to(tree.global_position) <= TREE_OCCLUSION_RADIUS and enemy_feet_y < tree_base_y:
				character_is_behind_tree = true
		var tree_modulate := tree.tree_sprite.modulate
		tree_modulate.a = TREE_OCCLUDED_ALPHA if character_is_behind_tree else 1.0
		tree.tree_sprite.modulate = tree_modulate

	for node in get_tree().get_nodes_in_group("harvestable_gold"):
		if not is_instance_valid(node):
			continue
		var gold := node as HarvestableGold
		var gold_base_position := gold.solid_collision.global_position
		var player_is_near_gold := global_position.distance_to(gold_base_position) <= TREE_OCCLUSION_RADIUS
		var player_is_behind_gold := player_feet_y < gold_base_position.y
		gold.gold_sprite.z_index = 2 if player_is_behind_gold else 0
		var gold_modulate := gold.gold_sprite.modulate
		gold_modulate.a = TREE_OCCLUDED_ALPHA if player_is_behind_gold and player_is_near_gold else 1.0
		gold.gold_sprite.modulate = gold_modulate

func _depth_sort_index(feet_y: float) -> int:
	return clampi(roundi(feet_y * 0.5) + DEPTH_SORT_OFFSET, -4096, 4096)

func _update_animation(direction: Vector2, sprinting: bool) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_interacting = false

	if is_interacting:
		return

	if direction.is_zero_approx():
		animated_sprite.speed_scale = 1.0
		_play_if_needed(IDLE_ANIMATIONS[held_item])
	else:
		animated_sprite.speed_scale = sprint_animation_speed_scale if sprinting else 1.0
		_play_if_needed(MOVE_ANIMATIONS[held_item])

func _start_interaction() -> void:
	var action_animation: String = ACTION_ANIMATIONS.get(held_item, "")
	if action_animation.is_empty():
		return
	is_interacting = true
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(action_animation)

func _harvest_tree_in_front() -> void:
	var facing := Vector2.LEFT if facing_left else Vector2.RIGHT
	var best_tree: HarvestableTree
	var best_distance := 60.0
	var player_feet_y := global_position.y
	var player_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_collision:
		player_feet_y += player_collision.position.y
		if player_collision.shape is CapsuleShape2D:
			player_feet_y += (player_collision.shape as CapsuleShape2D).height * 0.5
		elif player_collision.shape is RectangleShape2D:
			player_feet_y += (player_collision.shape as RectangleShape2D).size.y * 0.5
	const SIDE_HIT_VERTICAL_TOLERANCE := 24.0
	for node in get_tree().get_nodes_in_group("harvestable_trees"):
		if not is_instance_valid(node) or node.harvested:
			continue
		var offset: Vector2 = node.global_position - global_position
		var distance := offset.length()
		# Align the player's feet with the tree base so attacks from above or
		# below are rejected even when the player is diagonally nearby.
		var feet_to_tree_base := absf(player_feet_y - node.global_position.y)
		if distance > best_distance or offset.dot(facing) <= 0.0 or feet_to_tree_base > SIDE_HIT_VERTICAL_TOLERANCE:
			continue
		best_tree = node
		best_distance = distance
	if best_tree:
		best_tree.harvest()

func _mine_gold_in_front() -> void:
	var facing := Vector2.LEFT if facing_left else Vector2.RIGHT
	var best_gold: HarvestableGold
	var best_distance := 60.0
	var player_feet_y := global_position.y
	var player_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_collision:
		player_feet_y += player_collision.position.y
		if player_collision.shape is CapsuleShape2D:
			player_feet_y += (player_collision.shape as CapsuleShape2D).height * 0.5
		elif player_collision.shape is RectangleShape2D:
			player_feet_y += (player_collision.shape as RectangleShape2D).size.y * 0.5
	const SIDE_HIT_VERTICAL_TOLERANCE := 24.0
	for node in get_tree().get_nodes_in_group("harvestable_gold"):
		if not is_instance_valid(node):
			continue
		var gold := node as HarvestableGold
		if gold.mined:
			continue
		var offset: Vector2 = gold.global_position - global_position
		var distance := offset.length()
		var feet_to_gold := absf(player_feet_y - gold.global_position.y)
		if distance > best_distance or offset.dot(facing) <= 0.0 or feet_to_gold > SIDE_HIT_VERTICAL_TOLERANCE:
			continue
		best_gold = gold
		best_distance = distance
	if best_gold:
		best_gold.mine()

func _on_animation_finished() -> void:
	if is_interacting:
		if held_item == HeldItem.AXE and animated_sprite.animation == ACTION_ANIMATIONS[HeldItem.AXE]:
			_harvest_tree_in_front()
		elif held_item == HeldItem.PICKAXE and animated_sprite.animation == ACTION_ANIMATIONS[HeldItem.PICKAXE]:
			_mine_gold_in_front()
		is_interacting = false

func _play_if_needed(animation_name: String) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
