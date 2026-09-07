"""Original TRIP field equipment, executed in live Blender through official MCP.
Each exported part is modelled at metre scale with its origin at the work surface.
Hollow vessels have an inner wall and lip, not a solid top cap.
"""
import bpy, math, os
from pathlib import Path
source=Path('/Users/shaman/Desktop/Projects/Godot/TRIP/art_sources/menu_camp/build_menu.py').read_text()
exec(source.split('variants=')[0].replace("TRIP Menu • Cedar clearing","TRIP • Field laboratory"))
OUT=ROOT+'/assets/models/laboratory'
os.makedirs(OUT,exist_ok=True)
leather=material('Bellows • worn russet leather',(.23,.085,.033))
canvas=material('Waxed canvas • olive',(.25,.29,.15))
paper=material('Recipe folios • aged paper',(.65,.55,.32))
amber=material('Amber glazed vessel',(.36,.17,.045),.24)
def box(m,p,s,mat):
    x,y,z=p;a,b,c=[v/2 for v in s]
    v=[(x+dx*a,y+dy*b,z+dz*c) for dz in [-1,1] for dy in [-1,1] for dx in [-1,1]]
    for f in [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]:m.face([v[i] for i in f],mat)
def vessel(m,p,profile,mat,n=24):
    # Profile travels up outside, over lip, down inside, then to bowl floor.
    x,y,z=p;rings=[[(x+r*math.cos(i*math.tau/n),y+r*math.sin(i*math.tau/n),z+h) for i in range(n)] for r,h in profile]
    for a,b in zip(rings,rings[1:]):
        for i in range(n):m.face([a[i],a[(i+1)%n],b[(i+1)%n],b[i]],mat)
    m.face(list(reversed(rings[0])),mat);m.face(rings[-1],mat)
def arc(m,center,r,mat,axis='z',start=0,end=math.tau):
    x,y,z=center;ps=[]
    for i in range(25):
        a=start+(end-start)*i/24
        ps.append((x+r*math.cos(a),y+r*math.sin(a),z) if axis=='z' else (x+r*math.cos(a),y,z+r*math.sin(a)))
    m.tube(ps,[.018]*len(ps),mat,6)
models={}
def save(m,key):
    ob=m.finish();models[key]=ob
    with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=OUT+'/'+key+'.glb',export_format='GLB',use_selection=True,use_active_scene=True)
    return ob
m=Mesh('Workbench • pegged cedar trestles')
for i in range(5):box(m,(0,-.52+i*.26,.98),(4.9,.248,.10),wood if i%2 else bark)
for x in [-2.05,2.05]:
    for y in [-.44,.44]:m.tube([(x*1.06,y*1.25,0),(x,y,.96)],[.085,.075],bark,6)
    box(m,(x,0,.79),(.14,1.23,.14),bark)
box(m,(0,0,.30),(4.3,.10,.12),bark)
for x in [-2.05,2.05]:
    for y in [-.43,.43]:m.tube([(x,y,1.03),(x,y,1.037)],[.022,.022],iron,8)
save(m,'workbench')
m=Mesh('Mortar • carved granite bowl')
vessel(m,(0,0,0),[(.13,0),(.19,.05),(.22,.22),(.215,.26),(.18,.26),(.16,.10),(.045,.075)],stone)
arc(m,(0,0,.23),.216,stone2);save(m,'mortar')
m=Mesh('Pestle • polished granite')
m.tube([(0,0,-.15),(0,0,-.08),(0,0,.14),(0,0,.22)],[.07,.065,.032,.048],stone2,12);save(m,'pestle')
m=Mesh('Cauldron • open cast iron with riveted ears')
vessel(m,(0,0,0),[(.15,0),(.27,.07),(.32,.22),(.30,.36),(.275,.38),(.25,.38),(.275,.22),(.235,.09),(.08,.05)],iron)
arc(m,(0,0,.365),.292,iron)
arc(m,(0,0,.31),.34,iron,'y',0,math.pi)
for x in [-.30,.30]:box(m,(x,0,.30),(.065,.07,.1),iron)
save(m,'cauldron')
m=Mesh('Wash basin • coopered cedar')
vessel(m,(0,0,0),[(.18,0),(.25,.25),(.23,.27),(.21,.24),(.15,.04)],wood)
for z,r in [(.05,.194),(.22,.241)]:arc(m,(0,0,z),r,iron)
save(m,'basin')
for key,mat in [('water_jug',ceramic),('kvass_jug',amber),('spirit_flask',copper)]:
    m=Mesh(key+' • handled field vessel')
    vessel(m,(0,0,0),[(.10,0),(.15,.05),(.16,.24),(.10,.33),(.055,.36),(.055,.43),(.035,.43),(.035,.36),(.08,.31),(.12,.22),(.06,.035)],mat)
    arc(m,(.13,0,.23),.105,mat,'y',-math.pi*.6,math.pi*.6)
    save(m,key)
