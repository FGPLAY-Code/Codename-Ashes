"""
绿洲行动 - 敌人模型生成脚本
在 Blender 中运行：File -> Run Script
"""

import bpy
import math
import random

# ===== 清理场景 =====
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# ===== 材质创建 =====
def create_material(name, base_color, metallic=0.0, roughness=0.5, emission=None):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    
    # 清除默认节点
    nodes.clear()
    
    # 创建 Principled BSDF
    principled = nodes.new('ShaderNodeBsdfPrincipled')
    principled.location = (0, 0)
    principled.inputs['Base Color'].default_value = base_color
    principled.inputs['Metallic'].default_value = metallic
    principled.inputs['Roughness'].default_value = roughness
    
    if emission:
        # Blender 4.x+ 使用新的属性名
        if 'Emission Color' in principled.inputs:
            principled.inputs['Emission Color'].default_value = emission
            principled.inputs['Emission Strength'].default_value = 2.0
        else:
            principled.inputs['Emission'].default_value = emission
            principled.inputs['Emission Strength'].default_value = 2.0
    
    # 输出节点
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(principled.outputs['BSDF'], output.inputs['Surface'])
    
    return mat

# ===== 材质 =====
# 主体 - 深灰色金属
mat_body = create_material("Body_Metal", 
    base_color=(0.15, 0.15, 0.18, 1), 
    metallic=0.8, 
    roughness=0.3)

# 装甲 - 暗红色
mat_armor = create_material("Armor_Red", 
    base_color=(0.4, 0.1, 0.1, 1), 
    metallic=0.6, 
    roughness=0.4)

# 发光部件 - 橙色
mat_glow = create_material("Glow_Orange", 
    base_color=(1.0, 0.5, 0.0, 1), 
    metallic=0.0, 
    roughness=0.2,
    emission=(1.0, 0.4, 0.0, 1))

# 发光眼睛 - 红色
mat_eye = create_material("Eye_Red", 
    base_color=(1.0, 0.0, 0.0, 1), 
    metallic=0.0, 
    roughness=0.1,
    emission=(1.0, 0.0, 0.0, 1))

# 武器 - 黑色
mat_weapon = create_material("Weapon", 
    base_color=(0.1, 0.1, 0.1, 1), 
    metallic=0.9, 
    roughness=0.2)

