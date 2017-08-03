Shader "Hidden/AuraFog" {
	Properties {
		_MainTex ("Texture", 2D) = "white" {}
        _Color ("Fog Color", Color) = (1,1,1,1)
        _BlurTex ("Blurred Depth", 2D) = "white" {}
        _Tone ("Tone", Vector) = (1, 1, 0.01, 1)
	}
	SubShader {
		Cull Off ZWrite Off ZTest Always

        CGINCLUDE
            #define LENGTH 4
            const static float WEIGHTS[LENGTH] = { 0.226, 0.194, 0.067, 0.013 };
            const static float OFFSETS[LENGTH] = { 0.649, 2.403, 4.329, 6.264 };

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float4 _Color;
            sampler2D _BlurTex;
            float4 _Tone;

            sampler2D _CameraDepthTexture;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
            struct v2fBlur {
                float2 uv : TEXCOORD0;
                float2 offsets[LENGTH] : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            v2fBlur vertBlur(appdata v) {
                v2fBlur o;
                #ifdef VERTICAL
                float2 dp = float2(0.0, _MainTex_TexelSize.y);
                #else
                float2 dp = float2(_MainTex_TexelSize.x, 0.0);
                #endif
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                for (uint i = 0; i < LENGTH; i++)
                    o.offsets[i] = OFFSETS[i] * dp;
                return o;
            }

            float4 fragDepth (v2f i) : SV_Target {
                float d = tex2D(_CameraDepthTexture, i.uv).x;
                d = Linear01Depth(d);
                return d;
            }
            float4 fragBlur(v2fBlur IN) : SV_Target {
                float4 c = 0;
                for (uint i = 0; i < LENGTH; i++) {
                    c += tex2D(_MainTex, IN.uv - IN.offsets[i]) * WEIGHTS[i];
                    c += tex2D(_MainTex, IN.uv + IN.offsets[i]) * WEIGHTS[i];
                }
                return c;
            }
        ENDCG

        // 0
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragDepth
            ENDCG
        }
        // 1
        Pass {
            CGPROGRAM
            #pragma multi_compile __ VERTICAL
            #pragma vertex vertBlur
            #pragma fragment fragBlur
            ENDCG
        }
        // 2
		Pass {
			CGPROGRAM
            #pragma multi_compile __ BlendNormal DebugDepth DebugFog
			#pragma vertex vert
			#pragma fragment frag

			fixed4 frag (v2f i) : SV_Target {
				float4 c = tex2D(_MainTex, i.uv);
                float dcam = Linear01Depth(tex2D(_CameraDepthTexture, i.uv).x);
                float dblur = tex2D(_BlurTex, i.uv).x;

				float f = _Tone.x * pow(saturate(dcam - dblur - _Tone.z), _Tone.y);

                #if defined(BlendNormal)
                return lerp(c, _Color, f);
                #elif defined(DebugDepth)
                return dcam;
                #elif defined(DebugFog)
                return f * _Color;
                #else
                return c + f * _Color;
                #endif
			}
			ENDCG
		}
	}
}
