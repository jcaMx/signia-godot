#extends Node
#
#@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
#@onready var correct_sfx: AudioStreamPlayer = $CorrectSFX
#@onready var wrong_sfx: AudioStreamPlayer = $WrongSFX
#@onready var button_sfx: AudioStreamPlayer = $ButtonSFX
#@onready var chapter_complete_sfx: AudioStreamPlayer = $ChapterCompleteSFX
#
#
#func play_bgm(stream: AudioStream):
	#if bgm_player.stream == stream and bgm_player.playing:
		#return
#
	#bgm_player.stream = stream
	#bgm_player.play()
#
#
#func stop_bgm():
	#bgm_player.stop()
#
#
#func play_correct():
	#correct_sfx.play()
#
#
#func play_wrong():
	#wrong_sfx.play()
#
#
#func play_button():
	#button_sfx.play()
#
#
#func play_chapter_complete():
	#chapter_complete_sfx.play()
