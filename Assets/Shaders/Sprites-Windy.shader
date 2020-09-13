Shader "Sprites/Windy"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _IndexScale ("Index Scale", Float) = 0.25
        _IndexSpeed ("Index Speed", Float) = 0.25
        _NoiseTex ("Noise Texture", 2D) = "black" {}
        _NoiseContrast ("Noise Contrast", Range(-1, 1)) = 1.0
        _NoiseFrequency ("Noise Frequency", Float) = 0.25
        _NoiseMagnitude ("Noise Magnitude", Float) = 0.25
        _NoiseScale ("Noise Scale", Float) = 0.25
        _NoiseSpeed ("Noise Speed", Float) = 0.25
        _SwayFrequency ("Sway Frequency", Float) = 0.25
        _SwayMagnitude ("Sway Magnitude", Float) = 0.25
        _SwayScale ("Sway Scale", Float) = 1.0
        _SwaySpeed ("Sway Speed", Float) = 0.25
        _WindIndex ("Wind Index", Int) = 0
        _WindResistance ("Wind Resistance", Range(0, 1)) = 0.0
    }

    HLSLINCLUDE

        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
        #include "SpaceTransforms.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        float4 _Color;
        float _IndexScale;
        float _IndexSpeed;
        TEXTURE2D_SAMPLER2D(_NoiseTex, sampler_NoiseTex);
        float _NoiseContrast;
        float _NoiseFrequency;
        float _NoiseMagnitude;
        float _NoiseScale;
        float _NoiseSpeed;
        float _SwayFrequency;
        float _SwayMagnitude;
        float _SwayScale;
        float _SwaySpeed;
        int _WindIndex;
        float _WindResistance;

        float4 _WindVectorArray[8]; // Array length used below for index calculation

        #define WINDY_DEBUG_INDEX 0
        #define WINDY_DEBUG_NOISE 0
        #define WINDY_DEBUG (WINDY_DEBUG_INDEX || WINDY_DEBUG_NOISE)

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
            // Assuming object space coordinates of -1 -> 1, and that vertexes at -1 should remain stationary,
            // transform to 0 to 1 and apply wind resistance.
            // This would need to be inverted in a cave with vines hanging from the ceiling, for example.
            // This would also be an ideal place to use a secondary texture with the same texture coordinates as
            // _MainTex to precisely control the attenuation; that would also let us use dynamic batching.
            float heightAttenuation = 0.5 * (1 - _WindResistance) * (1 + i.vertex.y);

            // Wind vertex animation is performed in world space to facilitate random variation across adjacent objects.
            float3 wPos = TransformObjectToWorld(i.vertex);

            float2 windVector = _WindVectorArray[_WindIndex].xy; // Should match array length

            // Sample a noise texture based on scaled world position offset by time and attenuated by the frequency
            // (lower frequencies result in slower motion).
            // Note that because this is sampled in the vertex shader, we have to use the LOD version since the vertex
            // shader is unable to measure fragment derivatives to determine the appropriate mip level.
            float2 windNoiseCoord = (wPos.xy * _NoiseScale + _Time[1] * _NoiseSpeed) * _NoiseFrequency;
            float windNoise = SAMPLE_TEXTURE2D_LOD(_NoiseTex, sampler_NoiseTex, windNoiseCoord, 0).r;

            // Adjust the noise contrast and then attenuate the overall amount of noise.
            windNoise = _NoiseMagnitude * ((windNoise - 0.5) * (_NoiseContrast + 1)) + 0.5;

            // To simulate the motion of foliage swaying in the wind (that is stretching & contracting), sample a wave
            // using scaled world space coordinates offset by time and attenuated by the desired frequency
            // (lower frequencies result in slower motion).
            // Note that the wave sample is between -1 -> 1, so it will negate or exaggerate motion in the direction of
            // the wind.
            // Also, since the wave is sampled using world space coordinates, sine could be used instead of cosine.
            float2 windSway = _SwayMagnitude * (cos((wPos.xy * _SwayScale + (_Time[1]).xx * _SwaySpeed)) * _SwayFrequency);

            // Adjust the world space vertex based on height-attenuated noise and sway motion in the direction and
            // magnitude of the wind.
            // When debugging, we don't apply the motion since it makes it harder to study the fragment output.
            #if !WINDY_DEBUG
            wPos.xy += heightAttenuation * (windVector * windNoise + windVector * windSway);
            #endif

            Varyings o;
            o.vertex = mul(GetWorldToHClipMatrix(), float4(wPos, 1.0));
            o.color = i.color * _Color;
            o.texcoord = i.texcoord;

            #if WINDY_DEBUG_INDEX
            if (_WindIndex == 0)
            {
                o.color.rgb = float3(0, 0, 0);
            }
            else if (_WindIndex == 1)
            {
                o.color.rgb = float3(0, 0, 1);
            }
            else if (_WindIndex == 2)
            {
                o.color.rgb = float3(0, 1, 0);
            }
            else if (_WindIndex == 3)
            {
                o.color.rgb = float3(0, 1, 1);
            }
            else if (_WindIndex == 4)
            {
                o.color.rgb = float3(1, 0, 0);
            }
            else if (_WindIndex == 5)
            {
                o.color.rgb = float3(1, 0, 1);
            }
            else if (_WindIndex == 6)
            {
                o.color.rgb = float3(1, 1, 0);
            }
            else if (_WindIndex == 7)
            {
                o.color.rgb = float3(1, 1, 1);
            }
            else
            {
                o.color.rgb = float3(0.5, 0.5, 0.5);
            }
            #elif WINDY_DEBUG_NOISE
            o.color.r = windNoise;
            o.color.gb = 0.5 * (1 + windSway * normalize(windVector));
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