m=Mesh('Preparation • end grain board and field knife')
for i in range(6):box(m,(-.25+i*.10,0,0),(.097,.36,.035),wood if i%2 else bark)
box(m,(.14,-.02,.038),(.055,.16,.045),bark)
m.face([(.11,.06,.045),(.165,.06,.045),(.165,.27,.045),(.11,.20,.045)],iron)
save(m,'prep_board')
m=Mesh('Ladle • carved wooden cup')
vessel(m,(0,0,-.04),[(.05,0),(.10,.06),(.08,.075),(.06,.025)],wood,16)
m.tube([(0,.065,0),(0,.28,.055),(0,.57,.08)],[.023,.021,.032],wood,8);save(m,'ladle')
m=Mesh('Sample rack • corked amber bottles')
for y in [-.1,.1]:box(m,(0,y,.10),(.62,.04,.20),bark)
box(m,(0,0,.01),(.66,.28,.035),wood)
for x in [-.22,0,.22]:
    vessel(m,(x,0,.035),[(.055,0),(.064,.17),(.032,.21),(.028,.25),(.020,.25),(.02,.20),(.04,.15)],amber,16)
    m.tube([(x,0,.24),(x,0,.28)],[.025,.026],wood,8)
save(m,'bottle_rack')
m=Mesh('Bellows • pleated leather and oak handles')
for z in [0,.16]:
    m.face([(-.32,0,z),(0,-.18,z),(.27,-.12,z),(.33,0,z),(.27,.12,z),(0,.18,z)],wood)
for i in range(5):
    r=.17 if i%2 else .145
    m.tube([(-.23,0,.03+i*.027),(.19,0,.03+i*.027)],[r,r],leather,6)
m.tube([(-.28,0,.08),(-.58,0,.08)],[.065,.024],copper,10)
for z in [0,.16]:box(m,(.43,0,z),(.28,.07,.035),wood)
save(m,'bellows')
m=Mesh('Hourglass • braced brass frame')
for z in [-.22,.22]:box(m,(0,0,z),(.27,.24,.03),wood)
for x in [-.105,.105]:
    for y in [-.09,.09]:m.tube([(x,y,-.21),(x,y,.21)],[.012,.012],copper,6)
vessel(m,(0,0,-.19),[(.07,0),(.09,.03),(.018,.19),(.09,.35),(.075,.38)],ceramic,16)
save(m,'hourglass')
m=Mesh('Alembic • hammered copper and cooling spiral')
vessel(m,(-.17,0,0),[(.12,0),(.18,.05),(.19,.22),(.12,.32),(.055,.4)],copper)
ps=[(-.17,0,.4),(-.17,0,.54),(.12,0,.57),(.27,0,.45)]
ps +=[(.27+.08*math.cos(i*.45),.08*math.sin(i*.45),.44-i*.008) for i in range(45)]
ps +=[(.30,0,.045),(.44,0,.045)]
m.tube(ps,[.018]*len(ps),copper,8)
vessel(m,(.44,0,0),[(.05,0),(.065,.12),(.035,.15),(.028,.15),(.04,.03)],ceramic,16)
save(m,'distiller')
m=Mesh('Serving • wide ceramic bowl')
vessel(m,(0,0,0),[(.09,0),(.19,.13),(.17,.15),(.145,.11),(.055,.03)],ceramic);save(m,'serving_bowl')
m=Mesh('Crate • slatted cedar and iron corners')
for y in [-.3,.3]:
    for z in [.1,.26,.42]:box(m,(0,y,z),(.75,.045,.14),bark)
