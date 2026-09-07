"""Blender MCP build: deterministic irregular granite, independent staging scene."""
import bpy, math
from mathutils import Vector, noise
from pathlib import Path
root=Path('/Users/shaman/Desktop/Projects/Godot/TRIP')
scene=bpy.data.scenes.new('TRIP Granite Detailed');bpy.context.window.scene=scene
results=[]
for index,name in enumerate(['granite_round','granite_split','granite_moss']):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=1)
    ob=bpy.context.object;ob.name=name+'_detailed'
    offset=Vector((index*8.7,17.1,3.4))
    for v in ob.data.vertices:
        p=v.co.copy()
        broad=noise.noise_vector(p*1.5+offset).x
        fine=noise.noise_vector(p*7.0+offset).y
        p*=1.0+broad*.23+fine*.038
        p.x*=1.05+index*.1;p.y*=.83;p.z*=.75
        # Buried underside and asymmetric shoulders, no floating spherical base.
        p.z=max(p.z,-.56)+.5
        if index==1:p.x+=max(p.z-.55,0)*.25
        v.co=p
    for polygon in ob.data.polygons:polygon.use_smooth=True
    mat=bpy.data.materials.new(name+'_granite');mat.diffuse_color=(.32,.31,.28,1);mat.use_nodes=True
    mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.88
    ob.data.materials.append(mat)
    bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/taiga'/f'{name}.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False)
    results.append({'name':name,'triangles':len(ob.data.polygons)})
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art_sources/taiga/granite_detailed.blend'))
result={'models':results}
