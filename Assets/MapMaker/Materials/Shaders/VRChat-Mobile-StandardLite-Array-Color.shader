Shader "Voyage/VRChat Standard Lite Array Color"
{
    Properties
    {
        _MainTex("Albedo", 2DArray) = "white" {}
        _Color("Color", Color) = (1,1,1,1)

        [NoScaleOffset] _MetallicGlossMap("Metallic(R) Smoothness(A) Map", 2DArray) = "white" {}
        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 1.0
        _Glossiness("Smoothness", Range(0.0, 1.0)) = 1.0

        [NoScaleOffset] _BumpMap("Normal Map", 2DArray) = "bump" {}

        [Toggle(_EMISSION)]_EnableEmission("Enable Emission", int) = 0
        [NoScaleOffset] _EmissionMap("Emission", 2DArray) = "white" {}
        _EmissionColor("Emission Color", Color) = (1,1,1)

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #define UNITY_BRDF_PBS BRDF2_Unity_PBS
        #include "UnityPBSLighting.cginc"

        #pragma vertex vert
        #pragma surface surf StandardMobile exclude_path:prepass exclude_path:deferred noforwardadd noshadow nodynlightmap nolppv noshadowmask
        #pragma require 2darray

        #pragma target 3.5
        #pragma multi_compile _ _EMISSION
        #pragma multi_compile _ _SPECULARHIGHLIGHTS_OFF
        #pragma multi_compile _GLOSSYREFLECTIONS_OFF

        // -------------------------------------

        struct Input
        {
            float2 uv_MainTex;
            //float arrayIndex; // You'd think they'd support this by default in 2019...
            float4 color : COLOR;
        };

        struct SurfaceOutputStandardMobile
        {
            fixed3 Albedo;      // base (diffuse or specular) color
            float3 Normal;      // tangent space normal, if written
            half3 Emission;
            half Metallic;      // 0=non-metal, 1=metal
            // Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
            // Everywhere in the code you meet smoothness it is perceptual smoothness
            half Smoothness;    // 0=rough, 1=smooth
            fixed Alpha;        // alpha for transparencies
        };

        UNITY_DECLARE_TEX2DARRAY(_MainTex);
        half4 _Color;

        UNITY_DECLARE_TEX2DARRAY(_MetallicGlossMap);
        uniform half _Glossiness;
        uniform half _Metallic;

        UNITY_DECLARE_TEX2DARRAY(_BumpMap);
        uniform half _BumpScale;

        UNITY_DECLARE_TEX2DARRAY(_EmissionMap);
        half4 _EmissionColor;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        // -------------------------------------
        
        inline half4 LightingStandardMobile(SurfaceOutputStandardMobile s, float3 viewDir, UnityGI gi)
        {
            s.Normal = normalize(s.Normal);
        
            half oneMinusReflectivity;
            half3 specColor;
            s.Albedo = DiffuseAndSpecularFromMetallic(s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

            half4 c = UNITY_BRDF_PBS(s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
            UNITY_OPAQUE_ALPHA(c.a);
            return c;
        }

        inline UnityGI UnityGI_BaseMobile(UnityGIInput data, half3 normalWorld)
        {
            UnityGI o_gi;
            ResetUnityGI(o_gi);

            o_gi.light = data.light;
            o_gi.light.color *= data.atten;
        
            #if UNITY_SHOULD_SAMPLE_SH
                o_gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
            #endif
        
            #if defined(LIGHTMAP_ON)
                // Baked lightmaps
                half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
                half3 bakedColor = DecodeLightmap(bakedColorTex);
        
                #ifdef DIRLIGHTMAP_COMBINED
                    fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
                    o_gi.indirect.diffuse += DecodeDirectionalLightmap(bakedColor, bakedDirTex, normalWorld);
                #else // not directional lightmap
                    o_gi.indirect.diffuse += bakedColor;
                #endif
            #endif

            return o_gi;
        }
        
        inline half3 UnityGI_IndirectSpecularMobile(UnityGIInput data, Unity_GlossyEnvironmentData glossIn)
        {
            half3 specular;

            #ifdef _GLOSSYREFLECTIONS_OFF
                specular = unity_IndirectSpecColor.rgb;
            #else
                half3 env0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), data.probeHDR[0], glossIn);
                specular = env0;
            #endif
        
            return specular;
        }

        inline UnityGI UnityGlobalIlluminationMobile(UnityGIInput data, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
        {
            UnityGI o_gi = UnityGI_BaseMobile(data, normalWorld);
            o_gi.indirect.specular = UnityGI_IndirectSpecularMobile(data, glossIn);
            return o_gi;
        }

        inline void LightingStandardMobile_GI(SurfaceOutputStandardMobile s, UnityGIInput data, inout UnityGI gi)
        {
            Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic));
            gi = UnityGlobalIlluminationMobile(data, s.Normal, g);
        }

        void vert(inout appdata_full v, out Input o)
        {
            o.uv_MainTex = v.texcoord.xy;
            //o.arrayIndex = v.texcoord.z;
            o.color = v.color;
        }

        void surf(Input IN, inout SurfaceOutputStandardMobile o)
        {
            float3 uv = float3(IN.uv_MainTex, clamp(IN.color.r * 255,0,64));
            //float uvZ = IN.arrayIndex * 0.2;
            //float4 debugColor = float4(uvZ, uvZ, uvZ, uvZ);
            // Albedo comes from a texture tinted by color
            half4 albedoMap = UNITY_SAMPLE_TEX2DARRAY(_MainTex, uv) * _Color;
            

            // Metallic and smoothness come from slider variables
            half4 metallicGlossMap = UNITY_SAMPLE_TEX2DARRAY(_MetallicGlossMap, uv);
            o.Metallic = metallicGlossMap.r * _Metallic;
            o.Smoothness = metallicGlossMap.a * _Glossiness;

            /*UnpackScaleNormal()*/
            o.Normal = UNITY_SAMPLE_TEX2DARRAY(_BumpMap, uv)*2.0-1.0; /*UnpackScaleNormal(UNITY_SAMPLE_TEX2DARRAY(_BumpMap, uv), -1.0)*/;
            o.Albedo = albedoMap.rgb; //o.Normal; 
            
            #ifdef _EMISSION
                o.Emission = UNITY_SAMPLE_TEX2DARRAY(_EmissionMap, uv) * _EmissionColor;
            #endif
        }
        ENDCG
    }

    FallBack "VRChat/Mobile/Diffuse"
}
