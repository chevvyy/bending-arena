extends CanvasLayer
## Shows controls and a frame counter. Replace with HP and chi bars later.

@onready var fps_label: Label = $FpsLabel


func _process(_delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
