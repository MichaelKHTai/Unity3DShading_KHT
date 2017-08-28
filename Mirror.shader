Shader "FX/MirrorReflection"
{
	Properties
	{
		_Tint("Tint", Color) = (1,1,1,1)
		_MainTex ("Albedo", 2D) = "white" {}
		_DetailTex("Detail Texture", 2D) = "gray"{}
		[HideInInspector] _ReflectionTex ("", 2D) = "white" {}
		_Smoothness("Smoothness", Range(0,1)) = 0.5
		[NoScaleOffset] _MetallicMap ("Metallic", 2D) = "white" {}
		[Gamma] _Metallic("Metallic", Range(0,1)) = 0.1
		[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump"{}
		_BumpScale("Bump Scale", Float) = 1
		[NoScaleOffset] _DetailNormalMap ("Detail Normal", 2D) = "bump"{}
		_DetailBumpScale ("Bump Scale", Float) = 1

		_AlphaCutOff ("Alpha Cutoff", Range(0,1)) = 0.5
		//Fade rendering part
		[HideInInspector]_SrcBlend ("_SrcBlend", Float) = 1
		[HideInInspector]_DstBlend ("_DstBlend", Float) = 0
		[HideInInspector]_Zwrite ("_Zwrite", Float) = 1
	}

	CGINCLUDE

	#define BINORMAL_PER_FRAGMENT

	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		Pass {
			Tags {
				"LightMode" = "ForwardBase"
			}
			Blend [_SrcBlend] [_DstBlend]
			Zwrite [_Zwrite]
			CGPROGRAM

			#pragma target 3.0
			
			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _ _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_METALLIC _SMOOTHNESS_ALBEDO
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_MAP
			#pragma shader_feature _DETAIL_NORMAL
			#pragma multi_compile _ SHADOWS_SCREEN
			#pragma multi_compile _ VERTEXLIGHT_ON

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#define FORWARD_BASE_PASS

			
			#include "Mirror PBS.cginc"

			ENDCG
	    }

		Pass{
			Tags {
				"LightMode" = "ForwardAdd"
			}
			Blend [_SrcBlend] One
			Zwrite Off

			CGPROGRAM

			#pragma target 3.0

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _ _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_METALLIC _SMOOTHNESS_ALBEDO
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_MAP
			#pragma shader_feature _DETAIL_NORMAL
			#pragma multi_compile_fwdadd_fullshadows

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "Mirror PBS.cginc"

			ENDCG
		}

		Pass{
			Tags{
				"LightMode" = "ShadowCaster"
			}
			CGPROGRAM

			#pragma target 3.0

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _SEMITRANSPARENT_SHADOWS
			#pragma shader_feature _SMOOTHNESS_ALBEDO
			#pragma multi_compile_shadowcaster
			#pragma vertex ShadowVertexProgram
			#pragma fragment ShadowFragmentProgram

			#include "MyShadow.cginc"

			ENDCG
		}
	}

CustomEditor "MirrorShaderGUI"
}