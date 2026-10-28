extends Node
class_name PlayerStats

signal stamina_changed(current: float, maximum: float)

@export var max_stamina := 100.0
@export var stamina_drain_per_second := 30.0
@export var stamina_recovery_per_second := 20.0
@export var recovery_delay := 0.75

var stamina: float
var recovery_timer := 0.0

func _ready() -> void:
	stamina = max_stamina

func can_sprint() -> bool:
	return stamina > 0.0

func update_stamina(sprinting: bool, delta: float) -> void:
	var previous_stamina := stamina
	if sprinting and can_sprint():
		stamina = maxf(stamina - stamina_drain_per_second * delta, 0.0)
		recovery_timer = recovery_delay
	else:
		recovery_timer = maxf(recovery_timer - delta, 0.0)
		if recovery_timer == 0.0:
			stamina = minf(stamina + stamina_recovery_per_second * delta, max_stamina)

	if not is_equal_approx(stamina, previous_stamina):
		stamina_changed.emit(stamina, max_stamina)
