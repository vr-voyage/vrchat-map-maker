// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// More skybox mods by Lyuma

Shader "Skybox/Skybox-Cloudy-Lyuma" {
Properties {
    [KeywordEnum(None, Simple, High Quality)] _SunDisk ("Sun", Int) = 2
    _SunSize ("Sun Size", Range(0,1)) = 0.04
    _SunSizeConvergence("Sun Size Convergence", Range(1,10)) = 5

    _AtmosphereThickness ("Atmosphere Thickness", Range(0,5)) = 1.0
    _SkyTint ("Sky Tint", Color) = (.5, .5, .5, 1)
    _GroundColor ("Ground", Color) = (.369, .349, .341, 1)
    [HDR] _CloudColor ("Cloud color", Color) = (1.1, 1.1, 0.9, 1.0)

    _Exposure("Exposure", Range(0, 8)) = 1.3

    _SkyboxDistortion("Planet surf, cloudlayer, radius, bumpy", Vector) = (60.0, 220.0, 10000.0, 15.0)
    // speed was 0.03 , tint color was 0.5
    _ScaleSpeedTint("Scale, speed, tint color, bumpscale", Vector) = (0.1, 0.3, 0.68, 0.1)
    _CloudParams("Cloud dark, light, cover, alpha", Vector) = (0.5, 0.3, 0.2, 8.0)
    _CloudFarClip("Farclip above,below (0=disable),groundColor", Vector) = (20.0, 0.0, 1.0, 0.0)
	//_NoiseTexture("Noise texture", 2D) = "white" {}
    _NoiseTexture ("Noise Texture", 2D) = "white" {}
    _SkyTexThresh("Sky tex threshold", Float) = 0.6
	[Toggle(_NORMALMAP)] _UseNoiseTexture("Use Noise Texture (required on Quest)", Range(0,1)) = 1.0
}

SubShader {
    Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
    Cull Off ZWrite Off

    Pass {

        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag

        #include "UnityCG.cginc"
        #include "Lighting.cginc"
//#define _Time float4(23,23,23,23)
        #pragma multi_compile _SUNDISK_NONE _SUNDISK_SIMPLE _SUNDISK_HIGH_QUALITY
        #pragma shader_feature _NORMALMAP

        uniform half _Exposure;     // HDR exposure
        uniform half3 _GroundColor;
        uniform half _SunSize;
        uniform half _SunSizeConvergence;
        uniform half3 _SkyTint;
        uniform half _AtmosphereThickness;
        uniform half _SkyTexThresh;

    #if defined(UNITY_COLORSPACE_GAMMA)
        #define GAMMA 2
        #define COLOR_2_GAMMA(color) color
        #define COLOR_2_LINEAR(color) color*color
        #define LINEAR_2_OUTPUT(color) sqrt(color)
    #else
        #define GAMMA 2.2
        // HACK: to get gfx-tests in Gamma mode to agree until UNITY_ACTIVE_COLORSPACE_IS_GAMMA is working properly
        #define COLOR_2_GAMMA(color) ((unity_ColorSpaceDouble.r>2.0) ? pow(color,1.0/GAMMA) : color)
        #define COLOR_2_LINEAR(color) color
        #define LINEAR_2_LINEAR(color) color
    #endif

        // RGB wavelengths
        // .35 (.62=158), .43 (.68=174), .525 (.75=190)
        static const float3 kDefaultScatteringWavelength = float3(.65, .57, .475);
        static const float3 kVariableRangeForScatteringWavelength = float3(.15, .15, .15);

        #define OUTER_RADIUS 1.025
        static const float kOuterRadius = OUTER_RADIUS;
        static const float kOuterRadius2 = OUTER_RADIUS*OUTER_RADIUS;
        static const float kInnerRadius = 1.0;
        static const float kInnerRadius2 = 1.0;

        static const float kCameraHeight = 0.0001;

        #define kRAYLEIGH (lerp(0.0, 0.0025, pow(_AtmosphereThickness,2.5)))      // Rayleigh constant
        #define kMIE 0.0010             // Mie constant
        #define kSUN_BRIGHTNESS 20.0    // Sun brightness

        #define kMAX_SCATTER 50.0 // Maximum scattering value, to prevent math overflows on Adrenos

        static const half kHDSundiskIntensityFactor = 15.0;
        static const half kSimpleSundiskIntensityFactor = 27.0;

        static const half kSunScale = 400.0 * kSUN_BRIGHTNESS;
        static const float kKmESun = kMIE * kSUN_BRIGHTNESS;
        static const float kKm4PI = kMIE * 4.0 * 3.14159265;
        static const float kScale = 1.0 / (OUTER_RADIUS - 1.0);
        static const float kScaleDepth = 0.25;
        static const float kScaleOverScaleDepth = (1.0 / (OUTER_RADIUS - 1.0)) / 0.25;
        static const float kSamples = 2.0; // THIS IS UNROLLED MANUALLY, DON'T TOUCH

        #define MIE_G (-0.990)
        #define MIE_G2 0.9801

        #define SKY_GROUND_THRESHOLD 0.02

        // fine tuning of performance. You can override defines here if you want some specific setup
        // or keep as is and allow later code to set it according to target api

        // if set vprog will output color in final color space (instead of linear always)
        // in case of rendering in gamma mode that means that we will do lerps in gamma mode too, so there will be tiny difference around horizon
        // #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 0

        // sun disk rendering:
        // no sun disk - the fastest option
        #define SKYBOX_SUNDISK_NONE 0
        // simplistic sun disk - without mie phase function
        #define SKYBOX_SUNDISK_SIMPLE 1
        // full calculation - uses mie phase function
        #define SKYBOX_SUNDISK_HQ 2

        // uncomment this line and change SKYBOX_SUNDISK_SIMPLE to override material settings
        // #define SKYBOX_SUNDISK SKYBOX_SUNDISK_SIMPLE

    #ifndef SKYBOX_SUNDISK
        #if defined(_SUNDISK_NONE)
            #define SKYBOX_SUNDISK SKYBOX_SUNDISK_NONE
        #elif defined(_SUNDISK_SIMPLE)
            #define SKYBOX_SUNDISK SKYBOX_SUNDISK_SIMPLE
        #else
            #define SKYBOX_SUNDISK SKYBOX_SUNDISK_HQ
        #endif
    #endif

    #ifndef SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
        #if defined(SHADER_API_MOBILE)
            #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 1
        #else
            #define SKYBOX_COLOR_IN_TARGET_COLOR_SPACE 0
        #endif
    #endif

		#define lumaConv float3(0.2125f, 0.7154f, 0.0721f)

        // Calculates the Rayleigh phase function
        half getRayleighPhase(half eyeCos2)
        {
            return 0.75 + 0.75*eyeCos2;
        }
        half getRayleighPhase(half3 light, half3 ray)
        {
            half eyeCos = dot(light, ray);
            return getRayleighPhase(eyeCos * eyeCos);
        }


        struct appdata_t
        {
            float4 vertex : POSITION;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct v2f
        {
            float4  pos             : SV_POSITION;

        #if SKYBOX_SUNDISK == SKYBOX_SUNDISK_HQ || SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
            // for HQ sun disk, we need vertex itself to calculate ray-dir per-pixel
            float3  vertex          : TEXCOORD0;
        //#elif SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
        //    half3   rayDir          : TEXCOORD0;
        #else
            // as we dont need sun disk we need just rayDir.y (sky/ground threshold)
            half    skyGroundFactor : TEXCOORD0;
        #endif

            // calculate sky colors in vprog
            half3   groundColor     : TEXCOORD1;
            half3   skyColor        : TEXCOORD2;

        #if SKYBOX_SUNDISK != SKYBOX_SUNDISK_NONE
            half3   sunColor        : TEXCOORD3;
        #endif

            UNITY_VERTEX_OUTPUT_STEREO
        };

        float scale(float inCos)
        {
            float x = 1.0 - inCos;
        #if defined(SHADER_API_N3DS)
            // The polynomial expansion here generates too many swizzle instructions for the 3DS vertex assembler
            // Approximate by removing x^1 and x^2
            return 0.25 * exp(-0.00287 + x*x*x*(-6.80 + x*5.25));
        #else
            return 0.25 * exp(-0.00287 + x*(0.459 + x*(3.83 + x*(-6.80 + x*5.25))));
        #endif
        }

        // Lyuma added params
        sampler2D _NoiseTexture;
        float4 _NoiseTexture_ST;
        float _UseNoiseTexture;
        uniform float4 _SkyboxDistortion;//50.0, 1000.0
        static float planetSurface = _SkyboxDistortion.x;
        static float cloudSurface = _SkyboxDistortion.y;
        static float earthRadius = _SkyboxDistortion.z;
        static float cloudBumpiness = _SkyboxDistortion.w;
        static float curveAdd = (planetSurface + _WorldSpaceCameraPos.y) / earthRadius;
        static float cloudCurveAdd = (cloudSurface + _WorldSpaceCameraPos.y) / earthRadius;

        uniform float4 _ScaleSpeedTint;
        uniform float4 _CloudParams;
        uniform float4 _CloudFarClip;
        uniform float4 _CloudColor;
        static float showGroundAmount = _CloudFarClip.z;
        //sampler2D _NoiseTexture;

        static float cloudscale = _ScaleSpeedTint.x;
        static float speed = _ScaleSpeedTint.y;
        static float clouddark = _CloudParams.x;
        static float cloudlight = _CloudParams.y;
        static float cloudcover = _CloudParams.z;
        static float cloudalpha = _CloudParams.w;
        static float skytint = _ScaleSpeedTint.z;
        static float bumpscale = _ScaleSpeedTint.w;

        v2f vert (appdata_t v)
        {
            v2f OUT;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
            OUT.pos = UnityObjectToClipPos(v.vertex);

            float3 kSkyTintInGammaSpace = COLOR_2_GAMMA(_SkyTint); // convert tint from Linear back to Gamma
            float3 kScatteringWavelength = lerp (
                kDefaultScatteringWavelength-kVariableRangeForScatteringWavelength,
                kDefaultScatteringWavelength+kVariableRangeForScatteringWavelength,
                half3(1,1,1) - kSkyTintInGammaSpace); // using Tint in sRGB gamma allows for more visually linear interpolation and to keep (.5) at (128, gray in sRGB) point
            float3 kInvWavelength = 1.0 / pow(kScatteringWavelength, 4);

            float kKrESun = kRAYLEIGH * kSUN_BRIGHTNESS;
            float kKr4PI = kRAYLEIGH * 4.0 * 3.14159265;

            float3 cameraPos = float3(0,kInnerRadius + kCameraHeight,0);    // The camera's current position

            // Get the ray from the camera to the vertex and its length (which is the far point of the ray passing through the atmosphere)
            float3 eyeRay = normalize(mul((float3x3)unity_ObjectToWorld, v.vertex.xyz + float3(0,lerp(0, lerp(2, 0, saturate(showGroundAmount)), saturate(-normalize(normalize(v.vertex.xyz) + float3(0, curveAdd, 0)).y)),0))) ;
            //eyeRay = normalize(mul((float3x3)unity_ObjectToWorld, v.vertex.xyz));
            float3 eyeSurfRay = normalize(eyeRay + float3(0, curveAdd, 0));
            eyeRay = normalize(eyeRay + float3(0, cloudCurveAdd, 0));

            float far = sqrt(kOuterRadius2 + kInnerRadius2 * eyeRay.y * eyeRay.y - kInnerRadius2) - kInnerRadius * eyeRay.y;

            half3 cIn, cOut;

            if(eyeSurfRay.y >= 0.0)
            {
                // Sky
                // Calculate the length of the "atmosphere"

                float3 pos = cameraPos + far * eyeRay;

                // Calculate the ray's starting position, then calculate its scattering offset
                float height = kInnerRadius + kCameraHeight;
                float depth = exp(kScaleOverScaleDepth * (-kCameraHeight));
                float startAngle = dot(eyeRay, cameraPos) / height;
                float startOffset = depth*scale(startAngle);


                // Initialize the scattering loop variables
                float sampleLength = far / kSamples;
                float scaledLength = sampleLength * kScale;
                float3 sampleRay = eyeRay * sampleLength;
                float3 samplePoint = cameraPos + sampleRay * 0.5;

                // Now loop through the sample rays
                float3 frontColor = float3(0.0, 0.0, 0.0);
                // Weird workaround: WP8 and desktop FL_9_3 do not like the for loop here
                // (but an almost identical loop is perfectly fine in the ground calculations below)
                // Just unrolling this manually seems to make everything fine again.
//              for(int i=0; i<int(kSamples); i++)
                {
                    float height = length(samplePoint);
                    float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                    float lightAngle = dot(_WorldSpaceLightPos0.xyz, samplePoint) / height;
                    float cameraAngle = dot(eyeRay, samplePoint) / height;
                    float scatter = (startOffset + depth*(scale(lightAngle) - scale(cameraAngle)));
                    float3 attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));

                    frontColor += attenuate * (depth * scaledLength);
                    samplePoint += sampleRay;
                }
                {
                    float height = length(samplePoint);
                    float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                    float lightAngle = dot(_WorldSpaceLightPos0.xyz, samplePoint) / height;
                    float cameraAngle = dot(eyeRay, samplePoint) / height;
                    float scatter = (startOffset + depth*(scale(lightAngle) - scale(cameraAngle)));
                    float3 attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));

                    frontColor += attenuate * (depth * scaledLength);
                    samplePoint += sampleRay;
                }



                // Finally, scale the Mie and Rayleigh colors and set up the varying variables for the pixel shader
                cIn = frontColor * (kInvWavelength * kKrESun);
                cOut = frontColor * kKmESun;
            }
            else
            {
                // Ground
                far = (-kCameraHeight) / (min(-0.001, eyeRay.y));

                float3 pos = cameraPos + far * eyeRay;

                // Calculate the ray's starting position, then calculate its scattering offset
                float depth = exp((-kCameraHeight) * (1.0/kScaleDepth));
                float cameraAngle = dot(-eyeRay, pos);
                float lightAngle = dot(_WorldSpaceLightPos0.xyz, pos);
                float cameraScale = scale(cameraAngle);
                float lightScale = scale(lightAngle);
                float cameraOffset = depth*cameraScale;
                float temp = (lightScale + cameraScale);

                // Initialize the scattering loop variables
                float sampleLength = far / kSamples;
                float scaledLength = sampleLength * kScale;
                float3 sampleRay = eyeRay * sampleLength;
                float3 samplePoint = cameraPos + sampleRay * 0.5;

                // Now loop through the sample rays
                float3 frontColor = float3(0.0, 0.0, 0.0);
                float3 attenuate;
//              for(int i=0; i<int(kSamples); i++) // Loop removed because we kept hitting SM2.0 temp variable limits. Doesn't affect the image too much.
                {
                    float height = length(samplePoint);
                    float depth = exp(kScaleOverScaleDepth * (kInnerRadius - height));
                    float scatter = depth*temp - cameraOffset;
                    attenuate = exp(-clamp(scatter, 0.0, kMAX_SCATTER) * (kInvWavelength * kKr4PI + kKm4PI));
                    frontColor += attenuate * (depth * scaledLength);
                    samplePoint += sampleRay;
                }

                cIn = frontColor * (kInvWavelength * kKrESun + kKmESun);
                cOut = clamp(attenuate, 0.0, 1.0);
            }

        #if SKYBOX_SUNDISK == SKYBOX_SUNDISK_HQ || SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
            OUT.vertex          = -v.vertex;
        //#elif SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
        //    OUT.rayDir          = half3(-eyeRay);
        #else
            OUT.skyGroundFactor = -eyeRay.y / SKY_GROUND_THRESHOLD;
        #endif

            // if we want to calculate color in vprog:
            // 1. in case of linear: multiply by _Exposure in here (even in case of lerp it will be common multiplier, so we can skip mul in fshader)
            // 2. in case of gamma and SKYBOX_COLOR_IN_TARGET_COLOR_SPACE: do sqrt right away instead of doing that in fshader

            OUT.groundColor = _Exposure * (cIn + COLOR_2_LINEAR(_GroundColor) * cOut);
            OUT.skyColor    = _Exposure * (cIn * getRayleighPhase(_WorldSpaceLightPos0.xyz, -eyeRay));

        #if SKYBOX_SUNDISK != SKYBOX_SUNDISK_NONE
            // The sun should have a stable intensity in its course in the sky. Moreover it should match the highlight of a purely specular material.
            // This matching was done using the standard shader BRDF1 on the 5/31/2017
            // Finally we want the sun to be always bright even in LDR thus the normalization of the lightColor for low intensity.
            half lightColorIntensity = clamp(length(_LightColor0.xyz), 0.25, 1);
            #if SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
                OUT.sunColor    = kSimpleSundiskIntensityFactor * saturate(cOut * kSunScale) * _LightColor0.xyz / lightColorIntensity;
            #else // SKYBOX_SUNDISK_HQ
                OUT.sunColor    = kHDSundiskIntensityFactor * saturate(cOut) * _LightColor0.xyz / lightColorIntensity;
            #endif

        #endif

        #if defined(UNITY_COLORSPACE_GAMMA) && SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
            OUT.groundColor = sqrt(OUT.groundColor);
            OUT.skyColor    = sqrt(OUT.skyColor);
            #if SKYBOX_SUNDISK != SKYBOX_SUNDISK_NONE
                OUT.sunColor= sqrt(OUT.sunColor);
            #endif
        #endif
            return OUT;
        }


        // Calculates the Mie phase function
        half getMiePhase(half eyeCos, half eyeCos2)
        {
            half temp = 1.0 + MIE_G2 - 2.0 * MIE_G * eyeCos;
            temp = pow(temp, pow(_SunSize,0.65) * 10);
            temp = max(temp,1.0e-4); // prevent division by zero, esp. in half precision
            temp = 1.5 * ((1.0 - MIE_G2) / (2.0 + MIE_G2)) * (1.0 + eyeCos2) / temp;
            #if defined(UNITY_COLORSPACE_GAMMA) && SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
                temp = pow(temp, .454545);
            #endif
            return temp;
        }

        // Calculates the sun shape
        half calcSunAttenuation(half3 lightPos, half3 ray)
        {
        #if SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
            half3 delta = lightPos - ray;
            half dist = length(delta);
            half spot = 1.0 - smoothstep(0.0, _SunSize, dist);
            return spot * spot;
        #else // SKYBOX_SUNDISK_HQ
            half focusedEyeCos = pow(saturate(dot(lightPos, ray)), _SunSizeConvergence);
            return getMiePhase(-focusedEyeCos, focusedEyeCos * focusedEyeCos);
        #endif
        }

        //////////////////////////////////////////
        //////////////////////////////////////////
        // 2D Clouds
        // https://www.shadertoy.com/view/4tdSWr
        // by drift 2016-11-13
        static float2x2 m = float2x2( 1.6,  1.2, -1.2,  1.6 );

        float2 hash( float2 p ) {
            p = float2(dot(p,float2(127.1,311.7)), dot(p,float2(269.5,183.3)));
            return -1.0 + 2.0*frac(sin(p)*43758.5453123);
        }

        float noise( in float2 p ) {
            //return tex2D(_NoiseTexture, frac(p));
            const float K1 = 0.366025404; // (sqrt(3)-1)/2;
            const float K2 = 0.211324865; // (3-sqrt(3))/6;
            float2 i = floor(p + (p.x+p.y)*K1);	
            float2 a = p - i + (i.x+i.y)*K2;
            float2 o = (a.x>a.y) ? float2(1.0,0.0) : float2(0.0,1.0); //float2 of = 0.5 + 0.5*float2(sign(a.x-a.y), sign(a.y-a.x));
            float2 b = a - o + K2;
            float2 c = a - 1.0 + 2.0*K2;
            float3 h = max(0.5-float3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
            float3 n = h*h*h*h*float3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
            return dot(n, float3(70,70,70));	
        }

        float fbm(float2 n) {
            float total = 0.0, amplitude = 0.1;
            for (int i = 0; i < 7; i++) {
                total += noise(n) * amplitude;
                n = mul(m, n);
                amplitude *= 0.4;
            }
            return total;
        }

        float getCloudC(float2 realUV, float time, float q) {
            float2 uv;
            float weight;
            uint i;

            //noise colour
            float c = .5;
            c = 0.0;
            time = time * 2.0;
            uv = realUV;
            uv *= cloudscale*2.0;
            uv -= (q - time).xx;
            weight = 0.4;
            [unroll]
            for (i=0; i<3; i++){
                c += weight*noise( uv );
                uv = mul(m, uv) + time.xx;
                weight *= 0.6;
            }
            
            //noise ridge colour
            float c1 = 0.0;
            time = time * 1.5;
            uv = realUV;
            uv *= cloudscale*3.0;
            uv -= (q - time).xx;
            weight = 0.4;
            [unroll]
            for (i=0; i<3; i++){
                c1 += abs(weight*noise( uv ));
                uv = mul(m, uv) + time.xx;
                weight *= 0.6;
            }
            
            c += c1;
            return c;
        }

        float getCloudF(float2 realUV, float time, float q) {
        //ridged noise shape
            float2 uv;
            float r = 0.0,weight;
            uint i;
            uv = realUV;
            uv *= cloudscale;
            uv -= (q - time).xx;
            weight = 0.8;
            [unroll]
            for (i=0; i<3; i++){
                r += abs(weight*noise( uv ));
                uv = mul(m, uv) + time.xx;
                weight *= 0.7;
            }
            
            //noise shape
            float f = 0.0;
            uv = realUV;
            uv *= cloudscale;
            uv -= (q - time).xx;
            weight = 0.7;
            [unroll]
            for (i=0; i<3; i++){
                f += weight*noise( uv );
                uv = mul(m, uv) + time.xx;
                weight *= 0.6;
            }
            
            f *= r + f;
            f = cloudcover + cloudalpha*f*r;
            return f;
        }
        //////////////////////////////////////////
        //////////////////////////////////////////

        half4 frag (v2f IN) : SV_Target
        {
            //return half4(IN.skyColor,1);//
            half3 col = half3(0.0, 0.0, 0.0);

        // if y > 1 [eyeRay.y < -SKY_GROUND_THRESHOLD] - ground
        // if y >= 0 and < 1 [eyeRay.y <= 0 and > -SKY_GROUND_THRESHOLD] - horizon
        // if y < 0 [eyeRay.y > 0] - sky
        #if SKYBOX_SUNDISK == SKYBOX_SUNDISK_HQ || SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
            half3 ray = normalize(mul((float3x3)unity_ObjectToWorld, IN.vertex));
            ray = normalize(ray + float3(0,-cloudCurveAdd,0));
            half y = ray.y / SKY_GROUND_THRESHOLD;
        //#elif SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
        //    half3 ray = IN.rayDir.xyz;
        //    half y = ray.y / SKY_GROUND_THRESHOLD;
        #else
            half y = IN.skyGroundFactor;
        #endif

            // if we did precalculate color in vprog: just do lerp between them
            col = lerp(IN.skyColor, IN.groundColor, saturate(y * _CloudFarClip.z));

        #if SKYBOX_SUNDISK != SKYBOX_SUNDISK_NONE
            if(y < 0.0)
            {
                col += IN.sunColor * calcSunAttenuation(_WorldSpaceLightPos0.xyz, -ray);
            }
        #endif

		#if SKYBOX_SUNDISK == SKYBOX_SUNDISK_HQ || SKYBOX_SUNDISK == SKYBOX_SUNDISK_SIMPLE
        // Lyuma added clouds
        float distToPlane = (1.0 / dot(float3(0,1,0), ray));
        float3 cloudcolour = _CloudColor * clamp((clouddark + cloudlight * 0.5), 0.0, 1.0);
        //float yPlane = -1 * _WorldSpaceCameraPos.y;
        if (distToPlane < _CloudFarClip.y && distToPlane > -_CloudFarClip.x) {
            float currentPlaneDist = max(0.2, cloudSurface + _WorldSpaceCameraPos.y);
            float3 rayToPlane = sign(distToPlane) * currentPlaneDist * ray * distToPlane;
            float2 uvRaw = float2(dot(rayToPlane, float3(1,0,0)), dot(rayToPlane, float3(0,0,1))) - _WorldSpaceCameraPos.xz;
            float2 uv = (0.1*uvRaw) * .5 + float2(.5,.5);//// * float2(0.273, 0.262) + float2(127.18733, 882.1282)
            //if (_UseNoiseTexture > 0.5) {
            #if _NORMALMAP
                currentPlaneDist = max(0.2, cloudSurface + tex2D(_NoiseTexture, uv * bumpscale).r * cloudBumpiness + sign(distToPlane) * _WorldSpaceCameraPos.y);
            //} else {
            #else
                currentPlaneDist = max(0.2, cloudSurface + noise(uv * bumpscale) * cloudBumpiness + sign(distToPlane) * _WorldSpaceCameraPos.y);
            //}
            #endif
            rayToPlane = -currentPlaneDist * ray * distToPlane;
            uvRaw = float2(dot(rayToPlane, float3(1,0,0)), dot(rayToPlane, float3(0,0,1))) - _WorldSpaceCameraPos.xz;
            uv = (0.1*uvRaw) * .5 + float2(.5,.5);
            float time = _Time.r * speed;
            float f, c, q;
            //if (_UseNoiseTexture > 0.5) {
            #if _NORMALMAP
                float4 textmp = saturate(3.0 * tex2D(_NoiseTexture, TRANSFORM_TEX((0.2154 * ( uv * cloudscale + time)), _NoiseTexture)) + tex2D(_NoiseTexture, TRANSFORM_TEX((0.23 * float2(0.4, 0.51) * uv * (cloudscale + 0.3 * time)), _NoiseTexture)) - _SkyTexThresh);
                c = sqrt(dot(textmp.rgb, textmp.rgb));
                f = 0;
            //} else {
            #else
                q = fbm(uv * cloudscale * 0.5);
                c = getCloudC(uv, time, q);
                f = getCloudF(uv, time, q);
            //}
            #endif
            cloudcolour = _CloudColor * clamp((clouddark + cloudlight * c), 0.0, 1.0);
            float ndotl = lerp(saturate(_WorldSpaceLightPos0.y + 0.25) * saturate(_WorldSpaceLightPos0.y + 0.5),
                    lerp(dot(float3(0,1,0), normalize(_WorldSpaceLightPos0.xyz + float3(0,0.01,0))), 1.0, 0.75),
                    saturate(_WorldSpaceLightPos0.y));
            col = lerp(lerp(col, cloudcolour, 0.5), lerp(col, skytint * col + float4(_Exposure * cloudcolour * ndotl, 1.0), saturate(f + c)), (smoothstep(_CloudFarClip.x * 0.7, 0.0, -distToPlane) * smoothstep(_CloudFarClip.y, _CloudFarClip.y * 0.9, distToPlane)));
        } else {
            col = lerp(col, cloudcolour, 0.5);
        }
		#endif

        #if defined(UNITY_COLORSPACE_GAMMA) && !SKYBOX_COLOR_IN_TARGET_COLOR_SPACE
            col = LINEAR_2_OUTPUT(col);
        #endif

            return half4(col,1.0);

        }
        ENDCG
    }
}


Fallback Off
//CustomEditor "SkyboxProceduralShaderGUI"
}
