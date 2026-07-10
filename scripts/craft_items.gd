extends Node

# ============================================================
# 工艺藏品系统 - 搜打撤核心玩法
# ============================================================
# 品质等级: green(50%) > blue(30%) > purple(20%)

# 工艺藏品数据定义
const CRAFT_ITEMS: Dictionary = {
	# ============ 绿色品质 - 普通 ============
	"tactical_gloves": {
		"id": "tactical_gloves",
		"name": "战术手套",
		"quality": "green",
		"icon": "gloves",
		"description": "增加 15% 换弹速度",
		"rarity": 1,
		"rarity_name": "普通",
		"rarity_color": Color(0.2, 0.85, 0.3, 1),  # 绿色
		"effect_type": "reload_speed",
		"effect_value": 0.15,
		"sell_price": 500,
		"stackable": false
	},
	"combat_boots": {
		"id": "combat_boots",
		"name": "军靴",
		"quality": "green",
		"icon": "boots",
		"description": "增加 10% 移动速度",
		"rarity": 1,
		"rarity_name": "普通",
		"rarity_color": Color(0.2, 0.85, 0.3, 1),
		"effect_type": "move_speed",
		"effect_value": 0.10,
		"sell_price": 450,
		"stackable": false
	},
	"helmet_liner": {
		"id": "helmet_liner",
		"name": "头盔内衬",
		"quality": "green",
		"icon": "helmet_liner",
		"description": "增加 10 点头部防护",
		"rarity": 1,
		"rarity_name": "普通",
		"rarity_color": Color(0.2, 0.85, 0.3, 1),
		"effect_type": "head_armor",
		"effect_value": 10,
		"sell_price": 550,
		"stackable": false
	},
	"knee_pads": {
		"id": "knee_pads",
		"name": "护膝垫",
		"quality": "green",
		"icon": "knee_pads",
		"description": "减少 20% 坠落伤害",
		"rarity": 1,
		"rarity_name": "普通",
		"rarity_color": Color(0.2, 0.85, 0.3, 1),
		"effect_type": "fall_damage_reduction",
		"effect_value": 0.20,
		"sell_price": 400,
		"stackable": false
	},
	"tactical_watch": {
		"id": "tactical_watch",
		"name": "战术手表",
		"quality": "green",
		"icon": "watch",
		"description": "显示附近敌人位置标记",
		"rarity": 1,
		"rarity_name": "普通",
		"rarity_color": Color(0.2, 0.85, 0.3, 1),
		"effect_type": "enemy_marker",
		"effect_value": 1,
		"sell_price": 600,
		"stackable": false
	},

	# ============ 蓝色品质 - 稀有 ============
	"optical_sight": {
		"id": "optical_sight",
		"name": "光学瞄具",
		"quality": "blue",
		"icon": "scope",
		"description": "增加 25% 射击精度",
		"rarity": 2,
		"rarity_name": "稀有",
		"rarity_color": Color(0.3, 0.5, 1.0, 1),  # 蓝色
		"effect_type": "accuracy",
		"effect_value": 0.25,
		"sell_price": 12000,
		"stackable": false
	},
	"quick_mag": {
		"id": "quick_mag",
		"name": "快速弹匣",
		"quality": "blue",
		"icon": "mag",
		"description": "减少 30% 换弹时间",
		"rarity": 2,
		"rarity_name": "稀有",
		"rarity_color": Color(0.3, 0.5, 1.0, 1),
		"effect_type": "reload_time",
		"effect_value": 0.30,
		"sell_price": 15000,
		"stackable": false
	},
	"suppressor_tube": {
		"id": "suppressor_tube",
		"name": "消音器管",
		"quality": "blue",
		"icon": "suppressor",
		"description": "减少 40% 脚步声",
		"rarity": 2,
		"rarity_name": "稀有",
		"rarity_color": Color(0.3, 0.5, 1.0, 1),
		"effect_type": "footstep_reduction",
		"effect_value": 0.40,
		"sell_price": 10000,
		"stackable": false
	},

	# ============ 紫色品质 - 史诗 ============
	"tactical_vest": {
		"id": "tactical_vest",
		"name": "战术背心",
		"quality": "purple",
		"icon": "vest",
		"description": "增加 8 格背包容量",
		"rarity": 3,
		"rarity_name": "史诗",
		"rarity_color": Color(0.6, 0.3, 0.9, 1),  # 紫色
		"effect_type": "inventory_slots",
		"effect_value": 8,
		"sell_price": 30000,
		"stackable": false
	},
	"night_vision": {
		"id": "night_vision",
		"name": "夜视仪",
		"quality": "purple",
		"icon": "nvg",
		"description": "黑暗中视野范围扩大 50%",
		"rarity": 3,
		"rarity_name": "史诗",
		"rarity_color": Color(0.6, 0.3, 0.9, 1),
		"effect_type": "night_vision",
		"effect_value": 0.50,
		"sell_price": 25000,
		"stackable": false
	}
}

