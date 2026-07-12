"""
绿洲行动 - 人类敌人模型生成脚本
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
    
    nodes.clear()
    
    principled = nodes.new('ShaderNodeBsdfPrincipled')
    principled.location = (0, 0)
    principled.inputs['Base Color'].default_value = base_color
    principled.inputs['Metallic'].default_value = metallic
    principled.inputs['Roughness'].default_value = roughness
    
    if emission:
        if 'Emission Color' in principled.inputs:
            principled.inputs['Emission Color'].default_value = emission
            principled.inputs['Emission Strength'].default_value = 2.0
        else:
            principled.inputs['Emission'].default_value = emission
            principled.inputs['Emission Strength'].default_value = 2.0
    
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(principled.outputs['BSDF'], output.inputs['Surface'])
    
    return mat

# ===== 材质 =====
# 皮肤
mat_skin = create_material("Skin", 
    base_color=(0.85, 0.7, 0.6, 1), 
    metallic=0.0, 
    roughness=0.8)

# 迷彩服 - 荒漠色
mat_uniform = create_material("Uniform_Camo", 
    base_color=(0.45, 0.4, 0.3, 1), 
    metallic=0.0, 
    roughness=0.9)

# 战术背心 - 深绿色
mat_vest = create_material("Tactical_Vest", 
    base_color=(0.2, 0.25, 0.15, 1), 
    metallic=0.1, 
    roughness=0.7)

# 靴子 - 深棕色
mat_boots = create_material("Boots", 
    base_color=(0.15, 0.1, 0.08, 1), 
    metallic=0.0, 
    roughness=0.6)

# 枪械 - 黑色金属
mat_gun = create_material("Gun", 
    base_color=(0.1, 0.1, 0.1, 1), 
    metallic=0.7, 
    roughness=0.3)

# 头发 - 黑色
mat_hair = create_material("Hair", 
    base_color=(0.05, 0.05, 0.05, 1), 
    metallic=0.0, 
    roughness=0.9)

# ===== 创建人类敌人 =====
def create_human_enemy():
    # 创建空对象作为父级
    enemy = bpy.data.objects.new("Enemy_Soldier", None)
    bpy.context.collection.objects.link(enemy)
    
    # === 躯干 ===
    torso = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.18, depth=0.5, location=(0, 0, 0.9)
    )
    torso_obj = bpy.context.active_object
    torso_obj.name = "Torso"
    torso_obj.rotation_euler = (math.radians(90), 0, 0)
    torso_obj.data.materials.append(mat_uniform)
    torso_obj.parent = enemy
    
    # 战术背心
    vest = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.2, depth=0.35, location=(0, 0.05, 0.95)
    )
    vest_obj = bpy.context.active_object
    vest_obj.name = "Vest"
    vest_obj.rotation_euler = (math.radians(90), 0, 0)
    vest_obj.data.materials.append(mat_vest)
    vest_obj.parent = enemy
    
    # 背心弹夹包
    for i in range(3):
        pouch = bpy.ops.mesh.primitive_cube_add(
            size=1, location=(0.12, 0.08, 0.85 + i * 0.08)
        )
        pouch_obj = bpy.context.active_object
        pouch_obj.name = f"Pouch_{i}"
        pouch_obj.scale = (0.04, 0.06, 0.03)
        pouch_obj.data.materials.append(mat_vest)
        pouch_obj.parent = enemy
    
    # === 头部 ===
    head = bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.12, location=(0, 0, 1.5)
    )
    head_obj = bpy.context.active_object
    head_obj.name = "Head"
    head_obj.data.materials.append(mat_skin)
    head_obj.parent = enemy
    
    # 头发
    hair = bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.125, location=(0, 0, 1.52)
    )
    hair_obj = bpy.context.active_object
    hair_obj.name = "Hair"
    hair_obj.scale = (1, 1, 0.6)
    hair_obj.data.materials.append(mat_hair)
    hair_obj.parent = enemy
    
    # 帽子
    hat = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.13, depth=0.08, location=(0, 0, 1.58)
    )
    hat_obj = bpy.context.active_object
    hat_obj.name = "Hat"
    hat_obj.data.materials.append(mat_uniform)
    hat_obj.parent = enemy
    
    # 帽檐
    brim = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.14, depth=0.02, location=(0, 0.06, 1.56)
    )
    brim_obj = bpy.context.active_object
    brim_obj.name = "HatBrim"
    brim_obj.data.materials.append(mat_uniform)
    brim_obj.parent = enemy
    
    # === 脖子 ===
    neck = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.06, depth=0.1, location=(0, 0, 1.35)
    )
    neck_obj = bpy.context.active_object
    neck_obj.name = "Neck"
    neck_obj.data.materials.append(mat_skin)
    neck_obj.parent = enemy
    
    # === 手臂 ===
    arm_positions = [(-0.22, 0, 1.1), (0.22, 0, 1.1)]
    for i, pos in enumerate(arm_positions):
        # 上臂
        upper_arm = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.06, depth=0.28, location=pos
        )
        upper_arm_obj = bpy.context.active_object
        upper_arm_obj.name = f"UpperArm_{i}"
        upper_arm_obj.rotation_euler = (math.radians(90), 0, 0)
        upper_arm_obj.data.materials.append(mat_uniform)
        upper_arm_obj.parent = enemy
        
        # 前臂
        forearm_pos = (pos[0], pos[1], pos[2] - 0.35)
        forearm = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.05, depth=0.28, location=forearm_pos
        )
        forearm_obj = bpy.context.active_object
        forearm_obj.name = f"Forearm_{i}"
        forearm_obj.rotation_euler = (math.radians(90), 0, 0)
        forearm_obj.data.materials.append(mat_skin)
        forearm_obj.parent = enemy
        
        # 手
        hand_pos = (pos[0], pos[1], pos[2] - 0.52)
        hand = bpy.ops.mesh.primitive_uv_sphere_add(
            radius=0.05, location=hand_pos
        )
        hand_obj = bpy.context.active_object
        hand_obj.name = f"Hand_{i}"
        hand_obj.data.materials.append(mat_skin)
        hand_obj.parent = enemy
    
    # === 腿部 ===
    leg_positions = [(-0.1, 0, 0.5), (0.1, 0, 0.5)]
    for i, pos in enumerate(leg_positions):
        # 大腿
        thigh = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.09, depth=0.4, location=pos
        )
        thigh_obj = bpy.context.active_object
        thigh_obj.name = f"Thigh_{i}"
        thigh_obj.rotation_euler = (math.radians(90), 0, 0)
        thigh_obj.data.materials.append(mat_uniform)
        thigh_obj.parent = enemy
        
        # 小腿
        shin_pos = (pos[0], pos[1], pos[2] - 0.45)
        shin = bpy.ops.mesh.primitive_cylinder_add(
            radius=0.07, depth=0.4, location=shin_pos
        )
        shin_obj = bpy.context.active_object
        shin_obj.name = f"Shin_{i}"
        shin_obj.rotation_euler = (math.radians(90), 0, 0)
        shin_obj.data.materials.append(mat_uniform)
        shin_obj.parent = enemy
        
        # 靴子
        boot_pos = (pos[0], pos[1] + 0.05, pos[2] - 0.75)
        boot = bpy.ops.mesh.primitive_cube_add(
            size=1, location=boot_pos
        )
        boot_obj = bpy.context.active_object
        boot_obj.name = f"Boot_{i}"
        boot_obj.scale = (0.08, 0.15, 0.06)
        boot_obj.data.materials.append(mat_boots)
        boot_obj.parent = enemy
    
    # === 武器（AK风格步枪） ===
    # 枪身
    gun_body = bpy.ops.mesh.primitive_cube_add(
        size=1, location=(0.25, 0.15, 0.75)
    )
    gun_body_obj = bpy.context.active_object
    gun_body_obj.name = "GunBody"
    gun_body_obj.scale = (0.04, 0.08, 0.35)
    gun_body_obj.rotation_euler = (math.radians(90), 0, 0)
    gun_body_obj.data.materials.append(mat_gun)
    gun_body_obj.parent = enemy
    
    # 枪托
    stock = bpy.ops.mesh.primitive_cube_add(
        size=1, location=(0.25, -0.15, 0.78)
    )
    stock_obj = bpy.context.active_object
    stock_obj.name = "GunStock"
    stock_obj.scale = (0.03, 0.15, 0.06)
    stock_obj.rotation_euler = (math.radians(90), 0, 0)
    stock_obj.data.materials.append(mat_gun)
    stock_obj.parent = enemy
    
    # 弹夹
    mag = bpy.ops.mesh.primitive_cube_add(
        size=1, location=(0.25, 0.12, 0.65)
    )
    mag_obj = bpy.context.active_object
    mag_obj.name = "Magazine"
    mag_obj.scale = (0.03, 0.06, 0.08)
    mag_obj.rotation_euler = (math.radians(60), 0, 0)
    mag_obj.data.materials.append(mat_gun)
    mag_obj.parent = enemy
    
    # 枪口
    muzzle = bpy.ops.mesh.primitive_cylinder_add(
        radius=0.015, depth=0.08, location=(0.25, 0.15, 0.52)
    )
    muzzle_obj = bpy.context.active_object
    muzzle_obj.name = "Muzzle"
    muzzle_obj.rotation_euler = (math.radians(90), 0, 0)
    muzzle_obj.data.materials.append(mat_gun)
    muzzle_obj.parent = enemy
    
    # 瞄准镜
    sight = bpy.ops.mesh.primitive_cube_add(
        size=1, location=(0.25, 0.22, 0.75)
    )
    sight_obj = bpy.context.active_object
    sight_obj.name = "Sight"
    sight_obj.scale = (0.02, 0.04, 0.06)
    sight_obj.data.materials.append(mat_gun)
    sight_obj.parent = enemy
    
    # === 设置姿态 ===
    # 稍微前倾站立
    enemy.rotation_euler = (0, 0, 0)
    
    return enemy

# ===== 创建敌人 =====
enemy = create_human_enemy()

# ===== 应用变换 =====
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = enemy
enemy.select_set(True)

bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ===== 添加碰撞体 =====
bpy.ops.object.empty_add(type='CUBE', location=(0, 0, 0.9))
collision = bpy.context.active_object
collision.name = "CollisionBox"
collision.empty_display_size = 0.8
collision.scale = (0.35, 0.25, 1.0)
collision.parent = enemy

print("=" * 50)
print("人类士兵模型创建完成！")
print("名称: Enemy_Soldier")
print("身高: 约 1.7 米")
print("=" * 50)
print("导出方法:")
print("1. File -> Export -> glTF 2.0")
print("2. 选择 'Selected Objects'")
print("3. 导出为 .glb 格式")
print("4. 拖入 Godot 项目即可")
print("=" * 50)
