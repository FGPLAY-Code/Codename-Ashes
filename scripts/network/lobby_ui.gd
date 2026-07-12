## LobbyUI.gd
## 游戏大厅界面
## 显示房间列表、创建/加入房间、准备开始

extends Control

# ================================================================
# 节点引用（需要在场景中创建对应节点）
# ================================================================
@onready var room_list: ItemList = $VBox/RoomList
@onready var create_btn: Button  = $VBox/HBox/CreateBtn
@onready var join_btn: Button    = $VBox/HBox/JoinBtn
@onready var refresh_btn: Button = $VBox/HBox/RefreshBtn
@onready var room_panel: PanelContainer = $RoomPanel  # 进入房间后的面板
@onready var player_list: VBoxContainer = $RoomPanel/VBox/PlayerList
@onready var ready_btn: Button   = $RoomPanel/VBox/ReadyBtn
@onready var leave_btn: Button   = $RoomPanel/VBox/LeaveBtn
@onready var room_id_label: Label = $RoomPanel/VBox/RoomIdLabel
@onready var chat_log: RichTextLabel = $RoomPanel/VBox/ChatLog
@onready var chat_input: LineEdit = $RoomPanel/VBox/ChatInput

var _in_room: bool = false
var _room_players: Dictionary = {}  # socket_id -> player info

# ================================================================

func _ready() -> void:
	create_btn.pressed.connect(_on_create_room)
	join_btn.pressed.connect(_on_join_room)
	refresh_btn.pressed.connect(_on_refresh)
	ready_btn.pressed.connect(_on_toggle_ready)
	leave_btn.pressed.connect(_on_leave_room)
	chat_input.text_submitted.connect(_on_chat_submit)

	NetworkManager.room_list_updated.connect(_on_room_list_updated)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.room_join_failed.connect(_on_room_join_failed)
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.player_joined_room.connect(_on_player_joined)
	NetworkManager.player_left_room.connect(_on_player_left)
	NetworkManager.player_ready_changed.connect(_on_ready_changed)
	NetworkManager.game_started.connect(_on_game_start)
	NetworkManager.chat_message_received.connect(_on_chat_received)

	room_panel.visible = false
	NetworkManager.get_room_list()

# ================================================================
# 房间列表
# ================================================================

func _on_refresh() -> void:
	NetworkManager.get_room_list()

func _on_room_list_updated(rooms: Array) -> void:
	room_list.clear()
	for r in rooms:
		var text := "[%s] %s (%d/%d人)" % [
			r.get("map", "?"),
			r.get("host", "?"),
			r.get("player_count", 0),
			r.get("max_players", 4),
		]
		room_list.add_item(text)
		room_list.set_item_metadata(room_list.item_count - 1, r.get("id", ""))

# ================================================================
# 创建/加入房间
# ================================================================

func _on_create_room() -> void:
	NetworkManager.create_room("oasis_01")

func _on_join_room() -> void:
	var selected := room_list.get_selected_items()
	if selected.is_empty():
		return
	var room_id: String = room_list.get_item_metadata(selected[0])
	NetworkManager.join_room(room_id)

func _on_room_created(room_id: String) -> void:
	print("[LOBBY] Room created: ", room_id)
	_enter_room_ui(room_id, [])

func _on_room_joined(data: Dictionary) -> void:
	var room_id: String = data.get("room_id", "")
	var players: Array = data.get("players", [])
	_enter_room_ui(room_id, players)

func _on_room_join_failed(error: String) -> void:
	print("[LOBBY] Join failed: ", error)
	# TODO: 显示错误提示

func _enter_room_ui(room_id: String, players: Array) -> void:
	_in_room = true
	room_panel.visible = true
	room_id_label.text = "房间: " + room_id
	_room_players.clear()
	for p in players:
		_room_players[p.get("socket_id", "")] = p
	_refresh_player_list()

# ================================================================
# 房间内玩家管理
# ================================================================

func _on_player_joined(data: Dictionary) -> void:
	if not _in_room:
		return
	var sid: String = data.get("socket_id", "")
	_room_players[sid] = data
	_refresh_player_list()
	_append_chat("系统", data.get("name", "?") + " 加入了房间")

func _on_player_left(data: Dictionary) -> void:
	var sid: String = data.get("socket_id", "")
	_room_players.erase(sid)
	_refresh_player_list()
	_append_chat("系统", data.get("name", "?") + " 离开了房间")

func _on_ready_changed(data: Dictionary) -> void:
	var sid: String = data.get("socket_id", "")
	if _room_players.has(sid):
		_room_players[sid]["ready"] = data.get("ready", false)
		_refresh_player_list()

func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for sid in _room_players:
		var p = _room_players[sid]
		var label := Label.new()
		var ready_text := "[准备]" if p.get("ready", false) else "[等待]"
		label.text = "%s %s" % [ready_text, p.get("name", "?")]
		player_list.add_child(label)

# ================================================================
# 准备/离开
# ================================================================

func _on_toggle_ready() -> void:
	NetworkManager.toggle_ready()
	var is_ready := ready_btn.text == "取消准备"
	ready_btn.text = "取消准备" if not is_ready else "准备"

func _on_leave_room() -> void:
	NetworkManager.leave_room()
	_in_room = false
	_room_players.clear()
	room_panel.visible = false
	NetworkManager.get_room_list()

# ================================================================
# 游戏开始
# ================================================================

func _on_game_start(data: Dictionary) -> void:
	# 进入游戏场景
	# 地图名可以根据 data.get("map") 选择不同场景
	get_tree().change_scene_to_file("res://scenes/AshRavine.tscn")

# ================================================================
# 聊天
# ================================================================

func _on_chat_submit(text: String) -> void:
	if text.strip_edges() == "":
		return
	NetworkManager.send_chat(text)
	chat_input.clear()

func _on_chat_received(data: Dictionary) -> void:
	_append_chat(data.get("sender", "?"), data.get("text", ""))

func _append_chat(sender: String, text: String) -> void:
	chat_log.append_text("[b]%s[/b]: %s\n" % [sender, text])
	# 滚动到底部
	await get_tree().process_frame
	chat_log.scroll_to_line(chat_log.get_line_count() - 1)
