## MultiplayerGame.gd
## 多人游戏场景管理器
## 挂载到游戏主场景根节点，负责生成远程玩家、同步状态

extends Node

# ================================================================
# 节点引用
# ================================================================
@onready var local_player: CharacterBody3D = get_parent().get_node("Player")
@onready var spawn_root: Node3D = get_parent().get_node("SpawnRoot")

# 远程玩家预制体
const RemotePlayerScene = preload("res://scenes/RemotePlayer.tscn")

# ================================================================
# 状态
# ================================================================
var _remote_players: Dictionary = {}  # socket_id -> RemotePlayer 实例
var _my_socket_id: String = ""
var _state_send_timer: float = 0.0
const STATE_SEND_INTERVAL := 0.05  # 每 50ms 发一次状态（20Hz）

# ================================================================
# 初始化
# ================================================================

func _ready() -> void:
	# 连接服务器信号
	NetworkManager.game_started.connect(_on_game_start)
	NetworkManager.game_ended.connect(_on_game_end)
	NetworkManager.remote_player_state_received.connect(_on_remote_state)
	NetworkManager.player_joined_room.connect(_on_player_joined)
	NetworkManager.player_left_room.connect(_on_player_left)
	NetworkManager.take_damage_received.connect(_on_take_damage)
	NetworkManager.hit_confirmed.connect(_on_hit_confirmed)
	NetworkManager.player_killed.connect(_on_player_killed)
	NetworkManager.player_extracted.connect(_on_player_extracted)
	NetworkManager.chat_message_received.connect(_on_chat_received)

func _process(delta: float) -> void:
	if not NetworkManager.is_connected_to_server():
		return

	# 定时发送本地状态
	_state_send_timer += delta
	if _state_send_timer >= STATE_SEND_INTERVAL:
		_state_send_timer = 0.0
		_send_local_state()

# ================================================================
# 状态发送
# ================================================================

func _send_local_state() -> void:
	if not local_player:
		return
	var anim_player := local_player.get_node_or_null("AnimationPlayer")
	var current_anim: String = anim_player.current_animation if anim_player else ""
	NetworkManager.send_player_state(
		local_player.global_position,
		Vector3(0, local_player.rotation.y, 0),
		local_player.get("hp") if local_player.get("hp") != null else 100,
		current_anim,
	)

# ================================================================
# 游戏开始（服务端通知）
# ================================================================

func _on_game_start(data: Dictionary) -> void:
	print("[GAME] Game started, map: ", data.get("map"))

	# 确定自己的刷新点（服务端按 socket_id 分配）
	# 注意：WebSocket 客户端的 socket_id 在握手时由服务端分配
	# 这里先简化处理，spawn_points 按名字或直接取第一个
	var spawn_points: Dictionary = data.get("spawn_points", {})
	# TODO: 获取自己的 socket_id 后取对应刷新点
	# var my_spawn = spawn_points.get(NetworkManager.my_socket_id, {})
	# local_player.global_position = Vector3(my_spawn.x, my_spawn.y, my_spawn.z)

	# 暂时用随机刷新点
	if spawn_points.size() > 0:
		var first_spawn = spawn_points.values()[0]
		if first_spawn is Dictionary:
			local_player.global_position = Vector3(
				first_spawn.get("x", 0),
				first_spawn.get("y", 1),
				first_spawn.get("z", 0),
			)

# ================================================================
# 游戏结束
# ================================================================

func _on_game_end(data: Dictionary) -> void:
	print("[GAME] Game ended: ", data.get("reason"))
	var results: Array = data.get("results", [])

	# 保存结算数据
	var my_result = {}
	for r in results:
		if r.get("name") == NetworkManager.get_player_data().get("username"):
			my_result = r
			break

	# 自动保存战绩（如果成功撤离）
	if my_result.get("extracted", false):
		var gold_earned := 5000  # TODO: 根据实际拾取物品计算
		NetworkManager.save_game_result(gold_earned, my_result.get("kills", 0), [], [])

	# 显示结算界面
	# TODO: 切换到结算场景

