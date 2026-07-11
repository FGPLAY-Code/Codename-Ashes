# ================================================================
# NetworkManager - 原生 WebSocket 客户端（/ws 端点）
# 禁止使用 Socket.IO 协议
# ================================================================

extends Node

# ================================================================
# 信号定义
# ================================================================
signal connected_to_server
signal disconnected_from_server
signal room_list_updated(rooms: Array)
signal room_created(room_id: String)
signal room_joined(data: Dictionary)
signal room_join_failed(message: String)
signal player_joined_room(data: Dictionary)
signal player_left_room(data: Dictionary)
signal player_ready_changed(data: Dictionary)
signal game_started(data: Dictionary)
signal game_ended(data: Dictionary)
signal remote_player_state_received(data: Dictionary)
signal take_damage_received(data: Dictionary)
signal hit_confirmed(data: Dictionary)
signal player_killed(data: Dictionary)
signal player_extracted(data: Dictionary)
signal chat_message_received(data: Dictionary)
signal state_rejected(data: Dictionary)
signal kicked_from_room(data: Dictionary)
signal room_updated(data: Dictionary)

# ================================================================
# 常量
# ================================================================
const SERVER_WS := "ws://160.202.47.159:3000/ws"  # 原生 WebSocket 端点（非 Socket.IO）

# ================================================================
# 内部状态变量
# ================================================================
var _socket: WebSocketPeer = null
var _connected: bool = false
var _token: String = ""
var _current_room_id: String = ""
var _current_room_players: Array = []

# ================================================================
# 公有方法
# ================================================================

func connect_to_server(token: String = "") -> void:
	_token = token
	_socket = WebSocketPeer.new()
	
	# 构建 URL（原生 WebSocket，通过 query 参数传递 token）
	var url := SERVER_WS
	if _token != "":
		url += "?token=" + _token
	
	print("[NET] Connecting to: ", url)
	_socket.connect_to_url(url)
	_connected = false

func disconnect_from_server() -> void:
	if _socket:
		_socket.close()
		_socket = null
	_connected = false
	_current_room_id = ""
	_current_room_players = []
	disconnected_from_server.emit()

func is_connected_to_server() -> bool:
	return _connected

func get_current_room_id() -> String:
	return _current_room_id

func get_current_room_players() -> Array:
	return _current_room_players

# ================================================================
# 房间操作
# ================================================================

func request_room_list() -> void:
	_emit_no_ack("get_rooms", {})

func create_room(room_name: String, max_players: int = 4, password: String = "") -> void:
	_emit_no_ack("create_room", {
		"name": room_name,
		"max_players": max_players,
		"password": password
	})

func join_room(room_id: String, password: String = "") -> void:
	_emit_no_ack("join_room", {
		"room_id": room_id,
		"password": password
	})

func join_private_room(room_id: String, password: String) -> void:
	_emit_no_ack("join_private_room", {
		"room_id": room_id,
		"password": password
	})

func leave_room() -> void:
	_emit_no_ack("leave_room", {})

func toggle_ready() -> void:
	_emit_no_ack("toggle_ready", {})

func start_game() -> void:
	_emit_no_ack("start_game", {})

# ================================================================
# 游戏操作
# ================================================================

func send_player_state(pos: Vector3, rot: Vector3, hp: int, anim: String) -> void:
	_emit_no_ack("player_state", {
		"pos": pos,
		"rot": rot,
		"hp": hp,
		"anim": anim
	})

func send_shoot(target_socket_id: String, damage: int, hit_pos: Vector3) -> void:
	_emit_no_ack("shoot", {
		"target_socket_id": target_socket_id,
		"damage": damage,
		"hit_pos": hit_pos
	})

func send_chat(text: String) -> void:
	_emit_no_ack("chat", { "text": text })

func request_extract() -> void:
	_emit_no_ack("request_extract", {})

# ================================================================
# 内部：轮询 WebSocket
# ================================================================

func _process(_delta: float) -> void:
	if not _socket:
		return
	
	_socket.poll()
	
	var state = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			connected_to_server.emit()
	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			disconnected_from_server.emit()
		return
	
	# 读取所有可用消息
	while _socket.get_available_packet_count() > 0:
		var packet = _socket.get_packet()
		var raw := packet.get_string_from_utf8()
		_handle_message(raw)

# ================================================================
# 内部：消息发送
# ================================================================

func _emit(event: String, data: Dictionary) -> void:
	if not _connected:
		return
	var msg := JSON.stringify({"type": event, "data": data})
	_socket.send_text(msg)

func _emit_no_ack(event: String, data: Dictionary) -> void:
	_emit(event, data)

# ================================================================
# 内部：消息处理（原生 WebSocket JSON 协议）
# ================================================================

func _handle_message(raw: String) -> void:
	if raw.is_empty():
		return
	
	var json := JSON.new()
	if json.parse(raw) != OK:
		print("[NET] JSON parse error: ", raw)
		return
	
	var data = json.data
	if not data is Dictionary:
		return
	
	var msg_type: String = data.get("type", "")
	print("[NET] WS message: type=", msg_type)
	
	match msg_type:
		"auth_success":
			_connected = true
			connected_to_server.emit()
		"room_list":
			room_list_updated.emit(data.get("rooms", []))
		"room_created":
			_current_room_id = data.get("room_id", "")
			room_created.emit(_current_room_id)
		"room_joined":
			_current_room_id = data.get("room_id", "")
			_current_room_players = data.get("players", [])
			room_joined.emit(data)
		"room_join_failed":
			room_join_failed.emit(data.get("message", "加入失败"))
		"player_joined":
			player_joined_room.emit(data)
		"player_left":
			player_left_room.emit(data)
		"player_ready_changed":
			player_ready_changed.emit(data)
		"game_start":
			game_started.emit(data)
		"game_end":
			game_ended.emit(data)
		"remote_player_state":
			remote_player_state_received.emit(data)
		"take_damage":
			take_damage_received.emit(data)
		"hit_confirmed":
			hit_confirmed.emit(data)
		"player_killed":
			player_killed.emit(data)
		"player_extracted":
			player_extracted.emit(data)
		"chat_message":
			chat_message_received.emit(data)
		"state_rejected":
			state_rejected.emit(data)
		"kicked_from_room":
			_current_room_id = ""
			_current_room_players = []
			kicked_from_room.emit(data)
		"room_updated":
			_current_room_players = data.get("players", [])
			room_updated.emit(data)
		"room_left":
			_current_room_id = ""
			_current_room_players = []
		"error":
			push_error("[NET] Server error: " + str(data.get("message", "")))
		_:
			print("[NET] Unknown message type: ", msg_type)
