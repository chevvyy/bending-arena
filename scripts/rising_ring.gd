extends MeshInstance3D
## A glowing ring that rises up the body and fades, again and again (Healing Water).

@export var period := 1.2
@export var offset := 0.0
@export var height := 1.9

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var t := fmod(_time + offset, period) / period
	position.y = t * height
	var s := 1.0 - 0.35 * t
	scale = Vector3(s, 1.0, s)
	transparency = t
