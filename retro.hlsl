// Retro shader.  Makes your console look like an old CRT

// Set these to 1 to enable and 0 to disable each feature
#define ENABLE_REFRESHLINE 1
#define ENABLE_VIGNETTING 1
#define ENABLE_BAD_CRT 1
#define ENABLE_SCREENLINES 1
#define ENABLE_HUEOFFSET 0

// You can tweak the look by making small adjustments to these values
#define HUE_OFFSET 0.0f
#define CHANGE_RATE 0.01f
#define TOLERANCE 0.266f

#define REFRESH_LINE_SIZE 0.04f

#define DOWNSCALE   (1.5*Scale)

#define MAIN        main
#define PI          3.141592654
#define TAU         (2.0*PI)

static const float4 scanlineTint = float4(0.6f, 0.6f, 0.6f, 0.0f);

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
  float  Time;
  float  Scale;
  float2 Resolution;
  float4 Background;
};

float2 resolution() {
  return Resolution;
}

// HSV to RGB conversion
float3 hsv2rgb(float3 c) {
  const float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// RGB to HSV conversion
float3 rgb2hsv(float3 c) {
  const float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
  float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 adjust_hue(float3 HSV, float offset)
{
	if (HSV.y >= TOLERANCE) { HSV.x = fmod(HSV.x + offset, 1); }
	return HSV;
}


// Ray sphere intersection
float raySphere(float3 ro, float3 rd, float4 sph) {
  float3 oc = ro - sph.xyz;
  float b = dot(oc, rd);
  float c = dot(oc, oc) - sph.w*sph.w;
  float h = b*b - c;
  if (h<0.0) return -1.0;
  h = sqrt(h);
  return -b - h;
}

float psin(float a) {
  return 0.5+0.5*sin(a);
}

float3 sampleHSV(float2 p) {
  float2 cp = abs(p - 0.5);
  float4 s = shaderTexture.Sample(samplerState, p);
  float3 col = lerp(Background.xyz, s.xyz, s.w);
  return rgb2hsv(col)*step(cp.x, 0.5)*step(cp.y, 0.5);
}

float3 screen(float2 reso, float2 p, float diff, float spe) {
  float sr = reso.y/reso.x;
  float res=reso.y/DOWNSCALE;

  float2 ap = p;
  ap.x *= sr;

  // Viginetting
  float2 vp = ap + 0.5;
  float vig = tanh(pow(max(100.0*vp.x*vp.y*(1.0-vp.x)*(1.0-vp.y), 0.0), 0.35));

  ap *= 1.025;

  // Screen at coord
  float2 sp = ap;
  sp += 0.5;
  float3 shsv = sampleHSV(sp);

#if ENABLE_SCREENLINES
  // Scan line brightness
  float scanbri = lerp(0.75, 2.0, psin(PI*res*p.y));

  shsv.z *= scanbri;
  shsv.z = tanh(0.75*shsv.z);
#endif

#if ENABLE_VIGNETTING
  shsv.z *= vig;
#endif

#if ENABLE_BAD_CRT
  // Simulate bad CRT screen
  float dist = (p.x+p.y)*0.05;
  shsv.x += dist;
#endif

#if ENABLE_HUEOFFSET
	shsv = adjust_hue(shsv, HUE_OFFSET + Time * CHANGE_RATE);
#endif

  float3 col = float3(0.0, 0.0, 0.0);
  col += hsv2rgb(shsv);
  col += (0.35*spe+0.25*diff)*vig;

  return col;
}

// Computes the color given the ray origin and texture coord p [-1, 1]
float3 color(float2 reso, float3 ro, float2 p) {
  // Quick n dirty way to get ray direction
  float3 rd = normalize(float3(p, 2.0));

  // The screen is imagined to be projected on a large sphere to give it a curve
  const float radius = 20.0;
  const float4 center = float4(0.0, 0.0, radius, radius-1.0);
  float3 lightPos = 0.95*float3(-1.0, -1.0, 0.0);

  // Find the ray sphere intersection, basically a single ray tracing step
  float sd = raySphere(ro, rd, center);

  if (sd > 0.0) {
    // sp is the point on sphere where the ray intersected
    float3 sp = ro + sd*rd;
    // Normal of the sphere allows to compute lighting
    float3 nor = normalize(sp - center.xyz);
    float3 ld = normalize(lightPos - sp);

    // Diffuse lighting
    float diff = max(dot(ld, nor), 0.0);
    // Specular lighting
    float spe = pow(max(dot(reflect(rd, nor), ld), 0.0),30.0);

    // Due to how the scene is setup up we cheat and use sp.xy as the screen coord
    return screen(reso, sp.xy, diff, spe);
  } else {
    return float3(0.0, 0.0, 0.0);
  }
}

float4 MAIN(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET {
  float2 reso = resolution();
  float2 q = tex;
  float2 p = -1. + 2. * q;
  p.x *= reso.x/reso.y;

  float3 ro = float3(0.0, 0.0, 0.0);
  float3 col = color(reso, ro, p);

 	#if ENABLE_REFRESHLINE
	float timeOver = fmod(Time / 5, 1);
	float refreshLineColorTint = timeOver - q.y;
	if(q.y > timeOver && q.y - REFRESH_LINE_SIZE < timeOver ) col.rgb += (refreshLineColorTint * 2.0f);
	#endif

  return float4(col, 1.0);
}