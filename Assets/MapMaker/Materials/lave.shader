Shader "Custom/NewSurfaceShader"
{
    Properties {
	    texture_1 ("Texture 1", 2D) = "white" {}
	    texture_2 ("Texture 2", 2D) = "white" {}
	    texture_3 ("Texture 3", 2D) = "white" {}
	    texture_4 ("Texture 4", 2D) = "white" {}
	    _MainTex ("Foo", 2D) = "white" {}
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0
		
        sampler2D _MainTex;
        struct Input {
            float2 uv_MainTex;
        };
        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)
		
#define hlsl_atan(x,y) atan2(x, y)
#define mod(x,y) ((x)-(y)*floor((x)/(y)))
inline float4 textureLod(sampler2D tex, float2 uv, float lod) {
    return tex2D(tex, uv);
}
inline float2 tofloat2(float x) {
    return float2(x, x);
}
inline float2 tofloat2(float x, float y) {
    return float2(x, y);
}
inline float3 tofloat3(float x) {
    return float3(x, x, x);
}
inline float3 tofloat3(float x, float y, float z) {
    return float3(x, y, z);
}
inline float3 tofloat3(float2 xy, float z) {
    return float3(xy.x, xy.y, z);
}
inline float3 tofloat3(float x, float2 yz) {
    return float3(x, yz.x, yz.y);
}
inline float4 tofloat4(float x, float y, float z, float w) {
    return float4(x, y, z, w);
}
inline float4 tofloat4(float x) {
    return float4(x, x, x, x);
}
inline float4 tofloat4(float x, float3 yzw) {
    return float4(x, yzw.x, yzw.y, yzw.z);
}
inline float4 tofloat4(float2 xy, float2 zw) {
    return float4(xy.x, xy.y, zw.x, zw.y);
}
inline float4 tofloat4(float3 xyz, float w) {
    return float4(xyz.x, xyz.y, xyz.z, w);
}
inline float2x2 tofloat2x2(float2 v1, float2 v2) {
    return float2x2(v1.x, v1.y, v2.x, v2.y);
}

// EngineSpecificDefinitions


float rand(float2 x) {
    return frac(cos(mod(dot(x, tofloat2(13.9898, 8.141)), 3.14)) * 43758.5453);
}

float2 rand2(float2 x) {
    return frac(cos(mod(tofloat2(dot(x, tofloat2(13.9898, 8.141)),
						      dot(x, tofloat2(3.4562, 17.398))), tofloat2(3.14))) * 43758.5453);
}

float3 rand3(float2 x) {
    return frac(cos(mod(tofloat3(dot(x, tofloat2(13.9898, 8.141)),
							  dot(x, tofloat2(3.4562, 17.398)),
                              dot(x, tofloat2(13.254, 5.867))), tofloat3(3.14))) * 43758.5453);
}

float param_rnd(float minimum, float maximum, float seed) {
	return minimum+(maximum-minimum)*rand(tofloat2(seed));
}

float3 rgb2hsv(float3 c) {
	float4 K = tofloat4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	float4 p = c.g < c.b ? tofloat4(c.bg, K.wz) : tofloat4(c.gb, K.xy);
	float4 q = c.r < p.x ? tofloat4(p.xyw, c.r) : tofloat4(c.r, p.yzx);

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return tofloat3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c) {
	float4 K = tofloat4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


float fbm_value(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float p00 = rand(mod(o, size));
	float p01 = rand(mod(o + tofloat2(0.0, 1.0), size));
	float p10 = rand(mod(o + tofloat2(1.0, 0.0), size));
	float p11 = rand(mod(o + tofloat2(1.0, 1.0), size));
	float2 t =  f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return lerp(lerp(p00, p10, t.x), lerp(p01, p11, t.x), t.y);
}

float fbm_perlin(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float a00 = rand(mod(o, size)) * 6.28318530718;
	float a01 = rand(mod(o + tofloat2(0.0, 1.0), size)) * 6.28318530718;
	float a10 = rand(mod(o + tofloat2(1.0, 0.0), size)) * 6.28318530718;
	float a11 = rand(mod(o + tofloat2(1.0, 1.0), size)) * 6.28318530718;
	float2 v00 = tofloat2(cos(a00), sin(a00));
	float2 v01 = tofloat2(cos(a01), sin(a01));
	float2 v10 = tofloat2(cos(a10), sin(a10));
	float2 v11 = tofloat2(cos(a11), sin(a11));
	float p00 = dot(v00, f);
	float p01 = dot(v01, f - tofloat2(0.0, 1.0));
	float p10 = dot(v10, f - tofloat2(1.0, 0.0));
	float p11 = dot(v11, f - tofloat2(1.0, 1.0));
	float2 t =  f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return 0.5 + lerp(lerp(p00, p10, t.x), lerp(p01, p11, t.x), t.y);
}

float fbm_perlinabs(float2 coord, float2 size, float seed) {
	return abs(2.0*fbm_perlin(coord, size, seed)-1.0);
}

float2 rgrad2(float2 p, float rot, float seed) {
	float u = rand(p + tofloat2(seed, 1.0-seed));
	u = frac(u) * 6.28318530718; // 2*pi
	return tofloat2(cos(u), sin(u));
}

float fbm_simplex(float2 coord, float2 size, float seed) {
	coord *= 2.0; // needed for it to tile
	coord += rand2(tofloat2(seed, 1.0-seed)) + size;
	size *= 2.0; // needed for it to tile
	coord.y += 0.001;
    float2 uv = tofloat2(coord.x + coord.y*0.5, coord.y);
    float2 i0 = floor(uv);
    float2 f0 = frac(uv);
    float2 i1 = (f0.x > f0.y) ? tofloat2(1.0, 0.0) : tofloat2(0.0, 1.0);
    float2 p0 = tofloat2(i0.x - i0.y * 0.5, i0.y);
    float2 p1 = tofloat2(p0.x + i1.x - i1.y * 0.5, p0.y + i1.y);
    float2 p2 = tofloat2(p0.x + 0.5, p0.y + 1.0);
    i1 = i0 + i1;
    float2 i2 = i0 + tofloat2(1.0, 1.0);
    float2 d0 = coord - p0;
    float2 d1 = coord - p1;
    float2 d2 = coord - p2;
    float3 xw = mod(tofloat3(p0.x, p1.x, p2.x), size.x);
    float3 yw = mod(tofloat3(p0.y, p1.y, p2.y), size.y);
    float3 iuw = xw + 0.5 * yw;
    float3 ivw = yw;
    float2 g0 = rgrad2(tofloat2(iuw.x, ivw.x), 0.0, seed);
    float2 g1 = rgrad2(tofloat2(iuw.y, ivw.y), 0.0, seed);
    float2 g2 = rgrad2(tofloat2(iuw.z, ivw.z), 0.0, seed);
    float3 w = tofloat3(dot(g0, d0), dot(g1, d1), dot(g2, d2));
    float3 t = 0.8 - tofloat3(dot(d0, d0), dot(d1, d1), dot(d2, d2));
    t = max(t, tofloat3(0.0));
    float3 t2 = t * t;
    float3 t4 = t2 * t2;
    float n = dot(t4, w);
    return 0.5 + 5.5 * n;
}

float fbm_cellular(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float min_dist = 2.0;
	for(float x = -1.0; x <= 1.0; x++) {
		for(float y = -1.0; y <= 1.0; y++) {
			float2 node = rand2(mod(o + tofloat2(x, y), size)) + tofloat2(x, y);
			float dist = sqrt((f - node).x * (f - node).x + (f - node).y * (f - node).y);
			min_dist = min(min_dist, dist);
		}
	}
	return min_dist;
}

float fbm_cellular2(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float min_dist1 = 2.0;
	float min_dist2 = 2.0;
	for(float x = -1.0; x <= 1.0; x++) {
		for(float y = -1.0; y <= 1.0; y++) {
			float2 node = rand2(mod(o + tofloat2(x, y), size)) + tofloat2(x, y);
			float dist = sqrt((f - node).x * (f - node).x + (f - node).y * (f - node).y);
			if (min_dist1 > dist) {
				min_dist2 = min_dist1;
				min_dist1 = dist;
			} else if (min_dist2 > dist) {
				min_dist2 = dist;
			}
		}
	}
	return min_dist2-min_dist1;
}

float fbm_cellular3(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float min_dist = 2.0;
	for(float x = -1.0; x <= 1.0; x++) {
		for(float y = -1.0; y <= 1.0; y++) {
			float2 node = rand2(mod(o + tofloat2(x, y), size))*0.5 + tofloat2(x, y);
			float dist = abs((f - node).x) + abs((f - node).y);
			min_dist = min(min_dist, dist);
		}
	}
	return min_dist;
}

float fbm_cellular4(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float min_dist1 = 2.0;
	float min_dist2 = 2.0;
	for(float x = -1.0; x <= 1.0; x++) {
		for(float y = -1.0; y <= 1.0; y++) {
			float2 node = rand2(mod(o + tofloat2(x, y), size))*0.5 + tofloat2(x, y);
			float dist = abs((f - node).x) + abs((f - node).y);
			if (min_dist1 > dist) {
				min_dist2 = min_dist1;
				min_dist1 = dist;
			} else if (min_dist2 > dist) {
				min_dist2 = dist;
			}
		}
	}
	return min_dist2-min_dist1;
}

float fbm_cellular5(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float min_dist = 2.0;
	for(float x = -1.0; x <= 1.0; x++) {
		for(float y = -1.0; y <= 1.0; y++) {
			float2 node = rand2(mod(o + tofloat2(x, y), size)) + tofloat2(x, y);
			float dist = max(abs((f - node).x), abs((f - node).y));
			min_dist = min(min_dist, dist);
		}
	}
	return min_dist;
}

float fbm_cellular6(float2 coord, float2 size, float seed) {
	float2 o = floor(coord)+rand2(tofloat2(seed, 1.0-seed))+size;
	float2 f = frac(coord);
	float min_dist1 = 2.0;
	float min_dist2 = 2.0;
	for(float x = -1.0; x <= 1.0; x++) {
		for(float y = -1.0; y <= 1.0; y++) {
			float2 node = rand2(mod(o + tofloat2(x, y), size)) + tofloat2(x, y);
			float dist = max(abs((f - node).x), abs((f - node).y));
			if (min_dist1 > dist) {
				min_dist2 = min_dist1;
				min_dist1 = dist;
			} else if (min_dist2 > dist) {
				min_dist2 = dist;
			}
		}
	}
	return min_dist2-min_dist1;
}

uniform sampler2D texture_1;
static const float texture_1_size = 1024.0;

float2 transform2_clamp(float2 uv) {
	return clamp(uv, tofloat2(0.0), tofloat2(1.0));
}

float2 transform2(float2 uv, float2 translate, float rotate, float2 scale) {
 	float2 rv;
	uv -= translate;
	uv -= tofloat2(0.5);
	rv.x = cos(rotate)*uv.x + sin(rotate)*uv.y;
	rv.y = -sin(rotate)*uv.x + cos(rotate)*uv.y;
	rv /= scale;
	rv += tofloat2(0.5);
	return rv;	
}
uniform sampler2D texture_2;
static const float texture_2_size = 1024.0;

float3 blend_normal(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*c1 + (1.0-opacity)*c2;
}

float3 blend_dissolve(float2 uv, float3 c1, float3 c2, float opacity) {
	if (rand(uv) < opacity) {
		return c1;
	} else {
		return c2;
	}
}

float3 blend_multiply(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*c1*c2 + (1.0-opacity)*c2;
}

float3 blend_screen(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*(1.0-(1.0-c1)*(1.0-c2)) + (1.0-opacity)*c2;
}

float blend_overlay_f(float c1, float c2) {
	return (c1 < 0.5) ? (2.0*c1*c2) : (1.0-2.0*(1.0-c1)*(1.0-c2));
}

float3 blend_overlay(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*tofloat3(blend_overlay_f(c1.x, c2.x), blend_overlay_f(c1.y, c2.y), blend_overlay_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}

float3 blend_hard_light(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*0.5*(c1*c2+blend_overlay(uv, c1, c2, 1.0)) + (1.0-opacity)*c2;
}

float blend_soft_light_f(float c1, float c2) {
	return (c2 < 0.5) ? (2.0*c1*c2+c1*c1*(1.0-2.0*c2)) : 2.0*c1*(1.0-c2)+sqrt(c1)*(2.0*c2-1.0);
}

float3 blend_soft_light(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*tofloat3(blend_soft_light_f(c1.x, c2.x), blend_soft_light_f(c1.y, c2.y), blend_soft_light_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}

float blend_burn_f(float c1, float c2) {
	return (c1==0.0)?c1:max((1.0-((1.0-c2)/c1)),0.0);
}

float3 blend_burn(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*tofloat3(blend_burn_f(c1.x, c2.x), blend_burn_f(c1.y, c2.y), blend_burn_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}

float blend_dodge_f(float c1, float c2) {
	return (c1==1.0)?c1:min(c2/(1.0-c1),1.0);
}

float3 blend_dodge(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*tofloat3(blend_dodge_f(c1.x, c2.x), blend_dodge_f(c1.y, c2.y), blend_dodge_f(c1.z, c2.z)) + (1.0-opacity)*c2;
}

float3 blend_lighten(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*max(c1, c2) + (1.0-opacity)*c2;
}

float3 blend_darken(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*min(c1, c2) + (1.0-opacity)*c2;
}

float3 blend_difference(float2 uv, float3 c1, float3 c2, float opacity) {
	return opacity*clamp(c2-c1, tofloat3(0.0), tofloat3(1.0)) + (1.0-opacity)*c2;
}

float3 process_normal_default(float3 v, float multiplier) {
	return 0.5*normalize(v.xyz*multiplier+tofloat3(0.0, 0.0, -1.0))+tofloat3(0.5);
}

float3 process_normal_opengl(float3 v, float multiplier) {
	return 0.5*normalize(v.xyz*multiplier+tofloat3(0.0, 0.0, 1.0))+tofloat3(0.5);
}

float3 process_normal_directx(float3 v, float multiplier) {
	return 0.5*normalize(v.xyz*tofloat3(1.0, -1.0, 1.0)*multiplier+tofloat3(0.0, 0.0, 1.0))+tofloat3(0.5);
}

static const float p_o40964_albedo_color_r = 1.000000000;
static const float p_o40964_albedo_color_g = 1.000000000;
static const float p_o40964_albedo_color_b = 1.000000000;
static const float p_o40964_albedo_color_a = 1.000000000;
static const float p_o40964_metallic = 0.000000000;
static const float p_o40964_roughness = 1.000000000;
static const float p_o40964_emission_energy = 3.000000000;
static const float p_o40964_normal = 1.000000000;
static const float p_o40964_ao = 1.000000000;
static const float p_o40964_depth_scale = 1.000000000;
static const float p_o41367_translate_x = 0.250000000;
static const float p_o41367_rotate = 0.000000000;
static const float p_o41367_scale_x = 1.000000000;
static const float p_o41367_scale_y = 1.000000000;
static const float seed_o41369 = -57371.000000000;
static const float p_o41369_scale_x = 1.000000000;
static const float p_o41369_scale_y = 1.000000000;
static const float p_o41369_folds = 0.000000000;
static const float p_o41369_iterations = 3.000000000;
static const float p_o41369_persistence = 0.500000000;
float o41369_fbm(float2 coord, float2 size, int folds, int octaves, float persistence, float seed, float _seed_variation_) {
	float normalize_factor = 0.0;
	float value = 0.0;
	float scale = 1.0;
	for (int i = 0; i < octaves; i++) {
		float noise = fbm_value(coord*size, size, seed);
		for (int f = 0; f < folds; ++f) {
			noise = abs(2.0*noise-1.0);
		}
		value += noise * scale;
		normalize_factor += scale;
		size *= 2.0;
		scale *= persistence;
	}
	return value / normalize_factor;
}
float o40964_input_depth_tex(float2 uv, float _seed_variation_) {
float o41369_0_1_f = o41369_fbm((uv), tofloat2(p_o41369_scale_x, p_o41369_scale_y), int(p_o41369_folds), int(p_o41369_iterations), p_o41369_persistence, (seed_o41369+_seed_variation_), _seed_variation_);
float4 o40995_0 = textureLod(texture_1, (frac(transform2((uv), tofloat2(p_o41367_translate_x*(2.0*o41369_0_1_f-1.0), (_Time.y*.05)*(2.0*1.0-1.0)), p_o41367_rotate*0.01745329251*(2.0*1.0-1.0), tofloat2(p_o41367_scale_x*(2.0*1.0-1.0), p_o41367_scale_y*(2.0*1.0-1.0))))), 0.0);
float4 o40994_0_1_rgba = tofloat4(tofloat3(1.0)-o40995_0.rgb, o40995_0.a);
float4 o41367_0_1_rgba = o40994_0_1_rgba;

return (dot((o41367_0_1_rgba).rgb, tofloat3(1.0))/3.0);
}
static const float p_o41364_translate_x = 0.250000000;
static const float p_o41364_rotate = 0.000000000;
static const float p_o41364_scale_x = 1.000000000;
static const float p_o41364_scale_y = 1.000000000;
static const float p_o40966_amount = 0.300000000;
static const float p_o41425_gradient_0_pos = 0.113748000;
static const float p_o41425_gradient_0_r = 0.945312023;
static const float p_o41425_gradient_0_g = 0.825215995;
static const float p_o41425_gradient_0_b = 0.276946992;
static const float p_o41425_gradient_0_a = 1.000000000;
static const float p_o41425_gradient_1_pos = 0.233667000;
static const float p_o41425_gradient_1_r = 0.820312023;
static const float p_o41425_gradient_1_g = 0.288841993;
static const float p_o41425_gradient_1_b = 0.201874003;
static const float p_o41425_gradient_1_a = 1.000000000;
static const float p_o41425_gradient_2_pos = 0.391878000;
static const float p_o41425_gradient_2_r = 0.222655997;
static const float p_o41425_gradient_2_g = 0.152294993;
static const float p_o41425_gradient_2_b = 0.127853006;
static const float p_o41425_gradient_2_a = 1.000000000;
float4 o41425_gradient_gradient_fct(float x) {
  if (x < p_o41425_gradient_0_pos) {
    return tofloat4(p_o41425_gradient_0_r,p_o41425_gradient_0_g,p_o41425_gradient_0_b,p_o41425_gradient_0_a);
  } else if (x < p_o41425_gradient_1_pos) {
    return lerp(tofloat4(p_o41425_gradient_0_r,p_o41425_gradient_0_g,p_o41425_gradient_0_b,p_o41425_gradient_0_a), tofloat4(p_o41425_gradient_1_r,p_o41425_gradient_1_g,p_o41425_gradient_1_b,p_o41425_gradient_1_a), ((x-p_o41425_gradient_0_pos)/(p_o41425_gradient_1_pos-p_o41425_gradient_0_pos)));
  } else if (x < p_o41425_gradient_2_pos) {
    return lerp(tofloat4(p_o41425_gradient_1_r,p_o41425_gradient_1_g,p_o41425_gradient_1_b,p_o41425_gradient_1_a), tofloat4(p_o41425_gradient_2_r,p_o41425_gradient_2_g,p_o41425_gradient_2_b,p_o41425_gradient_2_a), ((x-p_o41425_gradient_1_pos)/(p_o41425_gradient_2_pos-p_o41425_gradient_1_pos)));
  }
  return tofloat4(p_o41425_gradient_2_r,p_o41425_gradient_2_g,p_o41425_gradient_2_b,p_o41425_gradient_2_a);
}
static const float p_o41366_translate_x = 0.250000000;
static const float p_o41366_rotate = 0.000000000;
static const float p_o41366_scale_x = 1.000000000;
static const float p_o41366_scale_y = 1.000000000;
static const float p_o40974_amount = 1.000000000;
float o40974_input_in(float2 uv, float _seed_variation_) {
float4 o40995_0 = textureLod(texture_1, uv, 0.0);

return (dot((o40995_0).rgb, tofloat3(1.0))/3.0);
}
float3 o40974_fct(float2 uv, float _seed_variation_) {
	float3 e = tofloat3(1.0/1024.000000000, -1.0/1024.000000000, 0);
	float2 rv = tofloat2(1.0, -1.0)*o40974_input_in(uv+e.xy, _seed_variation_);
	rv += tofloat2(-1.0, 1.0)*o40974_input_in(uv-e.xy, _seed_variation_);
	rv += tofloat2(1.0, 1.0)*o40974_input_in(uv+e.xx, _seed_variation_);
	rv += tofloat2(-1.0, -1.0)*o40974_input_in(uv-e.xx, _seed_variation_);
	rv += tofloat2(2.0, 0.0)*o40974_input_in(uv+e.xz, _seed_variation_);
	rv += tofloat2(-2.0, 0.0)*o40974_input_in(uv-e.xz, _seed_variation_);
	rv += tofloat2(0.0, 2.0)*o40974_input_in(uv+e.zx, _seed_variation_);
	rv += tofloat2(0.0, -2.0)*o40974_input_in(uv-e.zx, _seed_variation_);
	return tofloat3(rv, 0.0);
}

		
        void surf (Input IN, inout SurfaceOutputStandard o) {
      		float _seed_variation_ = 0.0;
			float2 uv = IN.uv_MainTex;
float o41369_0_1_f = o41369_fbm((uv), tofloat2(p_o41369_scale_x, p_o41369_scale_y), int(p_o41369_folds), int(p_o41369_iterations), p_o41369_persistence, (seed_o41369+_seed_variation_), _seed_variation_);
float4 o41452_0 = textureLod(texture_2, (frac(transform2((uv), tofloat2(p_o41364_translate_x*(2.0*o41369_0_1_f-1.0), (_Time.y*.05)*(2.0*1.0-1.0)), p_o41364_rotate*0.01745329251*(2.0*1.0-1.0), tofloat2(p_o41364_scale_x*(2.0*1.0-1.0), p_o41364_scale_y*(2.0*1.0-1.0))))), 0.0);
float4 o40995_0 = textureLod(texture_1, (frac(transform2((uv), tofloat2(p_o41364_translate_x*(2.0*o41369_0_1_f-1.0), (_Time.y*.05)*(2.0*1.0-1.0)), p_o41364_rotate*0.01745329251*(2.0*1.0-1.0), tofloat2(p_o41364_scale_x*(2.0*1.0-1.0), p_o41364_scale_y*(2.0*1.0-1.0))))), 0.0);
float4 o41425_0_1_rgba = o41425_gradient_gradient_fct((dot((o40995_0).rgb, tofloat3(1.0))/3.0));
float4 o40966_0_s1 = o41452_0;
float4 o40966_0_s2 = o41425_0_1_rgba;
float o40966_0_a = p_o40966_amount*1.0;
float4 o40966_0_2_rgba = tofloat4(blend_overlay((frac(transform2((uv), tofloat2(p_o41364_translate_x*(2.0*o41369_0_1_f-1.0), (_Time.y*.05)*(2.0*1.0-1.0)), p_o41364_rotate*0.01745329251*(2.0*1.0-1.0), tofloat2(p_o41364_scale_x*(2.0*1.0-1.0), p_o41364_scale_y*(2.0*1.0-1.0))))), o40966_0_s1.rgb, o40966_0_s2.rgb, o40966_0_a*o40966_0_s1.a), min(1.0, o40966_0_s2.a+o40966_0_a*o40966_0_s1.a));
float4 o41364_0_1_rgba = o40966_0_2_rgba;
float3 o40974_0_1_rgb = process_normal_default(o40974_fct((frac(transform2((uv), tofloat2(p_o41366_translate_x*(2.0*o41369_0_1_f-1.0), (_Time.y*.05)*(2.0*1.0-1.0)), p_o41366_rotate*0.01745329251*(2.0*1.0-1.0), tofloat2(p_o41366_scale_x*(2.0*1.0-1.0), p_o41366_scale_y*(2.0*1.0-1.0))))), _seed_variation_), p_o40974_amount*1024.000000000/128.0);
float4 o41366_0_1_rgba = tofloat4(o40974_0_1_rgb, 1.0);

			o.Albedo = ((o41364_0_1_rgba).rgb).rgb*tofloat4(p_o40964_albedo_color_r, p_o40964_albedo_color_g, p_o40964_albedo_color_b, p_o40964_albedo_color_a).rgb;
            o.Metallic = 1.0*p_o40964_metallic;
            o.Smoothness = 1.0-1.0*p_o40964_roughness;
            o.Alpha = 1.0;
			o.Normal = ((o41366_0_1_rgba).rgb)*tofloat3(-1.0, 1.0, -1.0)+tofloat3(1.0, 0.0, 1.0);

        }
        ENDCG
    }
    FallBack "Diffuse"
}



