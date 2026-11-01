extends Area2D
class_name HarvestableTree

@export var wood_drop_count := 4
@export var hits_to_fell := 6

@onready var tree_sprite: Sprite2D = $TreeSprite
@onready var stump_sprite: Sprite2D = $StumpSprite

var harvested := false
var hits_received := 0
var shake_tween: Tween
var tree_sprite_rest_position := Vector2.ZERO

func _ready() -> void:
	add_to_group("harvestable_trees")
	tree_sprite_rest_position = tree_sprite.position
	tree_sprite.visible = true
	stump_sprite.visible = false

func harvest() -> void:
	if harvested:
		return
	hits_received += 1
	_shake_tree()
	if hits_received < hits_to_fell:
		return
	harvested = true
	tree_sprite.visible = false
	stump_sprite.visible = true
	$CollisionShape2D.set_deferred("disabled", true)
	_drop_wood()

func _shake_tree() -> void:
	if shake_tween and shake_tween.is_running():
		shake_tween.kill()
	tree_sprite.position = tree_sprite_rest_position
	shake_tween = create_tween()
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position + Vector2(2.0, 0.0), 0.02)
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position + Vector2(-2.0, 0.0), 0.03)
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position + Vector2(1.0, 0.0), 0.025)
	shake_tween.tween_property(tree_sprite, "position", tree_sprite_rest_position, 0.02)

func _drop_wood() -> void:
	var wood_scene := preload("res://Entities/wood_resource.tscn")
	for index in wood_drop_count:
		var wood := wood_scene.instantiate()
		get_tree().current_scene.add_child(wood)
		wood.global_position = global_position + Vector2((index - (wood_drop_count - 1) * 0.5) * 20.0, 4.0)
