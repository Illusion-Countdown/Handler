class_name ScreenFX
extends CanvasLayer
## 全屏后处理：暗角、扫描线、噪点、色差、受击闪红。

var rect: ColorRect
var mat: ShaderMaterial
var flash_t: float = 0.0
var flash_max: float = 1.0


func _ready() -> void:
	layer = 100
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1, 1, 1, 1)
	var sh: Shader = load("res://assets/shaders/screen.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)


func hit_flash(strength: float = 0.35, color: Color = Color(1.0, 0.25, 0.15)) -> void:
	flash_t = 0.18
	flash_max = strength
	mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))


func _process(delta: float) -> void:
	if flash_t > 0.0:
		flash_t = max(0.0, flash_t - delta)
		var f: float = flash_max * (flash_t / 0.18)
		mat.set_shader_parameter("flash", f)
	else:
		mat.set_shader_parameter("flash", 0.0)
