## RemotePlayer.gd
## 远程玩家角色（其他联机玩家的表现层）
## 实例化一个角色模型，用插值平滑显示远端同步位置

extends CharacterBody3D

# ================================================================
# 配置
# ================================================================
const INTERP_SPEED := 15.0    # 插值速度（值越大越跟手，网络差时可降低）
const EXTRAPOLATE  := true    # 启用外插（预测远端移动，减少卡顿感）

# ================================================================
# 状态
# ================================================================
var socket_id: String = ""
var player_name: String = ""
var current_hp: int = 100
var is_dead: bool = false

var _target_pos: Vector3 = Vector3.ZERO
var _target_rot_y: float = 0.0
var _last_update_time: float = 0.0
var _last_velocity: Vector3 = Vector3.ZERO

# UI 标签
@onready var name_label: Label3D = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar3D  # 可选，需要自行添加

# ================================================================
# 初始化
# ================================================================

func setup(sid: String, pname: String, spawn_pos: Vector3) -> void:
	socket_id = sid
	player_name = pname
	global_position = spawn_pos
	_target_pos = spawn_pos
	if name_label:
		name_label.text = pname

# ================================================================
# 每帧更新（平滑插值）
# ================================================================

func _process(delta: float) -> void:
	if is_dead:
		return

	# 位置插值
	var interp_pos := global_position.lerp(_target_pos, INTERP_SPEED * delta)
	global_position = interp_pos

	# 旋转插值
	var current_rot := rotation.y
	var diff := fposmod(_target_rot_y - current_rot + PI, TAU) - PI
	rotation.y += diff * INTERP_SPEED * delta

# ================================================================
# 接收服务端推送的状态
# ================================================================

func apply_remote_state(data: Dictionary) -> void:
	var pos_d: Dictionary = data.get("pos", {})
	var rot_d: Dictionary = data.get("rot", {})
	var new_hp: int = data.get("hp", current_hp)
	var anim: String = data.get("anim", "")

	_last_velocity = Vector3(
		pos_d.get("x", 0.0) - _target_pos.x,
		pos_d.get("y", 0.0) - _target_pos.y,
		pos_d.get("z", 0.0) - _target_pos.z,
	)
	_target_pos = Vector3(
		pos_d.get("x", global_position.x),
		pos_d.get("y", global_position.y),
		pos_d.get("z", global_position.z),
	)
	_target_rot_y = rot_d.get("y", _target_rot_y)
	_last_update_time = Time.get_ticks_msec() / 1000.0

	# 更新血量
	if new_hp != current_hp:
		current_hp = new_hp
		if hp_bar:
			hp_bar.value = current_hp

	# 播放动画
	_play_anim(anim)

func _play_anim(anim: String) -> void:
	if anim.is_empty():
		return
	# TODO: 根据项目的 AnimationPlayer 或 AnimationTree 节点名称调整
	var anim_player := get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation(anim):
		if anim_player.current_animation != anim:
			anim_player.play(anim)

# ================================================================
# 受击 / 死亡
# ================================================================

func on_take_damage(damage: int) -> void:
	current_hp = max(0, current_hp - damage)
	if hp_bar:
		hp_bar.value = current_hp
	if current_hp <= 0:
		die()

func die() -> void:
	is_dead = true
	# TODO: 播放死亡动画
	var anim_player := get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation("death"):
		anim_player.play("death")
	# 延迟删除
	await get_tree().create_timer(3.0).timeout
	queue_free()
