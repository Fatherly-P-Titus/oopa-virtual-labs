extends Control
## Splash — brand image background, then main menu.

@export var hold_seconds: float = 3.0
@export var auto_continue: bool = true

const SPLASH_PATH := "res://assets/brand/oopa_splash.png"

@onready var _progress: ProgressBar = $Overlay/VBox/Progress
@onready var _status: Label = $Overlay/VBox/Status
@onready var _bg: TextureRect = $BackgroundImage
@onready var _fill: ColorRect = $Fill

var _t: float = 0.0
var _done: bool = false

func _ready() -> void:
	_progress.max_value = hold_seconds
	_progress.value = 0.0
	# Startup is not a staged loading process; keep the timed progress bar hidden.
	_progress.visible = false
	_status.text = "EXPLORE  ·  EXPERIMENT  ·  DISCOVER"
	# Defer one frame so TextureRect has final size
	call_deferred("_apply_splash_texture")

func _apply_splash_texture() -> void:
	if _bg == null:
		push_error("Splash: BackgroundImage node missing")
		return

	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tex: Texture2D = _load_texture(SPLASH_PATH)
	if tex == null:
		push_warning("Splash: texture load failed for %s" % SPLASH_PATH)
		# Visible fallback so we know code ran
		_fill.color = Color("#b22222")
		return

	_bg.texture = tex
	_bg.visible = true
	_bg.modulate = Color(0.82, 0.91, 1.0, 0.18)
	# Keep white letterbox only if aspect leaves gaps; image should cover
	_fill.color = Color.WHITE
	print("Splash: texture OK %dx%d" % [tex.get_width(), tex.get_height()])

func _load_texture(path: String) -> Texture2D:
	# 1) Normal resource load (after import)
	if ResourceLoader.exists(path):
		var res: Variant = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
		if res is Texture2D:
			return res
		res = load(path)
		if res is Texture2D:
			return res

	# 2) Load file from disk via globalized path
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
		var img := Image.new()
		var err := OK
		if FileAccess.file_exists(abs_path):
			err = img.load(abs_path)
		else:
			err = img.load(path)
		if err != OK:
			# Godot 4.2+ API
			if img.has_method("load_from_file"):
				img = Image.load_from_file(abs_path)
				if img != null and not img.is_empty():
					return ImageTexture.create_from_image(img)
			push_warning("Splash: Image.load error %s on %s" % [str(err), abs_path])
			return null
		if not img.is_empty():
			return ImageTexture.create_from_image(img)

	return null

func _process(delta: float) -> void:
	if _done or not auto_continue:
		return
	_t += delta
	_progress.value = min(_t, hold_seconds)
	if _t >= hold_seconds:
		_finish()

func _on_continue_pressed() -> void:
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	SceneRouter.go_main_menu()