# ===== 创建敌人 =====
def create_enemy():
    # 创建空对象作为父级
    enemy = bpy.data.objects.new("Enemy_Scout", None)
    bpy.context.collection.objects.link(enemy)
    
    # === 腿部 ===
    leg_positions = [(-0.15, 0, -0.4), (0.15, 0, -0.4)]
    for i, pos in enumerate(leg_positions):
        # 大腿
        thigh = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.08, depth=0.35, location=pos
        )
        thigh_obj = bpy.context.active_object
        thigh_obj.name = f"Thigh_{i}"
        thigh_obj.rotation_euler = (math.radians(90), 0, 0)
        thigh_obj.data.materials.append(mat_armor)
        thigh_obj.parent = enemy
        
        # 小腿
        shin_pos = (pos[0], pos[1], pos[2] - 0.45)
        shin = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.06, depth=0.4, location=shin_pos
        )
        shin_obj = bpy.context.active_object
        shin_obj.name = f"Shin_{i}"
        shin_obj.rotation_euler = (math.radians(90), 0, 0)
        shin_obj.data.materials.append(mat_body)
        shin_obj.parent = enemy
        
        # 脚部
        foot_pos = (pos[0], pos[1] + 0.1, pos[2] - 0.75)
        foot = bpy.ops.mesh.primitive_cube_add(
            size=1, location=foot_pos
        )
        foot_obj = bpy.context.active_object
        foot_obj.name = f"Foot_{i}"
        foot_obj.scale = (0.12, 0.2, 0.06)
        foot_obj.data.materials.append(mat_body)
        foot_obj.parent = enemy
    
    # === 躯干 ===
    torso = bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    torso_obj = bpy.context.active_object
    torso_obj.name = "Torso"
    torso_obj.scale = (0.25, 0.15, 0.35)
    torso_obj.data.materials.append(mat_body)
    torso_obj.parent = enemy
    
    # 胸甲
    chest = bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.02, 0.1))
    chest_obj = bpy.context.active_object
    chest_obj.name = "ChestPlate"
    chest_obj.scale = (0.22, 0.08, 0.2)
    chest_obj.data.materials.append(mat_armor)
    chest_obj.parent = enemy
    
    # 能量核心（胸口发光）
    core = bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.05, location=(0, 0.08, 0.05)
    )
    core_obj = bpy.context.active_object
    core_obj.name = "EnergyCore"
    core_obj.data.materials.append(mat_glow)
    core_obj.parent = enemy
    
    # 背部推进器
    thruster = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.06, depth=0.15, location=(0, -0.12, -0.1)
    )
    thruster_obj = bpy.context.active_object
    thruster_obj.name = "Thruster"
    thruster_obj.rotation_euler = (math.radians(90), 0, 0)
    thruster_obj.data.materials.append(mat_body)
    thruster_obj.parent = enemy
    
    # === 肩部装甲 ===
    shoulder_positions = [(-0.3, 0, 0.2), (0.3, 0, 0.2)]
    for i, pos in enumerate(shoulder_positions):
        shoulder = bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
        shoulder_obj = bpy.context.active_object
        shoulder_obj.name = f"Shoulder_{i}"
        shoulder_obj.scale = (0.1, 0.12, 0.12)
        shoulder_obj.data.materials.append(mat_armor)
        shoulder_obj.parent = enemy
        
        # 肩部发光条
        glow_pos = (pos[0], pos[1], pos[2] - 0.05)
        glow = bpy.ops.mesh.primitive_cube_add(size=1, location=glow_pos)
        glow_obj = bpy.context.active_object
        glow_obj.name = f"ShoulderGlow_{i}"
        glow_obj.scale = (0.08, 0.02, 0.02)
        glow_obj.data.materials.append(mat_glow)
        glow_obj.parent = enemy
    
    # === 手臂 ===
    arm_positions = [(-0.35, 0, -0.05), (0.35, 0, -0.05)]
    for i, pos in enumerate(arm_positions):
        # 上臂
        upper_arm = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.05, depth=0.25, location=pos
        )
        upper_arm_obj = bpy.context.active_object
        upper_arm_obj.name = f"UpperArm_{i}"
        upper_arm_obj.rotation_euler = (math.radians(90), 0, 0)
        upper_arm_obj.data.materials.append(mat_body)
        upper_arm_obj.parent = enemy
        
        # 前臂
        forearm_pos = (pos[0], pos[1], pos[2] - 0.35)
        forearm = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.04, depth=0.2, location=forearm_pos
        )
        forearm_obj = bpy.context.active_object
        forearm_obj.name = f"Forearm_{i}"
        forearm_obj.rotation_euler = (math.radians(90), 0, 0)
        forearm_obj.data.materials.append(mat_body)
        forearm_obj.parent = enemy
        
        # 手部
        hand_pos = (pos[0], pos[1], pos[2] - 0.5)
        hand = bpy.ops.mesh.primitive_cube_add(size=1, location=hand_pos)
        hand_obj = bpy.context.active_object
        hand_obj.name = f"Hand_{i}"
        hand_obj.scale = (0.05, 0.04, 0.08)
        hand_obj.data.materials.append(mat_body)
        hand_obj.parent = enemy
    
    # === 头部 ===
    head = bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.5))
    head_obj = bpy.context.active_object
    head_obj.name = "Head"
    head_obj.scale = (0.15, 0.12, 0.18)
    head_obj.data.materials.append(mat_body)
    head_obj.parent = enemy
    
    # 面罩
    visor = bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.05, 0.5))
    visor_obj = bpy.context.active_object
    visor_obj.name = "Visor"
    visor_obj.scale = (0.12, 0.05, 0.08)
    visor_obj.data.materials.append(mat_armor)
    visor_obj.parent = enemy
    
    # 眼睛发光
    eye_positions = [(-0.05, 0.08, 0.5), (0.05, 0.08, 0.5)]
    for i, pos in enumerate(eye_positions):
        eye = bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.025, location=pos
        )
        eye_obj = bpy.context.active_object
        eye_obj.name = f"Eye_{i}"
        eye_obj.data.materials.append(mat_eye)
        eye_obj.parent = enemy
    
    # 头顶天线
    antenna_base = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.015, depth=0.1, location=(0, 0, 0.7)
    )
    antenna_base_obj = bpy.context.active_object
    antenna_base_obj.name = "AntennaBase"
    antenna_base_obj.data.materials.append(mat_body)
    antenna_base_obj.parent = enemy
    
    antenna_tip = bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.025, location=(0, 0, 0.78)
    )
    antenna_tip_obj = bpy.context.active_object
    antenna_tip_obj.name = "AntennaTip"
    antenna_tip_obj.data.materials.append(mat_glow)
    antenna_tip_obj.parent = enemy
    
    # 头部侧面装甲
    helmet_positions = [(-0.12, 0, 0.55), (0.12, 0, 0.55)]
    for i, pos in enumerate(helmet_positions):
        helmet = bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
        helmet_obj = bpy.context.active_object
        helmet_obj.name = f"Helmet_{i}"
        helmet_obj.scale = (0.03, 0.08, 0.1)
        helmet_obj.data.materials.append(mat_armor)
        helmet_obj.parent = enemy
    
    # === 武器（科幻步枪） ===
    weapon = bpy.ops.mesh.primitive_cube_add(size=1, location=(0.35, 0, -0.1))
    weapon_obj = bpy.context.active_object
    weapon_obj.name = "Weapon"
    weapon_obj.scale = (0.04, 0.04, 0.3)
    weapon_obj.data.materials.append(mat_weapon)
    weapon_obj.parent = enemy
    
    # 枪管
    barrel = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.015, depth=0.2, location=(0.35, 0, -0.35)
    )
    barrel_obj = bpy.context.active_object
    barrel_obj.name = "Barrel"
    barrel_obj.rotation_euler = (math.radians(90), 0, 0)
    barrel_obj.data.materials.append(mat_weapon)
    barrel_obj.parent = enemy
    
    # 枪口发光
    muzzle_glow = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.02, depth=0.03, location=(0.35, 0, -0.47)
    )
    muzzle_obj = bpy.context.active_object
    muzzle_obj.name = "MuzzleGlow"
    muzzle_obj.rotation_euler = (math.radians(90), 0, 0)
    muzzle_obj.data.materials.append(mat_glow)
    muzzle_obj.parent = enemy
    
    # 准星
    sight = bpy.ops.mesh.primitive_cube_add(
        size=1, location=(0.35, 0.06, -0.15)
    )
    sight_obj = bpy.context.active_object
    sight_obj.name = "Sight"
    sight_obj.scale = (0.02, 0.02, 0.02)
    sight_obj.data.materials.append(mat_glow)
    sight_obj.parent = enemy
    
    # === 设置姿态 ===
    # 稍微前倾站立姿态
    enemy.rotation_euler = (0, 0, 0)
    
    return enemy

# ===== 创建敌人 =====
enemy = create_enemy()

# ===== 应用变换并设为Blender单位 =====
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = enemy
enemy.select_set(True)

# 应用变换
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 缩放到合适大小（假设1单位=1米）
enemy.scale = (1.0, 1.0, 1.0)

# ===== 添加碰撞体 =====
# 为敌人添加碰撞体（用于游戏引擎）
bpy.ops.object.empty_add(type='CUBE', location=(0, 0, 0.2))
collision = bpy.context.active_object
collision.name = "CollisionBox"
collision.empty_display_size = 0.8
collision.scale = (0.5, 0.3, 1.0)
collision.parent = enemy

# ===== 创建碰撞子场景 =====
# 在Blender中选中敌人，按P导出为场景

print("=" * 50)
print("敌人模型创建完成！")
print("名称: Enemy_Scout")
print("高度: 约 1.6 米")
print("=" * 50)
print("导出方法:")
print("1. File -> Export -> glTF 2.0")
print("2. 选择 'Selected Objects'")
print("3. 导出为 .glb 格式")
print("4. 拖入 Godot 项目即可")
print("=" * 50)