# ================================================================
# 远程玩家进入
# ================================================================

func _on_player_joined(data: Dictionary) -> void:
	var sid: String = data.get("socket_id", "")
	if sid == "" or sid == _my_socket_id:
		return

	var rp: Node3D = RemotePlayerScene.instantiate()
	spawn_root.add_child(rp)
	rp.setup(sid, data.get("name", "Player"), Vector3.ZERO)
	_remote_players[sid] = rp
	print("[GAME] Remote player joined: ", data.get("name"))

func _on_player_left(data: Dictionary) -> void:
	var sid: String = data.get("socket_id", "")
	if _remote_players.has(sid):
		_remote_players[sid].queue_free()
		_remote_players.erase(sid)
		print("[GAME] Remote player left: ", data.get("name"))

# ================================================================
# 远程状态同步
# ================================================================

func _on_remote_state(data: Dictionary) -> void:
	var sid: String = data.get("socket_id", "")
	if _remote_players.has(sid):
		_remote_players[sid].apply_remote_state(data)

# ================================================================
# 受击（服务端通知本地玩家）
# ================================================================

func _on_take_damage(data: Dictionary) -> void:
	var damage: int = data.get("damage", 0)
	var hp: int = data.get("hp", 100)
	print("[GAME] Take damage: ", damage, " HP: ", hp)

	# 更新本地血量
	if local_player.has_method("apply_damage"):
		local_player.apply_damage(damage)
	elif "hp" in local_player:
		local_player.hp = hp

	# 显示受击特效
	# TODO: 屏幕边缘红色闪烁

# ================================================================
# 命中确认（其他玩家被击中的视觉反馈）
# ================================================================

func _on_hit_confirmed(data: Dictionary) -> void:
	var target_sid: String = data.get("target", "")
	var hit_pos_d: Dictionary = data.get("hit_pos", {})
	var hit_pos := Vector3(hit_pos_d.get("x", 0), hit_pos_d.get("y", 0), hit_pos_d.get("z", 0))

	# TODO: 在命中位置生成血迹粒子
	print("[GAME] Hit confirmed on: ", target_sid, " at ", hit_pos)

# ================================================================
# 玩家击杀
# ================================================================

func _on_player_killed(data: Dictionary) -> void:
	var killer_name: String = data.get("killer_name", "")
	var victim_name: String = data.get("victim_name", "")
	var victim_sid: String = data.get("victim", "")

	print("[GAME] ", killer_name, " killed ", victim_name)

	# 如果被击杀者是远程玩家，触发死亡动画
	if _remote_players.has(victim_sid):
		_remote_players[victim_sid].die()

	# 显示击杀提示（HUD）
	var hud = get_node_or_null("/root/HUD")
	if hud and hud.has_method("show_kill_feed"):
		hud.show_kill_feed(killer_name, victim_name)

# ================================================================
# 撤离
# ================================================================

func _on_player_extracted(data: Dictionary) -> void:
	var name: String = data.get("name", "")
	print("[GAME] ", name, " extracted!")
	# TODO: 显示撤离提示

# ================================================================
# 聊天
# ================================================================

func _on_chat_received(data: Dictionary) -> void:
	var sender: String = data.get("sender", "")
	var text: String = data.get("text", "")
	print("[CHAT] ", sender, ": ", text)
	# TODO: 显示聊天界面

# ================================================================
# 发射武器时调用（从 player.gd 调用此函数）
# ================================================================

func on_local_shoot(target: Node3D, damage: int, hit_position: Vector3) -> void:
	# 判断目标是否是远程玩家
	for sid in _remote_players:
		if _remote_players[sid] == target:
			NetworkManager.send_shoot(sid, damage, hit_position)
			return
