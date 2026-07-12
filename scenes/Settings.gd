extends Control

var settings_popup: PanelContainer
var keybind_popup: PanelContainer
var gameplay_popup: PanelContainer
var master_volume_slider: HSlider
var sfx_volume_slider: HSlider
var resolution_option: OptionButton

const SAVE_FILE_PATH = "user://settings.cfg"

func _ready() -> void:
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close_settings()

func _on_open_settings() -> void:
	show_settings()

func show_settings() -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_create_settings_ui()
	_load_settings()

func close_settings() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _create_settings_ui() -> void:
	# 清除旧UI
	for child in get_children():
		child.queue_free()

	# 半透明背景
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	bg.gui_input.connect(_on_bg_click.bind())
	add_child(bg)

	# 主面板
	settings_popup = PanelContainer.new()
	settings_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_popup.offset_left = -200
	settings_popup.offset_top = -250
	settings_popup.offset_right = 200
	settings_popup.offset_bottom = 250
	add_child(settings_popup)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	panel_style.border_color = Color(0.2, 0.7, 0.5, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	settings_popup.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	settings_popup.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.5, 1))
	vbox.add_child(title)

	# 分隔线
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# 画面设置
	var graphics_label = Label.new()
	graphics_label.text = "画面"
	graphics_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	vbox.add_child(graphics_label)

	resolution_option = OptionButton.new()
	resolution_option.add_item("1280x720", 0)
	resolution_option.add_item("1920x1080", 1)
	resolution_option.add_item("2560x1440", 2)
	resolution_option.add_item("窗口模式", 3)
	resolution_option.item_selected.connect(_on_resolution_changed)
	vbox.add_child(resolution_option)

	# 分隔线
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# 声音设置
	var audio_label = Label.new()
	audio_label.text = "声音"
	audio_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	vbox.add_child(audio_label)

	# 主音量
	var master_row = HBoxContainer.new()
	vbox.add_child(master_row)

	var master_label = Label.new()
	master_label.text = "主音量"
	master_label.custom_minimum_size = Vector2(60, 0)
	master_row.add_child(master_label)

	master_volume_slider = HSlider.new()
	master_volume_slider.min_value = 0
	master_volume_slider.max_value = 100
	master_volume_slider.step = 1
	master_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	master_row.add_child(master_volume_slider)

	var master_value = Label.new()
	master_value.name = "MasterValue"
	master_value.text = "100%"
	master_value.custom_minimum_size = Vector2(50, 0)
	master_row.add_child(master_value)

	# 音效音量
	var sfx_row = HBoxContainer.new()
	vbox.add_child(sfx_row)

	var sfx_label = Label.new()
	sfx_label.text = "音效"
	sfx_label.custom_minimum_size = Vector2(60, 0)
	sfx_row.add_child(sfx_label)

	sfx_volume_slider = HSlider.new()
	sfx_volume_slider.min_value = 0
	sfx_volume_slider.max_value = 100
	sfx_volume_slider.step = 1
	sfx_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_row.add_child(sfx_volume_slider)

	var sfx_value = Label.new()
	sfx_value.name = "SFXValue"
	sfx_value.text = "100%"
	sfx_value.custom_minimum_size = Vector2(50, 0)
	sfx_row.add_child(sfx_value)

	# 分隔线
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# 按键介绍按钮
	var keybind_btn = Button.new()
	keybind_btn.text = "按键介绍"
	keybind_btn.pressed.connect(_show_keybind_popup)
	vbox.add_child(keybind_btn)

	# 游戏玩法按钮
	var gameplay_btn = Button.new()
	gameplay_btn.text = "游戏玩法"
	gameplay_btn.pressed.connect(_show_gameplay_popup)
	vbox.add_child(gameplay_btn)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "关闭 (ESC)"
	close_btn.pressed.connect(close_settings)
	vbox.add_child(close_btn)

func _on_bg_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_settings()

func _on_resolution_changed(index: int) -> void:
	var resolutions = [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440)
	]
	if index < resolutions.size():
		DisplayServer.window_set_size(resolutions[index])
	_save_settings()

func _on_master_volume_changed(value: float) -> void:
	var db_value = linear_to_db(value / 100.0) if value > 0 else -80
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_value)
	
	var master_value = settings_popup.find_child("MasterValue", true, false)
	if master_value:
		master_value.text = str(int(value)) + "%"
	_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	# 枪声使用 Master 总线
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		# 音效音量相对于主音量
		var master_val = master_volume_slider.value if master_volume_slider else 100
		var combined = (value / 100.0) * (master_val / 100.0)
		var db_value = linear_to_db(combined) if combined > 0 else -80
		AudioServer.set_bus_volume_db(master_bus, db_value)
	
	var sfx_value = settings_popup.find_child("SFXValue", true, false)
	if sfx_value:
		sfx_value.text = str(int(value)) + "%"
	_save_settings()

