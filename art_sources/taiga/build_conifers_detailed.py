"""Detailed evergreen branch structure. Run through Blender MCP.
Keeps old scenes intact; only exports the four explicitly named game assets.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
root=Path('/Users/shaman/Desktop/Projects/Godot/TRIP')
source=(root/'art_sources/menu_camp/build_menu.py').read_text()
exec(source.split('variants=')[0].replace('TRIP Menu • Cedar clearing','TRIP Detailed Conifers'))
records=[]
for index,(name,height,fir) in enumerate([('cedar',8,False),('fir',10,True),('young_fir',3.5,True),('wind_cedar',6,False)]):
    R=random.Random(9834+index)
    m=Mesh(name+'_detailed')
    lean=.7 if index==3 else .16
    def trunk_at(z):return Vector((lean*(z/height)**1.7, .12*math.sin(z*.6),z))
    m.tube([trunk_at(height*t/12) for t in range(13)], [max(.018,height*.035*(1-t/12)**1.15) for t in range(13)],bark,14)
    for j in range(7):
        a=j*math.tau/7
        m.tube([Vector((math.cos(a)*.85,math.sin(a)*.85,.01)),Vector((math.cos(a)*.35,math.sin(a)*.35,.18)),trunk_at(.6)],[.06,.13,.18],bark,7)
    # Distinct whorls, curved boughs, and narrower compound sprays instead of
    # the original large polygon leaves / decimated crown lumps.
    for tier in range(12):
        z=height*(.18+tier*.065)+R.uniform(-.13,.13)
        radius=height*(.27-tier*.020)*(1 if fir else 1.15)
        for j in range(6):
            a=j*math.tau/6+tier*1.13+R.uniform(-.24,.24)
            d=Vector((math.cos(a),math.sin(a),0))
            base=trunk_at(z)
            tip=base+d*radius+Vector((0,0,-radius*.15 if fir else radius*.08))
            middle=base.lerp(tip,.53)+Vector((0,0,-.12))
            m.tube([base,middle,tip],[max(.025,radius*.037),.025,.006],bark,7)
            for k in range(1,8):
                center=base.lerp(tip,k/8)+Vector((0,0,-.08*math.sin(k/8*math.pi)))
                for sign in [-1,1]:
                    direction=Vector((math.cos(a+sign*.82),math.sin(a+sign*.82),R.uniform(-.15,.25))).normalized()
                    length=radius*.38*(1-k/10)
                    end=center+direction*length
                    m.tube([center,end],[.009,.002],bark,4)
                    # Fine needles form radial sprays; no broad opaque leaf planes.
                    side=direction.cross(Vector((0,0,1))).normalized()
                    up=side.cross(direction).normalized()
                    for q in range(6):
                        p=center.lerp(end,(q+.4)/6)
                        for angle in [0,3.14]:
                            radial=side*math.cos(angle+q*.7)+up*math.sin(angle+q*.7)
                            nd=(radial*.78+direction*.6).normalized()
                            nlen=min(.3,height*.04)*R.uniform(.7,1.25)*(1-q*.025)
                            # Two narrow facets give volume and light response.
                            m.leaf(p,nd,nlen,.023 if fir else .028,tips if q>4 else pine)
    ob=m.finish()
    for poly in ob.data.polygons:
        if poly.material_index==bark:poly.use_smooth=True
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/taiga'/f'{name}.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False)
    records.append({'name':name,'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons)})
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art_sources/taiga/conifers_detailed.blend'))
result={'models':records}
