extends CanvasLayer

@onready var progress_bar = %ProgressBar
@onready var label = %Label
@onready var main_menu = get_node_or_null("../MainMenu")


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	LevelManager.progress_changed.connect(_on_progress_changed)
	_sync_visibility()


func _process(_delta):
	_sync_visibility()


func _on_progress_changed(current_index, total_count):
	if total_count <= 0:
		progress_bar.value = 0
		#label.text = "0%"
		return

	var percent = float(current_index) / float(total_count) * 100.0
	progress_bar.value = percent
	#label.text = " %d%%" % int(percent)


func _sync_visibility():
	visible = main_menu == null or not main_menu.visible
