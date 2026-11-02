extends CharacterBody2D
class_name Orc1Enemy

@export var move_speed := 90.0
@export var attack_range := 42.0
@export var side_attack_vertical_tolerance := 12.0
@export var attack_damage := 10.0
@export var attack_cooldown := 0.7
@export var avoidance_probe_distance := 72.0

const DEPTH_SORT_OFFSET := 1030

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: PlayerController
var is_attacking := false
var attack_cooldown_timer := 0.0
var stuck_timer := 0.0
var forced_avoidance_direction := Vector2.ZERO
var forced_avoidance_timer := 0.0

func _ready() -> void:
	add_to_group("enemies")
	z_index = _depth_sort_index(_get_feet_y(self))
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play("Idle")
	for animation_name in ["Attack", "Hurt", "Death"]:
		animated_sprite.sprite_frames.set_animation_loop(animation_name, false)

func _physics_process(delta: float) -> void:
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	z_index = _depth_sort_index(_get_feet_y(self))
	if not is_instance_valid(player):
		player = _find_player()
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		_play_if_needed("Idle")
		return

	var to_player := player.global_position - global_position
	var can_attack := to_player.length() <= attack_range and _can_attack_from_position() and _has_clear_path_to_player()
	if absf(to_player.x) > 0.01:
		animated_sprite.flip_h = to_player.x < 0.0

	# Cancel the swing and reposition if the player escapes or moves below the orc.
	if is_attacking and not can_attack:
		is_attacking = false
		animated_sprite.play("Run")

	if can_attack:
		velocity = Vector2.ZERO
		move_and_slide()
		if not is_attacking and attack_cooldown_timer <= 0.0:
			is_attacking = true
			animated_sprite.play("Attack")
		elif not is_attacking:
			_play_if_needed("Idle")
		return

	var desired_direction := to_player.normalized()
	forced_avoidance_timer = maxf(forced_avoidance_timer - delta, 0.0)
	var steering_direction := _get_steering_direction(desired_direction)
	if forced_avoidance_timer > 0.0:
		steering_direction = forced_avoidance_direction
	velocity = steering_direction * move_speed
	var previous_position := global_position
	move_and_slide()
	_update_stuck_recovery(previous_position, desired_direction, delta)
	_play_if_needed("Run")

func _update_stuck_recovery(previous_position: Vector2, desired_direction: Vector2, delta: float) -> void:
	var made_progress := (global_position - previous_position).dot(desired_direction)
	var expected_progress := move_speed * delta * 0.25
	if get_slide_collision_count() > 0 and made_progress < expected_progress:
		stuck_timer += delta
	else:
		stuck_timer = 0.0

	if stuck_timer < 0.12 or forced_avoidance_timer > 0.0:
		return

	var space := get_world_2d().direct_space_state
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(player):
		excluded.append(player.get_rid())
	var origin := global_position
	var step_left := desired_direction.rotated(PI * 0.5)
	var step_right := desired_direction.rotated(-PI * 0.5)
	var left_clearance := _get_ray_clearance(space, origin, step_left, excluded)
	var right_clearance := _get_ray_clearance(space, origin, step_right, excluded)
	forced_avoidance_direction = step_left if left_clearance >= right_clearance else step_right
	forced_avoidance_timer = 0.65
	stuck_timer = 0.0

func _get_steering_direction(desired_direction: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(player):
		excluded.append(player.get_rid())
	var origin := global_position
	var best_direction := desired_direction
	var best_score := _get_ray_clearance(space, origin, desired_direction, excluded) + avoidance_probe_distance * 0.25
	if best_score >= avoidance_probe_distance + avoidance_probe_distance * 0.25:
		return desired_direction

	# Try both sides of the direct route. Prefer open paths that still make
	# progress toward the player, which lets the orc go around tree trunks.
	for angle in [0.785398, -0.785398, 1.308997, -1.308997, 2.094395, -2.094395]:
		var candidate := desired_direction.rotated(angle)
		var clearance := _get_ray_clearance(space, origin, candidate, excluded)
		var score := clearance + candidate.dot(desired_direction) * avoidance_probe_distance * 0.25
		if score > best_score:
			best_score = score
			best_direction = candidate
	return best_direction

func _get_ray_clearance(space: PhysicsDirectSpaceState2D, origin: Vector2, direction: Vector2, excluded: Array[RID]) -> float:
	var query := PhysicsRayQueryParameters2D.create(
		origin,
		origin + direction * avoidance_probe_distance,
		collision_mask,
		excluded
	)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return avoidance_probe_distance
	return origin.distance_to(hit["position"])

func _has_clear_path_to_player() -> bool:
	if not is_instance_valid(player):
		return false
	var origin := global_position
	var target := player.global_position
	var orc_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if orc_collision:
		origin = orc_collision.global_position
	if player_collision:
		target = player_collision.global_position
	var to_target := target - origin
	if to_target.length() <= 0.0:
		return true
	var excluded: Array[RID] = [get_rid(), player.get_rid()]
	var clearance := _get_ray_clearance(get_world_2d().direct_space_state, origin, to_target.normalized(), excluded)
	return clearance >= to_target.length() - 4.0

func _find_player() -> PlayerController:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerController:
			var found_player := node as PlayerController
			# Keep the two CharacterBody2D nodes from pushing or snagging each
			# other while the player is dodging through the orc.
			add_collision_exception_with(found_player)
			return found_player
	return null

func _can_attack_from_position() -> bool:
	if not is_instance_valid(player):
		return false
	var orc_feet_y := _get_feet_y(self)
	var player_feet_y := _get_feet_y(player)
	# Godot's Y axis grows downward. A small tolerance allows attacks from
	# beside the player while preventing attacks when the orc is clearly below.
	return orc_feet_y <= player_feet_y + side_attack_vertical_tolerance

func _get_feet_y(body: CharacterBody2D) -> float:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return body.global_position.y
	var feet_y := collision.global_position.y
	if collision.shape is RectangleShape2D:
		feet_y += (collision.shape as RectangleShape2D).size.y * 0.5
	elif collision.shape is CapsuleShape2D:
		feet_y += (collision.shape as CapsuleShape2D).height * 0.5
	return feet_y

func get_feet_y() -> float:
	return _get_feet_y(self)

func _depth_sort_index(feet_y: float) -> int:
	return clampi(roundi(feet_y * 0.5) + DEPTH_SORT_OFFSET, -4096, 4096)

func _on_animation_finished() -> void:
	if animated_sprite.animation != "Attack":
		return
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range and _can_attack_from_position():
		player.stats.take_damage(attack_damage)
	is_attacking = false
	attack_cooldown_timer = attack_cooldown
	_play_if_needed("Idle")

func _play_if_needed(animation_name: String) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
