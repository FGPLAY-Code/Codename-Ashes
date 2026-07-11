extends Control

@onready var name_input: LineEdit = %NameInput
@onready var confirm_hint: Label = %ConfirmHint

var player_name: String = ""

func _ready() -> void:
	# 连接信号
	name_input.text_submitted.connect(_on_name_input_submitted)
	name_input.text_changed.connect(_on_name_changed)
	
	# 聚焦输入框
	name_input.grab_focus()
	
	# 初始状态
	confirm_hint.modulate = Color(1, 1, 1, 0)  # 初始隐藏

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and player_name.length() > 0:
		_create_player()

func _on_name_input_submitted(text: String) -> void:
	if text.strip_edges().length() > 0:
		_create_player()

func _on_name_changed(text: String) -> void:
	player_name = text.strip_edges()
	if player_name.length() > 0:
		# 显示确认提示
		var tween = create_tween()
		tween.tween_property(confirm_hint, "modulate", Color(1, 1, 1, 1), 0.3)
	else:
		# 隐藏确认提示
		var tween = create_tween()
		tween.tween_property(confirm_hint, "modulate", Color(1, 1, 1, 0), 0.3)

func _create_player() -> void:
	if player_name.length() == 0:
		return
	
	# 禁用输入
	name_input.editable = false
	
	# 保存玩家数据
	save_player_data()
	
	# 跳转到基地（由 GameStart 决定在线/离线模式）
	get_tree().change_scene_to_file("res://scenes/GameStart.tscn")

func save_player_data() -> void:
	var config = ConfigFile.new()
	
	# 创建新角色数据
	config.set_value("player", "name", player_name)
	config.set_value("player", "created", Time.get_datetime_string_from_system())
	config.set_value("player", "level", 1)
	config.set_value("player", "experience", 0)
	config.set_value("player", "cash", 0)  # 初始现金为0
	
	# 初始背包数据
	config.set_value("inventory", "slots", [])
	config.set_value("inventory", "capacity", 28)
	
	# 初始装备数据
	config.set_value("equipment", "head", null)
	config.set_value("equipment", "body", null)
	config.set_value("equipment", "backpack", null)
	config.set_value("equipment", "tactical", null)
	
	# 保存到文件
	config.save("user://player_data.cfg")
	print("玩家数据已保存: " + player_name)
