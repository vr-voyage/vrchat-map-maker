// Normal Mapping for a Triplanar Shader - Ben Golus 2017
// Unity Surface Shader example shader

// Implements correct triplanar normals in a Surface Shader with out computing or passing additional information from the
// vertex shader.

Shader "Triplanar/Surface Shader (RNM) (2DArray)" {
    Properties {
        _MainTex ("Albedo (RGB)", 2DArray) = "gray" {}
        [NoScaleOffset] _BumpMap("Normal Map", 2DArray) = "bump" {}
        _Glossiness("Smoothness", Range(0, 1)) = 0.5
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        [NoScaleOffset] _OcclusionMap("Occlusion", 2DArray) = "gray" {}
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        //_PouipIndex("Index", Range(0, 16)) = 0
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 200
        
        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows
        #pragma require 2darray

        // Use shader model 3.0 target, to get nicer looking lighting
        // Use shader model 3.5 for Texture2DArray support
        #pragma target 3.5

        #include "UnityStandardUtils.cginc"

        // flip UVs horizontally to correct for back side projection
        #define TRIPLANAR_CORRECT_PROJECTED_U

        // offset UVs to prevent obvious mirroring
        // #define TRIPLANAR_UV_OFFSET

        // Reoriented Normal Mapping
        // http://blog.selfshadow.com/publications/blending-in-detail/
        // Altered to take normals (-1 to 1 ranges) rather than unsigned normal maps (0 to 1 ranges)
        half3 blend_rnm(half3 n1, half3 n2)
        {
            n1.z += 1;
            n2.xy = -n2.xy;

            return n1 * dot(n1, n2) / n1.z - n2;
        }

        UNITY_DECLARE_TEX2DARRAY(_MainTex);
        float4 _MainTex_ST;

        UNITY_DECLARE_TEX2DARRAY(_BumpMap);
        UNITY_DECLARE_TEX2DARRAY(_OcclusionMap);

        half _Glossiness;
        half _Metallic;
        
        half _OcclusionStrength;

        //float _PouipIndex;

        struct Input {
            float3 worldPos;
            float3 worldNormal;
            float4 color : COLOR;
            INTERNAL_DATA
        };

        float3 WorldToTangentNormalVector(Input IN, float3 normal) {
            float3 t2w0 = WorldNormalVector(IN, float3(1,0,0));
            float3 t2w1 = WorldNormalVector(IN, float3(0,1,0));
            float3 t2w2 = WorldNormalVector(IN, float3(0,0,1));
            float3x3 t2w = float3x3(t2w0, t2w1, t2w2);
            return normalize(mul(t2w, normal));
        }

        // Voyage :
        // UNITY_SAMPLE_TEX2DARRAY(sampler, uv) * 2 - 1 doens't give good results
        // Nor does UnpackNormal(sampler, uv)
        // Note, this has been tested with Non Linear and Linear Normals and SRGB Textures
        // LinearToGammaSpace seems to "kinda" work but is still messy...
        // Something is wrong with the normals generation, either texture wise
        // Or shader wise.
        // However, I don't have enough knowledge to debug that at the moment.
#define Unpack2DArrayNormals(texArray, uv) (UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(texArray, uv)))
        
        void surf (Input IN, inout SurfaceOutputStandard o) {
            // work around bug where IN.worldNormal is always (0,0,0)!
            IN.worldNormal = WorldNormalVector(IN, float3(0,0,1));
            float texIndex = clamp(IN.color.r * 255,0,64);

            // calculate triplanar blend
            half3 triblend = saturate(pow(IN.worldNormal, 4));
            triblend /= max(dot(triblend, half3(1,1,1)), 0.0001);

            // calculate triplanar uvs
            // applying texture scale and offset values ala TRANSFORM_TEX macro
            // FIXME Found a way to optimize this... Changing float2 to float3 might
            // break a few optimizations there.

            float3 uvX = float3(IN.worldPos.zy * _MainTex_ST.xy + _MainTex_ST.zy, texIndex);
            float3 uvY = float3(IN.worldPos.xz * _MainTex_ST.xy + _MainTex_ST.zy, texIndex);
            float3 uvZ = float3(IN.worldPos.xy * _MainTex_ST.xy + _MainTex_ST.zy, texIndex);


            // offset UVs to prevent obvious mirroring
        #if defined(TRIPLANAR_UV_OFFSET)
            uvY += 0.33;
            uvZ += 0.67;
        #endif

            // minor optimization of sign(). prevents return value of 0
            half3 axisSign = IN.worldNormal < 0 ? -1 : 1;
            
            // flip UVs horizontally to correct for back side projection
        #if defined(TRIPLANAR_CORRECT_PROJECTED_U)
            uvX.x *= axisSign.x;
            uvY.x *= axisSign.y;
            uvZ.x *= -axisSign.z;
        #endif

            // albedo textures
            fixed4 colX = UNITY_SAMPLE_TEX2DARRAY(_MainTex, uvX);
            fixed4 colY = UNITY_SAMPLE_TEX2DARRAY(_MainTex, uvY);
            fixed4 colZ = UNITY_SAMPLE_TEX2DARRAY(_MainTex, uvZ);
            fixed4 col = colX * triblend.x + colY * triblend.y + colZ * triblend.z;

            // occlusion textures
            half occX = UNITY_SAMPLE_TEX2DARRAY(_OcclusionMap, uvX).g;
            half occY = UNITY_SAMPLE_TEX2DARRAY(_OcclusionMap, uvY).g;
            half occZ = UNITY_SAMPLE_TEX2DARRAY(_OcclusionMap, uvZ).g;
            half occ = LerpOneTo(occX * triblend.x + occY * triblend.y + occZ * triblend.z, _OcclusionStrength);

            // tangent space normal maps
            half3 tnormalX = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(_BumpMap, uvX));
            half3 tnormalY = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(_BumpMap, uvY));
            half3 tnormalZ = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(_BumpMap, uvZ));

            // flip normal maps' x axis to account for flipped UVs
        #if defined(TRIPLANAR_CORRECT_PROJECTED_U)
            tnormalX.x *= axisSign.x;
            tnormalY.x *= axisSign.y;
            tnormalZ.x *= -axisSign.z;
        #endif

            half3 absVertNormal = abs(IN.worldNormal);

            // swizzle world normals to match tangent space and apply reoriented normal mapping blend
            tnormalX = blend_rnm(half3(IN.worldNormal.zy, absVertNormal.x), tnormalX);
            tnormalY = blend_rnm(half3(IN.worldNormal.xz, absVertNormal.y), tnormalY);
            tnormalZ = blend_rnm(half3(IN.worldNormal.xy, absVertNormal.z), tnormalZ);

            // apply world space sign to tangent space Z
            tnormalX.z *= axisSign.x;
            tnormalY.z *= axisSign.y;
            tnormalZ.z *= axisSign.z;

            // sizzle tangent normals to match world normal and blend together
            half3 worldNormal = normalize(
                tnormalX.zyx * triblend.x +
                tnormalY.xzy * triblend.y +
                tnormalZ.xyz * triblend.z
                );

            // set surface ouput properties
            o.Albedo = col.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Occlusion = occ;

            // convert world space normals into tangent normals
            o.Normal = WorldToTangentNormalVector(IN, worldNormal);
        }
        ENDCG
    }
    FallBack "Diffuse"
}
