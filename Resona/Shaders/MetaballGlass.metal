//
//  MetaballGlass.metal
//  GlassMind
//
//  SDF-based metaball smooth union shader for glass bubble merge effect.
//  SDF smooth union technique inspired by temoki/lq
//  (https://github.com/temoki/lq) — MIT License, Copyright 2025 Tim Lehmann
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ─── SDF Primitives ───

// Signed distance to a circle
float sdfCircle(float2 p, float2 center, float radius) {
    return length(p - center) - radius;
}

// Signed distance to a velocity-stretched circle (ellipse approximation)
float sdfStretchedCircle(float2 p, float2 center, float radius, float angle, float stretch) {
    float2 q = p - center;
    float c = cos(angle), s = sin(angle);
    // Rotate to velocity-aligned frame
    float2 rotated = float2(c * q.x + s * q.y, -s * q.x + c * q.y);
    // Stretch along velocity (x), compress perpendicular (y)
    rotated.x /= stretch;
    rotated.y *= sqrt(stretch);
    return length(rotated) - radius;
}

// Smooth union of two SDF values — creates liquid-like merge
float smoothUnion(float d1, float d2, float k) {
    if (k <= 0.0) return min(d1, d2);
    float e = max(k - abs(d1 - d2), 0.0);
    return min(d1, d2) - e * e * 0.25 / k;
}

// ─── Combined SDF for all blobs ───

float combinedSDF(float2 p, float4 blobs[8], float4 colors[8], int count, float k) {
    float d = 1e9;
    for (int i = 0; i < count; i++) {
        float radius = blobs[i].z / 2.0;
        if (radius > 0.0) {
            float angle = blobs[i].w;
            float stretch = colors[i].w;
            float di = sdfStretchedCircle(p, blobs[i].xy, radius, angle, stretch);
            d = smoothUnion(d, di, k);
        }
    }
    return d;
}

// ─── Main Shader ───

[[ stitchable ]] half4 metaballGlass(
    float2 position,
    SwiftUI::Layer layer,
    float count,
    float smoothK,
    float4 op0, float4 op1,
    float4 b0, float4 b1, float4 b2, float4 b3,
    float4 b4, float4 b5, float4 b6, float4 b7,
    float4 c0, float4 c1, float4 c2, float4 c3,
    float4 c4, float4 c5, float4 c6, float4 c7
) {
    float4 blobs[8] = { b0, b1, b2, b3, b4, b5, b6, b7 };
    float4 colors[8] = { c0, c1, c2, c3, c4, c5, c6, c7 };
    float opacities[8] = { op0.x, op0.y, op0.z, op0.w, op1.x, op1.y, op1.z, op1.w };
    int n = min(int(count), 8);
    
    if (n == 0) return layer.sample(position);
    
    // Compute SDF at current position
    float d = combinedSDF(position, blobs, colors, n, smoothK);
    
    // Early exit if far from any blob
    if (d > 5.0) return layer.sample(position);
    
    // Compute gradient (surface normal) via central differences
    float eps = 1.0;
    float dR = combinedSDF(position + float2(eps, 0), blobs, colors, n, smoothK);
    float dL = combinedSDF(position - float2(eps, 0), blobs, colors, n, smoothK);
    float dU = combinedSDF(position + float2(0, eps), blobs, colors, n, smoothK);
    float dD = combinedSDF(position - float2(0, eps), blobs, colors, n, smoothK);
    float2 grad = float2(dR - dL, dU - dD) / (2.0 * eps);
    float2 normal = length(grad) > 0.001 ? normalize(grad) : float2(0);
    
    half4 original = layer.sample(position);
    
    if (d < 0.0) {
        // ── Inside metaball shape: flat glass disc ──
        // Effects concentrate at edges, center is mostly transparent
        
        float depth = clamp(-d / 20.0, 0.0, 1.0);
        float edgeFactor = pow(1.0 - depth, 2.0);
        
        // Detect if background is light or dark
        half bgBrightness = (original.r + original.g + original.b) / half(3.0);
        half isLight = smoothstep(half(0.4), half(0.7), bgBrightness); // 0=dark, 1=light
        
        // Color tint and Local Opacity from nearest blobs
        float totalWeight = 0.0;
        float3 blendedColor = float3(0);
        float localOpacity = 0.0;
        
        for (int i = 0; i < n; i++) {
            float radius = blobs[i].z / 2.0;
            if (radius > 0.0) {
                float di = sdfCircle(position, blobs[i].xy, radius);
                float weight = exp(-max(di, 0.0) * 0.05);
                blendedColor += colors[i].rgb * weight;
                localOpacity += opacities[i] * weight;
                totalWeight += weight;
            }
        }
        if (totalWeight > 0.0) {
            blendedColor /= totalWeight;
            localOpacity /= totalWeight;
        } else {
            localOpacity = 1.0;
        }
        
        half renderOpacity = half(localOpacity);
        
        // Refraction only at edges
        float refractionStrength = 12.0 * edgeFactor * float(renderOpacity);
        float2 refractedPos = position + normal * refractionStrength;
        half4 refracted = layer.sample(refractedPos);
        half4 base = mix(original, refracted, half(0.8 * edgeFactor) * renderOpacity);
        
        // Stronger tint on light backgrounds for visibility
        half3 tint = half3(blendedColor);
        half tintStrength = mix(half(0.25), half(0.50), isLight) * renderOpacity;
        base.rgb = mix(base.rgb, tint, tintStrength);
        
        // Light mode: strong dark rim shadow for clear glass visibility
        // Dark mode: bright rim highlight
        half rimDarken = half(0.30 * edgeFactor) * isLight * renderOpacity;
        half rimLighten = half(0.18 * edgeFactor) * (half(1.0) - isLight) * renderOpacity;
        base.rgb *= half3(1.0 - rimDarken);
        base.rgb += half3(rimLighten);
        base.rgb = min(base.rgb, half3(1.0));
        
        return base;
        
    } else if (d < 3.0) {
        // Edge outline adapts to background
        float edge = smoothstep(3.0, 0.0, d);
        half bgBrightness2 = (original.r + original.g + original.b) / half(3.0);
        half isLight2 = smoothstep(half(0.4), half(0.7), bgBrightness2);
        
        // Interpolate outline opacity based on distance to nearest blobs
        float totalWeight = 0.0;
        float localOpacity = 0.0;
        for (int i = 0; i < n; i++) {
            float radius = blobs[i].z / 2.0;
            if (radius > 0.0) {
                float di = sdfCircle(position, blobs[i].xy, radius);
                float weight = exp(-max(di, 0.0) * 0.05);
                localOpacity += opacities[i] * weight;
                totalWeight += weight;
            }
        }
        if (totalWeight > 0.0) localOpacity /= totalWeight; else localOpacity = 1.0;
        half renderOpacity = half(localOpacity);
        
        // Light bg: strong dark outline, Dark bg: bright outline
        half darkOutline = half(edge * 0.25) * isLight2 * renderOpacity;
        half lightOutline = half(edge * 0.12) * (half(1.0) - isLight2) * renderOpacity;
        half3 delta = half3(lightOutline - darkOutline);
        return original + half4(delta, 0);
        
    } else {
        return original;
    }
}
