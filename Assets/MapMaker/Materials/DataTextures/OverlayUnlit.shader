//
// 1. Add a Quad in Unity
// 2. Parent the quad under camera, to prevent frustum culling.
// 3. Attach this shader.
//
Shader "Quad/Fullscreen"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
	SubShader
	{
        Tags{ "RenderType" = "Overlay" "Queue" = "Overlay" "PreviewType" = "Plane" }
		ZTest Always ZWrite Off
		Cull Off ZWrite Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv     : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};


            sampler2D _MainTex;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = v.vertex;
				o.uv = v.uv;
				o.uv.y = 1 - o.uv.y;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				return tex2D (_MainTex, i.uv);// fixed4(i.uv, 0, 1);
                
			}
			ENDCG
		}
	}
}