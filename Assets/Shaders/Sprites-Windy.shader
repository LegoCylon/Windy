Shader "Sprites/Windy"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _NoiseTex ("Noise Texture", 2D) = "black" {}
        _NoiseContrast ("Noise Contrast", Range(-1, 1)) = 1.0
        _NoiseFrequency ("Noise Frequency", Float) = 0.25
        _NoiseMagnitude ("Noise Magnitude", Float) = 0.25
        _NoiseScale ("Noise Scale", Float) = 0.25
        _NoiseSpeed ("Noise Speed", Float) = 0.25
        _SwayFrequency ("Sway Frequency", Float) = 0.25
        _SwayMagnitude ("Sway Magnitude", Float) = 0.25
        _SwaySpeed ("Sway Speed", Float) = 0.25
        _WindResistance ("Wind Resistance", Range(0, 1)) = 0.0
    }

    HLSLINCLUDE

        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
        #include "SpaceTransforms.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        float4 _Color;
        TEXTURE2D_SAMPLER2D(_NoiseTex, sampler_NoiseTex);
        float _NoiseContrast;
        float _NoiseFrequency;
        float _NoiseMagnitude;
        float _NoiseScale;
        float _NoiseSpeed;
        float _SwayFrequency;
        float _SwayMagnitude;
        float _SwaySpeed;
        float _WindResistance;

        #define WINDY_DEBUG 0

        struct Attributes
        {
            float3 vertex : POSITION;
            float4 color : COLOR;
            float2 texcoord : TEXCOORD0;
        };

        struct Varyings
        {
            float4 vertex : SV_POSITION;
            float4 color : COLOR;
            float2 texcoord : TEXCOORD0;
        };

        Varyings Vert(Attributes i)
        {
            float heightAttenuation = .5 * (1 - _WindResistance) * (1 + i.vertex.y);

            float3 wPos = TransformObjectToWorld(i.vertex);

            float2 windVector = float2(2, 0);
            float2 windNoiseCoord = (wPos.xy * _NoiseScale + _Time[1] * _NoiseSpeed) * _NoiseFrequency;
            float windNoise = SAMPLE_TEXTURE2D_LOD(_NoiseTex, sampler_NoiseTex, windNoiseCoord, 0);
            windNoise = _NoiseMagnitude * ((windNoise - 0.5) * (_NoiseContrast + 1)) + 0.5;

            float2 windSway = 0.5 * _SwayMagnitude * ((1).xx + cos((wPos.xy + (_Time[1]).xx * _SwaySpeed)) * _SwayFrequency);

            #if !WINDY_DEBUG
            wPos.xy += heightAttenuation * (windVector * windNoise - windVector * windSway);
            #endif

            Varyings o;
            o.vertex = mul(GetWorldToHClipMatrix(), float4(wPos, 1.0));
            o.color = i.color * _Color;
            o.texcoord = i.texcoord;

            #if WINDY_DEBUG
            o.color.r = windNoise;
            o.color.gb = windSway * normalize(windVector);
            o.color.a = heightAttenuation;
            #endif

            return o;
        }

        float4 Frag(Varyings i) : SV_Target
        {
            float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * i.color;
            #if WINDY_DEBUG
            color = i.color;
            #endif
            color.rgb *= color.a;
            return color;
        }

    ENDHLSL

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
            "DisableBatching"="True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment Frag

            ENDHLSL
        }
    }
}