func _show_keybind_popup() -> void:
	if keybind_popup:
		keybind_popup.queue_free()
	if gameplay_popup:
		gameplay_popup.queue_free()

	keybind_popup = PanelContainer.new()
	keybind_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	keybind_popup.offset_left = -250
	keybind_popup.offset_top = -300
	keybind_popup.offset_right = 250
	keybind_popup.offset_bottom = 300
	add_child(keybind_popup)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	panel_style.border_color = Color(0.2, 0.7, 0.5, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	keybind_popup.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	keybind_popup.add_child(vbox)

	var title = Label.new()
	title.text = "按键介绍"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.5, 1))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var keybinds = [
		["移动", "WASD"],
		["跳跃", "空格"],
		["冲刺", "Shift"],
		["蹲下", "C"],
		["左探头", "Q"],
		["右探头", "E"],
		["射击", "鼠标左键"],
		["瞄准", "鼠标右键"],
		["换弹", "R"],
		["切换射击模式", "B"],
		["打开背包", "Tab"],
		["搜索/拾取", "F"],
		["设置", "ESC"],
	]

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(scroll_vbox)

	for bind in keybinds:
		var row = HBoxContainer.new()
		scroll_vbox.add_child(row)

		var key_label = Label.new()
		key_label.text = bind[0]
		key_label.custom_minimum_size = Vector2(100, 0)
		key_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		row.add_child(key_label)

		var value_label = Label.new()
		value_label.text = bind[1]
		value_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
		row.add_child(value_label)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close_keybind_popup)
	vbox.add_child(close_btn)

func _close_keybind_popup() -> void:
	if keybind_popup:
		keybind_popup.queue_free()
		keybind_popup = null

func _show_gameplay_popup() -> void:
	if keybind_popup:
		keybind_popup.queue_free()
	if gameplay_popup:
		gameplay_popup.queue_free()

	gameplay_popup = PanelContainer.new()
	gameplay_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gameplay_popup.offset_left = -300
	gameplay_popup.offset_top = -350
	gameplay_popup.offset_right = 300
	gameplay_popup.offset_bottom = 350
	add_child(gameplay_popup)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	panel_style.border_color = Color(0.2, 0.7, 0.5, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	gameplay_popup.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	gameplay_popup.add_child(vbox)

	var title = Label.new()
	title.text = "游戏玩法"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.5, 1))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(scroll_vbox)

	var sections = [
		{
			"title": "游戏目标",
			"content": "在废墟战场上生存，击杀敌人，收集物资，尽可能获得更高的撤离收益。"
		},
		{
			"title": "移动操作",
			"content": "WASD移动，空格跳跃，Shift冲刺，C蹲下。Q/E探头可以探出墙角观察敌人。"
		},
		{
			"title": "武器操作",
			"content": "左键射击，右键瞄准，B键切换全自动/单发模式。蹲下射击更稳定。"
		},
		{
			"title": "物资收集",
			"content": "F键搜索弹药箱获取弹药。击杀敌人掉落储物箱，可获得工艺藏品。"
		},
		{
			"title": "撤离系统",
			"content": "找到地图上的撤离点，按住E键开始撤离。撤离成功后，背包物资将转化为收益。"
		},
		{
			"title": "工艺藏品",
			"content": "击杀敌人有几率掉落储物箱，开启可获得工艺藏品。不同品质有不同效果，可在基地出售换取金币。"
		},
	]

	for section in sections:
		var section_label = Label.new()
		section_label.text = section["title"]
		section_label.add_theme_font_size_override("font_size", 16)
		section_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))
		scroll_vbox.add_child(section_label)

		var content_label = Label.new()
		content_label.text = section["content"]
		content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content_label.add_theme_font_size_override("font_size", 14)
		content_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		scroll_vbox.add_child(content_label)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close_gameplay_popup)
	vbox.add_child(close_btn)

func _close_gameplay_popup() -> void:
	if gameplay_popup:
		gameplay_popup.queue_free()
		gameplay_popup = null

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE_PATH)
	
	if err == OK:
		var master_vol = config.get_value("audio", "master_volume", 100)
		var sfx_vol = config.get_value("audio", "sfx_volume", 100)
		
		if master_volume_slider:
			master_volume_slider.value = master_vol
		if sfx_volume_slider:
			sfx_volume_slider.value = sfx_vol
		
		# 应用音量
		var db_val = linear_to_db(master_vol / 100.0) if master_vol > 0 else -80
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_val)

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", int(master_volume_slider.value) if master_volume_slider else 100)
	config.set_value("audio", "sfx_volume", int(sfx_volume_slider.value) if sfx_volume_slider else 100)
	config.save(SAVE_FILE_PATH)
