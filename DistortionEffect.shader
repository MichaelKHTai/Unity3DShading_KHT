Shader "Custom/DistortionEffect" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Tint ("Tint (RGB)", Color) = (0.5,0.5,0.5,1)
		_IntensityAndScrolling ("Intensity (XY); Scrolling (ZW)", Vector) = (0.1,0.1,1,1)
		_DistanceFade ("Distance Fade (X=Near, Y=Far, ZW=Unused)", Float) = (20, 50, 0, 0)
	}
	SubShader {
		Tags {"Queue" = "Transparent" "IgnoreProjector" = "True"}
		Blend One Zero
		Lighting Off
		Fog { Mode Off }
		ZWrite Off
		LOD 200
		Cull [_CullMode]
		GrabPass{ "_GrabTexture" }
		Pass {
			CGPROGRAM

			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram

			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _GrabTexture;
			float2 _DistanceFade;
			float4 _IntensityAndScrolling;

			struct VertexData {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
			};

			struct Interpolators {
				float4 pos : SV_POSITION;
				float4 color : COLOR;
				float4 uv : TEXCOORD0;
				float4 screen : TEXCOORD1;
			};

			Interpolators VertexProgram (VertexData v) {
				Interpolators i;
				i.pos = UnityObjectToClipPos(v.vertex);
				i.color = v.color;
				i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				i.uv.zw = v.uv;

				float4 screenPos = ComputeGrabScreenPos(i.pos);
				i.screen.xy = screenPos.xy / screenPos.w;
				float depth = length(mul(UNITY_MATRIX_MV, v.vertex));
				i.screen.z = saturate((_DistanceFade.y - depth) / (_DistanceFade.y - _DistanceFade.x));
				i.screen.w = depth;
				return i;
			}

			float4 FragmentProgram (Interpolators i) : COLOR {
				float2 distort = tex2D(_MainTex, i.uv.xy).xy;
				distort = (distort * 2 - 1) * _IntensityAndScrolling.xy * i.screen.z * i.color.a;
				float mask = tex2D(_MainTex, i.uv.zw).b;
				distort *= mask +0.1;
				float2 uv = i.screen.xy + distort;
				
				float4 color = tex2D(_GrabTexture, uv);
				UNITY_OPAQUE_ALPHA(color.a);
				color.a = 0;
				return color;
			}

			ENDCG
		}
	}
}