# 掉落概率配置
const DROP_PROBABILITIES: Dictionary = {
	"green": 0.50,   # 50% 绿色
	"blue": 0.30,    # 30% 蓝色
	"purple": 0.20   # 20% 紫色
}

# 每种品质的物品列表
static func get_items_by_quality(quality: String) -> Array:
	var result: Array = []
	for item_id in CRAFT_ITEMS:
		if CRAFT_ITEMS[item_id]["quality"] == quality:
			result.append(item_id)
	return result

# 根据概率随机获取物品ID
static func roll_loot() -> String:
	var roll = randf()
	var cumulative = 0.0

	# 按概率逐级判定
	for quality in ["purple", "blue", "green"]:
		cumulative += DROP_PROBABILITIES[quality]
		if roll < cumulative:
			# 获取该品质的物品列表
			var items = get_items_by_quality(quality)
			if items.size() > 0:
				return items[randi() % items.size()]

	# 默认返回绿色
	var green_items = get_items_by_quality("green")
	if green_items.size() > 0:
		return green_items[randi() % green_items.size()]
	return ""

# 获取物品数据
static func get_item_data(item_id: String) -> Dictionary:
	if CRAFT_ITEMS.has(item_id):
		return CRAFT_ITEMS[item_id].duplicate(true)
	return {}

# 获取品质边框颜色
static func get_quality_color(quality: String) -> Color:
	match quality:
		"green":
			return Color(0.2, 0.85, 0.3, 1)    # 翠绿
		"blue":
			return Color(0.3, 0.5, 1.0, 1)     # 天蓝
		"purple":
			return Color(0.6, 0.3, 0.9, 1)    # 紫罗兰
		_:
			return Color(0.6, 0.6, 0.6, 1)    # 灰色

# 获取品质名称
static func get_quality_name(quality: String) -> String:
	match quality:
		"green":
			return "普通"
		"blue":
			return "稀有"
		"purple":
			return "史诗"
		_:
			return "未知"

# 获取物品图标颜色（用于UI显示）
static func get_item_icon_color(icon_type: String) -> Color:
	match icon_type:
		"gloves":
			return Color(0.4, 0.6, 0.4, 1)
		"boots":
			return Color(0.5, 0.4, 0.3, 1)
		"helmet_liner":
			return Color(0.3, 0.5, 0.3, 1)
		"knee_pads":
			return Color(0.5, 0.5, 0.4, 1)
		"watch":
			return Color(0.4, 0.5, 0.6, 1)
		"scope":
			return Color(0.2, 0.4, 0.6, 1)
		"mag":
			return Color(0.4, 0.4, 0.5, 1)
		"suppressor":
			return Color(0.3, 0.35, 0.4, 1)
		"vest":
			return Color(0.4, 0.5, 0.3, 1)
		"nvg":
			return Color(0.2, 0.3, 0.2, 1)
		_:
			return Color(0.5, 0.5, 0.5, 1)

func _ready() -> void:
	# 初始化随机种子（如果尚未初始化）
	pass

# 生成物品掉落数据（用于储物箱掉落）
func generate_loot_item() -> Dictionary:

	var item_id = roll_loot()
	if item_id == "":
		return {}

	var item_data = get_item_data(item_id)
	item_data["count"] = 1
	return item_data

# 计算掉落总价值（用于显示）
static func calculate_loot_value() -> Dictionary:
	var total_value = 0
	var breakdown = {}

	for item_id in CRAFT_ITEMS:
		var item = CRAFT_ITEMS[item_id]
		var prob = DROP_PROBABILITIES[item["quality"]] / get_items_by_quality(item["quality"]).size()
		var expected_value = item["sell_price"] * prob
		total_value += expected_value
		if not breakdown.has(item["quality"]):
			breakdown[item["quality"]] = 0
		breakdown[item["quality"]] += expected_value

	return {
		"total": int(total_value),
		"breakdown": breakdown
	}
