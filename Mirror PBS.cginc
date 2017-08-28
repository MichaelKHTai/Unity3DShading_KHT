
#if !defined(MIRROR_PBS_INCLUDED)
#define MIRROR_PBS_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"


float4 _Tint;
sampler2D _MainTex, _DetailTex, _ReflectionTex;
float4 _MainTex_ST, _DetailTex_ST;
sampler2D _NormalMap, _DetailNormalMap, _MetallicMap;
float _Smoothness, _Metallic, _BumpScale, _DetailBumpScale, _AlphaCutOff;


struct Interpolators{
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 normal : TEXCOORD1;
	#if defined(BINORMAL_PER_FRAGMENT)
		float4 tangent : TEXCOORD2;
	#else
		float3 tangent : TEXCOORD2;
		float3 binormal : TEXCOORD3;
	#endif

	float3 worldPos : TEXCOORD4;

	SHADOW_COORDS(5)

	#if defined(VERTEXLIGHT_ON)
		float3 vertexLightColor : TEXCOORD6;
	#endif
	
	float4 refl : TEXCOORD7;
};

struct VertexData{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float4 tangent : TANGENT;
	float3 normal : NORMAL;
};

float ComputeMetallicMap(Interpolators i){
	#if defined(_METALLIC_MAP)
		return tex2D(_MetallicMap, i.uv.xy).r;
	#else
		return _Metallic;
	#endif
}

float ComputeSmoothnessMap(Interpolators i){
	float smoothness = 1;
	#if defined(_SMOOTHNESS_ALBEDO)
		smoothness = tex2D(_MainTex, i.uv.xy).a;
	#elif defined(_METALLIC_MAP) && defined(_SMOOTHNESS_METALLIC)
		smoothness = tex2D(_MetallicMap, i.uv.xy).a;
	#endif
	return smoothness * _Smoothness;
}

float ComputeTransparent(Interpolators i){
	float alpha = _Tint.a;
	#if !defined(_SMOOTHNESS_ALBEDO)
		alpha *= tex2D(_MainTex, i.uv.xy).a;
	#endif
	return alpha;
}

void ComputeVertexLightColor(inout Interpolators i){
	#if defined(VERTEXLIGHT_ON)
		i.vertexLightColor = Shade4PointLights(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, i.worldPos, i.normal
		);
	#endif
}

float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
	return cross(normal, tangent.xyz) *
		(binormalSign * unity_WorldTransformParams.w);
}

Interpolators MyVertexProgram(VertexData v){
	Interpolators i;
	i.pos = UnityObjectToClipPos(v.vertex);
	i.worldPos = mul(unity_ObjectToWorld, v.vertex);
	i.normal = UnityObjectToWorldNormal(v.normal);
	#if defined(BINORMAL_PER_FRAGMENT)
		i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
	#else
		i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
		i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
	#endif
	i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
	i.refl = ComputeScreenPos(i.pos);

	TRANSFER_SHADOW(i);

	ComputeVertexLightColor(i);

	return i;
}

UnityLight CreateLight (Interpolators i){
	UnityLight light;
	#if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
		light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
	#else
		light.dir = _WorldSpaceLightPos0;
	#endif
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
	light.color = _LightColor0.rgb * attenuation;
	light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}


UnityIndirect CreateIndirectLight (Interpolators i) {
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

	#if defined(VERTEXLIGHT_ON)
		indirectLight.diffuse = i.vertexLightColor;
	#endif

	#if defined(FORWARD_BASE_PASS)
		indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)*0.8));

		fixed4 tex = tex2D(_MainTex, i.uv.xy);
		fixed4 refl = tex2Dproj(_ReflectionTex, UNITY_PROJ_COORD(i.refl));

		float4 envSample = tex*refl * ComputeSmoothnessMap(i);
		indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);
	#endif
	return indirectLight;
}

//Part of Bumpiness
void InitializeFragmentNormal(inout Interpolators i){
	float3 Main = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
	float3 Detail = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
	float3 tangentSpaceNormal = BlendNormals(Main, Detail);
	#if defined(BINORMAL_PER_FRAGMENT)
		float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
	#else
		float3 binormal = i.binormal;
	#endif
	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * binormal +
		tangentSpaceNormal.z * i.normal);
}

float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
	float alpha = ComputeTransparent(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _AlphaCutOff);
	#endif
	InitializeFragmentNormal(i);
	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
	albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
	float3 cameraDir = normalize(_WorldSpaceCameraPos - i.worldPos);
	float3 specularTint;
	float oneMinusReflectivity;
	albedo = DiffuseAndSpecularFromMetallic(
		albedo, ComputeMetallicMap(i), specularTint, oneMinusReflectivity
	);
	#if defined(_RENDERING_TRANSPARENT)
		albedo *= alpha;
		alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
	#endif

	float4 shader = UNITY_BRDF_PBS(
		albedo, specularTint, oneMinusReflectivity,
		 ComputeSmoothnessMap(i), i.normal, cameraDir, CreateLight(i),
		  CreateIndirectLight(i));
	#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
		shader.a = alpha;
	#endif
	return shader;
}

#endif