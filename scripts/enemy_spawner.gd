extends Node3D

@export var enemy_scene: PackedScene

## 突袭模式：初始生成数量
@export var raid_spawn_count: int = 8

## 突袭模式：生成半径（以地图原点为中心）
@export var spawn_radius: float = 40.0

## 突袭模式：最小生成间距（避免敌人叠在一起）
@export var min_spacing: float = 8.0

var player: Node3D = null

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		push_warning("敌人生成器找不到玩家！确保玩家已添加到 'Player' 组")
	
	# 开始新突袭：清空旧敌人 + 生成新一批
	call_deferred("initialize_raid")

## 初始化新一局突袭
func initialize_raid():
	# 清空所有旧敌人
	_clear_all_enemies()
	
	# 生成新敌人
	_spawn_raid_enemies()
	
	print("[Raid] 突袭初始化完成，生成 ", raid_spawn_count, " 个敌人")

## 清空地图上所有敌人
func _clear_all_enemies():
	var all_enemies = get_tree().get_nodes_in_group("Enemy")
	for e in all_enemies:
		if is_instance_valid(e) and e.is_inside_tree():
			e.queue_free()
	print("[Raid] 已清空 ", all_enemies.size(), " 个旧敌人")

## 在随机位置生成一批敌人
func _spawn_raid_enemies():
	if enemy_scene == null:
		push_warning("敌人生成器没有设置 enemy_scene！")
		return
	
	var spawned_positions: Array[Vector3] = []
	
	for i in range(raid_spawn_count):
		var pos = _find_valid_spawn_pos(spawned_positions)
		if pos == null:
			continue
		
		var enemy = enemy_scene.instantiate()
		get_tree().root.add_child(enemy)
		enemy.global_position = pos
		
		# 添加到 Enemy 组（如果还没加）
		if not enemy.is_in_group("Enemy"):
			enemy.add_to_group("Enemy")
		
		spawned_positions.append(pos)
	
	print("[Raid] 已生成 ", spawned_positions.size(), " 个敌人")

## 寻找一个有效的生成位置
func _find_valid_spawn_pos(used: Array[Vector3]) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var attempts = 0
	while attempts < 30:
		attempts += 1
		var angle = randf() * TAU
		var dist = randf_range(15.0, spawn_radius)
		var pos = Vector3(cos(angle) * dist, 30, sin(angle) * dist)
		
		# 检查间距
		var valid = true
		for p in used:
			if pos.distance_to(p) < min_spacing:
				valid = false
				break
		if not valid:
			continue
		
		# 向下发射射线，找到地形表面 Y
		var query = PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 60)
		query.collision_mask = 1  # layer 1 = 地面
		var result = space_state.intersect_ray(query)
		if result:
			pos.y = result.position.y
			return pos
	
	# 实在找不到就退回到玩家高度
	if player:
		return Vector3(0, player.global_position.y, 0)
	return Vector3.ZERO
