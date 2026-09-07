shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
    float height = 1.0 - UV.y;
    float sway = sin(height * 10.0 - TIME * 5.5) * 0.06 * height;
    float width = (1.0-height) * 0.38 + sin(height*17.0-TIME*9.0)*0.025;
    float edge = abs(UV.x-0.5+sway);
    float flame = 1.0-smoothstep(width-0.05,width+0.015,edge);
    float root = smoothstep(0.0,0.13,height);
    ALBEDO = mix(vec3(1.0,0.72,0.18),vec3(1.0,0.12,0.008),height);
    EMISSION = ALBEDO * 2.0;
    ALPHA = flame * root * (1.0-smoothstep(0.82,1.0,height)) * 0.9;
}
