// Retro shader.  Makes your console look like an old CRT
// Based on the RETROII example code provided on Windows Terminal forums

// Set these to 1 to enable and 0 to disable each feature
#define ENABLE_REFRESHLINE 1
#define ENABLE_VIGNETTING 1
#define ENABLE_BAD_CRT 1
#define ENABLE_SCREENLINES 1
#define ENABLE_HUEOFFSET 0
#define ENABLE_TINT 0
#define ENABLE_GRAIN 1

#define GRAIN_INTENSITY 0.03

// Grain Lookup Table
#define a0  0.151015505647689
#define a1 -0.5303572634357367
#define a2  1.365020122861334
#define b0  0.132089632343748
#define b1 -0.7607324991323768

// You can tweak the look by making small adjustments to these values
#define HUE_OFFSET 0.0f
#define CHANGE_RATE 0.01f
#define TOLERANCE 0.266f

#define REFRESHLINE_SIZE 0.04f
#define REFRESHLINE_STRENGTH 0.5f

#define TINT_COLOR float4(0, 0.7f, 0, 0)

#define BAD_CRT_EFFECT 0.06f

#define DOWNSCALE   (1.5*Scale)

#define MAIN        main
#define PI          3.141592654
#define TAU         (2.0*PI)

#define SCALED_GAUSSIAN_SIGMA (2.0*Scale)

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

float permute(float x)
{
	x *= (34 * x + 1);
	return 289 * frac(x * 1 / 289.0f);
}

float rand(inout float state)
{
	state = permute(state);
	return frac(state / 41.0f);
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

  // Vignetting
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
  float dist = (p.x+p.y)*BAD_CRT_EFFECT;
  shsv.x += dist;
#endif

#if ENABLE_HUEOFFSET
	shsv = adjust_hue(shsv, HUE_OFFSET + Time * CHANGE_RATE);
#endif

  float3 col = float3(0.0, 0.0, 0.0);
  col += hsv2rgb(shsv);
  col += (0.35*spe+0.25*diff)*vig;

#if ENABLE_TINT
  float grayscale = (col.r + col.g + col.b) / 3.f;
  col = float4(grayscale, grayscale, grayscale, 0.1f);
  col *= TINT_COLOR;
#endif

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
	if(q.y > timeOver && q.y - REFRESHLINE_SIZE < timeOver ) col.rgb += (refreshLineColorTint * REFRESHLINE_STRENGTH);
	#endif

#if ENABLE_GRAIN
	float3 m = float3(tex, Time % 5 / 5) + 1.;
	float state = permute(permute(m.x) + m.y) + m.z;

	float pp = 0.95 * rand(state) + 0.025;
	float qq = pp - 0.5;
	float r2 = qq * qq;

	float grain = qq * (a2 + (a1 * r2 + a0) / (r2 * r2 + b1 * r2 + b0));
	col.rgb += GRAIN_INTENSITY * grain;
#endif

  return float4(col, 1.0);
}