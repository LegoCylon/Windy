Shader "Sprites/Windy"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
    }

    HLSLINCLUDE

        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

        // Transforms position from object space to homogenous space
        float4 TransformObjectToHClip(float3 positionOS)
        {
            // More efficient than computing M*VP matrix product
            return mul(unity_MatrixVP, mul(unity_ObjectToWorld, float4(positionOS, 1.0)));
        }

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        float4 _Color;

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
            Varyings o;
            o.vertex = TransformObjectToHClip(i.vertex);
            o.color = i.color * _Color;
            o.texcoord = i.texcoord;

            return o;
        }

        float4 Frag(Varyings i) : SV_Target
        {
            float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord) * i.color;
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