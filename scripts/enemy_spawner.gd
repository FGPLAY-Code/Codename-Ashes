extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 5.0
@export var min_distance: float = 30.0
@export var max_distance: float = 50.0
@export var max_enemies: int = 10
@export var spawn_radius: float = 200.0
@export var despawn_distance: float = 100.0

var current_enemies: int = 0
var player: Node3D = null
var spawn_timer: float = 0.0

func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		push_warning("敌人生成器找不到玩家！确保玩家已添加到 'Player' 组")

func _process(delta):
	if player == null:
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return

	if not is_instance_valid(player) or not player.is_inside_tree():
		return

	spawn_timer += delta
	if spawn_timer >= spawn_interval and current_enemies < max_enemies:
		spawn_timer = 0.0
		spawn_enemy()

func spawn_enemy():
	if enemy_scene == null:
		push_warning("敌人生成器没有设置 enemy_scene！")
		return

	if player == null or not is_instance_valid(player):
		return

	var distance = randf_range(min_distance, max_distance)
	var angle = randf() * TAU
	var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)

	var spawn_pos = player.global_position + offset
	spawn_pos.y = 0  # 确保在地面

	# 先添加到场景树
	var enemy = enemy_scene.instantiate()
	get_tree().root.add_child(enemy)
	
	# 然后设置位置
	enemy.global_position = spawn_pos
	
	enemy.tree_exited.connect(_on_enemy_removed)
	
	current_enemies += 1
	print("生成敌人，当前数量: ", current_enemies)

func _on_enemy_removed():
	current_enemies = max(0, current_enemies - 1)
