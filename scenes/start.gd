extends Control

const SAVE_FILE_PATH = "user://player_data.cfg"

func _ready() -> void:
	_check_player_exists()

func _check_player_exists() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE_PATH)
	
	if err == OK:
		# 玩家数据已存在，跳转到基地
		print("[Start] 检测到玩家数据，进入基地")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/GameStart.tscn")
	else:
		# 首次进入，创建新角色
		print("[Start] 未检测到玩家数据，创建新角色")
		get_tree().call_deferred("change_scene_to_file", "res://scenes/new_player.tscn")
