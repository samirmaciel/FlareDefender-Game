extends Area2D
class_name HarvestableGold

@export var gold_drop_count := 4
@export var hits_to_mine := 6

@onready var gold_sprite: Sprite2D = $Sprite2D
@onready var solid_collision: CollisionShape2D = $StaticBody2D/CollisionShape2D

var mined := false
var hits_received := 0
var shake_tween: Tween
var sprite_rest_position := Vector2.ZERO

func _ready() -> void:
	add_to_group("harvestable_gold")
	sprite_rest_position = gold_sprite.position

func mine() -> void:
	if mined:
		return
	hits_received += 1
	_shake_gold()
	if hits_received < hits_to_mine:
		return
	mined = true
	gold_sprite.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	solid_collision.set_deferred("disabled", true)
	_drop_gold()

func _shake_gold() -> void:
	if shake_tween and shake_tween.is_running():
		shake_tween.kill()
	gold_sprite.position = sprite_rest_position
	shake_tween = create_tween()
	shake_tween.tween_property(gold_sprite, "position", sprite_rest_position + Vector2(2.0, 0.0), 0.02)
	shake_tween.tween_property(gold_sprite, "position", sprite_rest_position + Vector2(-2.0, 0.0), 0.03)
	shake_tween.tween_property(gold_sprite, "position", sprite_rest_position + Vector2(1.0, 0.0), 0.025)
	shake_tween.tween_property(gold_sprite, "position", sprite_rest_position, 0.02)

func _drop_gold() -> void:
	var gold_scene := preload("res://Entities/gold_resource.tscn")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _index in gold_drop_count:
		var gold := gold_scene.instantiate()
		get_tree().current_scene.add_child(gold)
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(48.0, 72.0)
		var offset := Vector2.RIGHT.rotated(angle) * distance
		var start_position := global_position
		var landing_position := start_position + offset
		var arc_position := start_position + offset * 0.5 + Vector2.UP * 28.0
		gold.global_position = start_position
		var drop_tween := gold.create_tween()
		drop_tween.tween_property(gold, "global_position", arc_position, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		drop_tween.tween_property(gold, "global_position", landing_position, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
