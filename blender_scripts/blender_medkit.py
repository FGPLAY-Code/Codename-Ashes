"""绿洲行动 - 低多边形医疗包
Blender 脚本：File → Import → Run Script → 选择此文件
"""
import bpy
import os

def clear_scene():
    """清空场景"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def main():
    clear_scene()
    
    # ===== 1. 医疗包主体 =====
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    medkit = bpy.context.active_object
    medkit.name = "Medkit"
    medkit.scale = (0.4, 0.3, 0.12)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # ===== 2. 红色十字 =====
    # 横条
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.13))
    cross_h = bpy.context.active_object
    cross_h.name = "Cross_H"
    cross_h.scale = (0.22, 0.07, 0.01)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # 竖条
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.13))
    cross_v = bpy.context.active_object
    cross_v.name = "Cross_V"
    cross_v.scale = (0.07, 0.22, 0.01)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # ===== 3. 简单材质 =====
    # 白色材质
    mat_white = bpy.data.materials.new(name="MedkitWhite")
    mat_white.use_nodes = True
    nodes = mat_white.node_tree.nodes
    for node in nodes:
        if node.type == 'BSDF_PRINCIPLED':
            if 'Base Color' in node.inputs:
                node.inputs['Base Color'].default_value = (0.92, 0.92, 0.92, 1)
    
    # 红色材质
    mat_red = bpy.data.materials.new(name="MedkitRed")
    mat_red.use_nodes = True
    nodes_red = mat_red.node_tree.nodes
    for node in nodes_red:
        if node.type == 'BSDF_PRINCIPLED':
            if 'Base Color' in node.inputs:
                node.inputs['Base Color'].default_value = (0.9, 0.1, 0.1, 1)
    
    # 应用材质
    medkit.data.materials.append(mat_white)
    cross_h.data.materials.append(mat_red)
    cross_v.data.materials.append(mat_red)
    
    # 设置父级
    bpy.ops.object.select_all(action='DESELECT')
    medkit.select_set(True)
    cross_h.select_set(True)
    cross_v.select_set(True)
    bpy.context.view_layer.objects.active = medkit
    bpy.ops.object.parent_set()
    
    # ===== 4. 导出 GLB =====
    output_dir = r"E:\Godot\绿洲行动 demo\绿洲行动-demo\models"
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "medkit.glb")
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        use_selection=True
    )
    print(f"导出成功: {output_path}")

main()