for x in [-.36,.36]:
    for z in [.1,.26,.42]:box(m,(x,0,z),(.045,.6,.14),wood)
    for y in [-.28,.28]:box(m,(x,y,.26),(.06,.06,.49),iron)
box(m,(0,0,.035),(.72,.58,.055),wood);save(m,'crate')
m=Mesh('Canopy • sagging waxed canvas, ridge and lashings')
for x in [-2.65,2.65]:
    for y in [-.95,.95]:
        m.tube([(x,y,0),(x,y,2.12)],[.045,.034],bark,7)
        m.tube([(x,y,2.06),(x*1.15,y*1.4,.02)],[.007,.007],wood,5)
for x in [-2.65,2.65]:m.tube([(x,0,0),(x,0,2.75)],[.05,.035],bark,7)
m.tube([(-2.7,0,2.72),(2.7,0,2.72)],[.038,.038],bark,7)
for i in range(16):
    for j in range(8):
        vs=[]
        for a,b in [(i,j),(i+1,j),(i+1,j+1),(i,j+1)]:
            x=-2.7+a*5.4/16;y=-1.12+b*2.24/8;z=2.72-abs(y)*.48-.16*math.sin(a*math.pi/16)+.018*math.sin(a*3)
            vs.append((x,y,z))
        m.face(vs,canvas);m.face(list(reversed(vs)),canvas)
save(m,'canopy')
m=Mesh('Drying rack • twine and suspended herbs')
for x in [-.5,.5]:m.tube([(x,0,0),(x,0,1.7)],[.04,.03],bark,7)
m.tube([(-.55,0,1.65),(.55,0,1.65)],[.04,.04],bark,7)
for x in [-.36,-.12,.12,.36]:
    m.tube([(x,0,1.64),(x,0,1.30)],[.006,.006],wood,4)
    for j in range(5):m.leaf((x,0,1.33),(math.cos(j*1.26)*.3,math.sin(j*1.26)*.3,-1),.38,.06,larch)
save(m,'drying_rack')
m=Mesh('Spore filter • cloth cartridge and brass housing')
vessel(m,(0,0,0),[(.12,0),(.16,.1),(.14,.38),(.1,.42),(.07,.42),(.1,.12)],copper)
for z in [.12,.20,.28,.36]:arc(m,(0,0,z),.148,iron)
box(m,(0,0,.43),(.18,.18,.018),canvas);save(m,'spore_filter')
m=Mesh('Root resonator • ceramic root cradle')
vessel(m,(0,0,0),[(.12,0),(.18,.06),(.18,.16),(.15,.18),(.12,.07)],ceramic)
for i in range(4):m.tube([(0,0,.1),(.12*math.cos(i*1.6),.12*math.sin(i*1.6),.28),(.17*math.cos(i*1.6),.17*math.sin(i*1.6),.53)],[.03,.021,.005],bark,7)
save(m,'root_resonator')
m=Mesh('Mirror separator • dark polished stone in brass frame')
box(m,(0,0,.02),(.36,.25,.04),wood)
box(m,(0,0,.28),(.23,.035,.42),iron)
for x in [-.14,.14]:m.tube([(x,0,.02),(x,0,.53)],[.015,.015],copper,8)
m.tube([(-.14,0,.53),(.14,0,.53)],[.015,.015],copper,8);save(m,'mirror_separator')
m=Mesh('Concordance • double helical copper coil')
box(m,(0,0,.025),(.4,.4,.05),wood)
for shift in [0,math.pi]:
    ps=[(.14*math.cos(i*.22+shift),.14*math.sin(i*.22+shift),.06+i*.008) for i in range(75)]
    m.tube(ps,[.015]*75,copper,6)
vessel(m,(0,0,.05),[(.07,0),(.06,.45),(.035,.5)],ceramic,16);save(m,'concordance_coil')
# Keep source as a neat asset sheet. Exported origins remain local.
for i,(key,ob) in enumerate(models.items()):ob.location=((i%5)*6,(i//5)*4,0)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art_sources/laboratory/field_laboratory.blend')
result={'models':list(models),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in models.values()),'directory':OUT}
