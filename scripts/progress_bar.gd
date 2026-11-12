extends CanvasLayer

@onready var progress_bar = %ProgressBar
@onready var label = %Label
@onready var main_menu = get_node_or_null("../MainMenu")

var last_current := -1
var last_total := -1


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not LevelManager.progress_changed.is_connected(_on_progress_changed):
		LevelManager.progress_changed.connect(_on_progress_changed)
	_sync_visibility()
	_on_progress_changed(LevelManager.get_current_progress_value(), LevelManager.get_current_progress_total())


func _process(_delta):
	_sync_visibility()
	var cur = LevelManager.get_current_progress_value()
	var tot = LevelManager.get_current_progress_total()
	if cur != last_current or tot != last_total:
		_on_progress_changed(cur, tot)


func _on_progress_changed(current_index, total_count):
	last_current = int(current_index)
	last_total = int(total_count)

	if total_count <= 0 or current_index <= 0:
		progress_bar.value = 0.0
		return

	var percent = clampf(float(current_index) / float(total_count) * 100.0, 0.0, 100.0)
	progress_bar.value = percent


func _sync_visibility():
	visible = main_menu == null or not main_menu.visible
