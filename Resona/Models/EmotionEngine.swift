//
//  EmotionEngine.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI
import Combine

class EmotionEngine: ObservableObject {
    // ─── Primary Axes ───
    @Published var energy: Float = 0.5       // 0 = calm ... 1 = intense
    @Published var valence: Float = 0.0      // -1 = negative ... +1 = positive
    @Published var accumulatedImage: UIImage?
    /// Newest single dot layer, used for easeIn fade-in animation
    @Published var newDotLayer: UIImage?

    // ─── Color Click Tracking ───
    /// Records each "Add Color" click with its color hex, energy, and valence at that moment.
    @Published var colorClickHistory: [(hex: String, energy: Float, valence: Float)] = []

    /// Call this each time the user taps "Add Color" to record the color used.
    func recordColorClick() {
        colorClickHistory.append((
            hex: dominantColorHex,
            energy: energy,
            valence: valence
        ))
    }

    /// Builds aggregated color usage entries from the click history.
    func buildColorUsage() -> [ColorUsageEntry] {
        // Group by (rounded energy, rounded valence) to cluster similar positions
        var grouped: [String: (hex: String, count: Int, energy: Float, valence: Float)] = [:]

        for click in colorClickHistory {
            // Use hex as the grouping key since each emotion position maps to a unique color
            let key = click.hex
            var existing = grouped[key] ?? (click.hex, 0, 0, 0)
            existing.count += 1
            // Weighted average of energy/valence
            let prevTotal = Float(existing.count - 1)
            existing.energy = (existing.energy * prevTotal + click.energy) / Float(existing.count)
            existing.valence = (existing.valence * prevTotal + click.valence) / Float(existing.count)
            grouped[key] = existing
        }

        return grouped.map { (_, data) in
            ColorUsageEntry(
                colorHex: data.hex,
                count: data.count,
                energy: data.energy,
                valence: data.valence
            )
        }
    }

    // ─── Glass Blob State (persists across page navigation) ───
    @Published var glassBlobs: [GlassBlob] = []
    @Published var totalClicks: Int = 0
    /// Color of the last generated bubble, used to detect emotion switch
    var lastSpawnedColorHex: String?

    // ─── Placed Dot Registry (for overlap avoidance) ───
    /// Records every rendered dot's center (pixel coords) and radius for overlap checks.
    var placedDots: [(center: CGPoint, radius: CGFloat)] = []

    /// Returns true when the proposed circle overlaps any existing dot or doesn't have enough spacing.
    /// Requires empty space between dots.
    func hasOverlap(center: CGPoint, radius: CGFloat) -> Bool {
        for dot in placedDots {
            let dx = center.x - dot.center.x
            let dy = center.y - dot.center.y
            let dist = sqrt(dx * dx + dy * dy)
            // Rendered size involves blur and fading edges.
            // We need a large multiplier to ensure the visible cores don't touch.
            if dist < (radius + dot.radius) * 2.20 { return true }
        }
        return false
    }

    /// Records a placed dot so future placements can avoid it.
    func recordPlacedDot(center: CGPoint, radius: CGFloat) {
        placedDots.append((center: center, radius: radius))
    }

    // ─── Palette Harmonizer State ───
    /// Hue of the first tap in this session (0–1). All subsequent colors are pulled toward it.
    var paletteAnchorHue: CGFloat?

    /// Returns a harmonized UIColor for rendering.
    /// - Pulls hue 15% toward the session anchor (shortest circular path).
    /// - Trims saturation by 12% for visual restraint.
    /// - Brightness is never modified — preserves emotion intensity encoding.
    func harmonizedColor(from hex: String) -> UIColor {
        let base = UIColor(Color(hex: hex))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Set anchor on first call of the session
        if paletteAnchorHue == nil { paletteAnchorHue = h }
        let anchor = paletteAnchorHue!

        // Circular shortest-path delta (stays within ±0.5 of the color wheel)
        var delta = anchor - h
        if delta >  0.5 { delta -= 1.0 }
        if delta < -0.5 { delta += 1.0 }
        var newH = h + delta * 0.15
        if newH < 0 { newH += 1.0 }
        if newH >= 1 { newH -= 1.0 }

        // Saturation trim — enough to unify without killing the emotion
        let newS = max(s * 0.88, 0.06)

        return UIColor(hue: newH, saturation: newS, brightness: b, alpha: a)
    }

    // ─── Composition Intelligence State ───
    /// Tap count per color hex — drives dominant emotion detection.
    var colorTapCounts: [String: Int] = [:]
    /// The hex color with the most taps; becomes the visual focal mass.
    var compositionDominantHex: String = ""
    /// Focal center in normalized coordinates (0–1). Biases dot placement.
    var focalCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// Running orbital angle for secondary-emotion dot distribution.
    var nextOrbitalAngle: Double = 0.0

    /// Resets the creation session (called after save or when starting fresh).
    func resetSession() {
        accumulatedImage = nil
        newDotLayer = nil
        colorClickHistory = []
        glassBlobs = []
        totalClicks = 0
        lastSpawnedColorHex = nil
        colorTapCounts = [:]
        compositionDominantHex = ""
        focalCenter = CGPoint(x: 0.5, y: 0.5)
        nextOrbitalAngle = 0.0
        placedDots = []
        paletteAnchorHue = nil
    }

    // ─── Particle Visual Properties (derived) ───
    var particleSpeed: Float { 0.5 + energy * 1.5 }
    var particleOpacity: Float { 0.15 + energy * 0.25 }  // never too bright
    var noiseScale: Float { 1.5 + (1.0 - energy) * 2.5 }

    // ─── Emotion Name ───
    var emotionName: String {
        let e = energy
        let v = valence

        if e > 0.6 && v > 0.3 { return "Warm Excitement" }
        if e > 0.6 && v < -0.3 { return "Restless Tension" }
        if e < 0.4 && v > 0.3 { return "Peaceful Optimism" }
        if e < 0.4 && v < -0.3 { return "Deep Reflection" }
        if e > 0.6 { return "High Energy" }
        if e < 0.4 { return "Calm Presence" }
        if v > 0.3 { return "Gentle Joy" }
        if v < -0.3 { return "Quiet Contemplation" }
        return "Balanced Harmony"
    }

    // ─── Dominant Color (for particles only, NOT for glass) ───
    var dominantColor: Color {
        let e = CGFloat(energy)
        let v = CGFloat((valence + 1) / 2) // normalize to 0...1

        // Calm-Negative: indigo  | Calm-Positive: teal
        // High-Negative: coral   | High-Positive: gold
        let topColor = Color.lerp(from: .coral, to: .gold, t: v)
        let bottomColor = Color.lerp(from: .deepIndigo, to: .teal, t: v)
        return Color.lerp(from: bottomColor, to: topColor, t: e)
    }

    var dominantColorHex: String {
        let e = Float(energy)
        let v = Float((valence + 1) / 2)

        let r = (1.0 - e) * (1.0 - v) * 0.39 + (1.0 - e) * v * 0.08 + e * (1.0 - v) * 1.0 + e * v * 1.0
        let g = (1.0 - e) * (1.0 - v) * 0.40 + (1.0 - e) * v * 0.72 + e * (1.0 - v) * 0.42 + e * v * 0.84
        let b = (1.0 - e) * (1.0 - v) * 0.95 + (1.0 - e) * v * 0.65 + e * (1.0 - v) * 0.42 + e * v * 0.42

        let ri = Int(min(r, 1.0) * 255)
        let gi = Int(min(g, 1.0) * 255)
        let bi = Int(min(b, 1.0) * 255)
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    // ─── Composition Intelligence ───

    struct DotVisualParams {
        var size:    CGFloat   // dot diameter
        var blur:    CGFloat   // shadow blur radius
        var opacity: CGFloat   // fill alpha
    }

    /// Call once per tap before computing placement.
    /// Updates tap counts, dominant hex, and applies focal-center drift.
    func advanceComposition(colorHex: String) {
        // 1. Increment tap count
        colorTapCounts[colorHex, default: 0] += 1

        // 2. Recompute dominant
        let previousDominant = compositionDominantHex
        let newDominant = colorTapCounts.max(by: { $0.value < $1.value })?.key ?? colorHex

        // 3. Dominant changed → relocate focal center (biased off-center for organic asymmetry)
        if newDominant != previousDominant {
            focalCenter = CGPoint(
                x: CGFloat.random(in: 0.30...0.60),
                y: CGFloat.random(in: 0.30...0.60)
            )
            compositionDominantHex = newDominant
        }

        // 4. Slow drift toward canvas center — preserves off-center bias for most of the session
        focalCenter.x += (0.5 - focalCenter.x) * 0.008
        focalCenter.y += (0.5 - focalCenter.y) * 0.008
    }

    /// Returns a pixel-space CGPoint for where this tap's dot should be placed.
    /// Dominant color → Gaussian cluster around focal center.
    /// Secondary color → golden-angle orbital band around focal center.
    func focalPlacement(colorHex: String, cardSize: CGSize) -> CGPoint {
        let fcx = focalCenter.x * cardSize.width
        let fcy = focalCenter.y * cardSize.height
        let isDominant = colorHex == compositionDominantHex
        let dominantCount = CGFloat(colorTapCounts[compositionDominantHex] ?? 1)

        let margin: CGFloat = 30

        func clamped(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(p.x, margin), cardSize.width  - margin),
                y: min(max(p.y, margin), cardSize.height - margin)
            )
        }

        if isDominant {
            // Wider base radius — gives dominant mass visual room to breathe
            // Tightens up to 50% over first 20 taps as the core solidifies
            let baseRadius  = cardSize.width * 0.38
            let tightening  = min(dominantCount / 20.0, 1.0)
            let radius      = baseRadius * (1.0 - tightening * 0.5)

            // Box-Muller Gaussian offset — organic, non-circular scatter
            let u1 = Double.random(in: 0.001...1.0)
            let u2 = Double.random(in: 0.0...1.0)
            let z  = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
            let u3 = Double.random(in: 0.001...1.0)
            let u4 = Double.random(in: 0.0...1.0)
            let z2 = sqrt(-2.0 * log(u3)) * cos(2.0 * .pi * u4)

            let gx = CGFloat(z  * 0.4) * radius
            let gy = CGFloat(z2 * 0.4) * radius
            return clamped(CGPoint(x: fcx + gx, y: fcy + gy))

        } else {
            // Orbital band pushed far from dominant core — clear spatial separation
            let orbitalRadius = cardSize.width * 0.52
            let radiusJitter  = CGFloat.random(in: -0.06...0.06) * cardSize.width
            let r             = orbitalRadius + radiusJitter

            // ~137.5° golden-angle step prevents dots stacking in same direction
            nextOrbitalAngle += 2.399 + Double.random(in: -0.25...0.25)

            let x = fcx + CGFloat(cos(nextOrbitalAngle)) * r
            let y = fcy + CGFloat(sin(nextOrbitalAngle)) * r
            return clamped(CGPoint(x: x, y: y))
        }
    }

    /// Returns size/blur/opacity with clear hierarchy between dominant (core) and secondary (halo).
    func dotVisualParams(colorHex: String) -> DotVisualParams {
        let baseSize:    CGFloat = CGFloat.random(in: 40...70)
        let baseBlur:    CGFloat = baseSize * 0.5
        // Lower base opacity — multiply blending darkens fast; keep each layer light
        let baseOpacity: CGFloat = 0.42

        if colorHex == compositionDominantHex {
            // Core: slightly larger, sharper focus, slightly more solid
            return DotVisualParams(
                size:    baseSize * 1.15,
                blur:    baseBlur * 0.70,
                opacity: min(baseOpacity + 0.10, 0.70)
            )
        } else {
            // Orbit: smaller, much more diffuse — reads as atmospheric halo
            return DotVisualParams(
                size:    baseSize * 0.86,
                blur:    baseBlur * 1.55,
                opacity: max(baseOpacity - 0.15, 0.10)
            )
        }
    }

    // ─── Particle SIMD color for Metal shader ───
    func particleColor(for colorScheme: ColorScheme) -> SIMD4<Float> {
        let e = energy
        let v = (valence + 1) / 2

        var r: Float, g: Float, b: Float

        if colorScheme == .light {
            // Soft, muted particles on light background
            r = (1.0 - e) * (1.0 - v) * 0.39 + (1.0 - e) * v * 0.08 + e * (1.0 - v) * 0.85 + e * v * 0.85
            g = (1.0 - e) * (1.0 - v) * 0.40 + (1.0 - e) * v * 0.60 + e * (1.0 - v) * 0.35 + e * v * 0.70
            b = (1.0 - e) * (1.0 - v) * 0.80 + (1.0 - e) * v * 0.55 + e * (1.0 - v) * 0.35 + e * v * 0.35
        } else {
            // Glowing particles on dark background
            r = (1.0 - e) * (1.0 - v) * 0.42 + (1.0 - e) * v * 0.10 + e * (1.0 - v) * 1.0 + e * v * 1.0
            g = (1.0 - e) * (1.0 - v) * 0.42 + (1.0 - e) * v * 0.75 + e * (1.0 - v) * 0.45 + e * v * 0.88
            b = (1.0 - e) * (1.0 - v) * 0.96 + (1.0 - e) * v * 0.68 + e * (1.0 - v) * 0.45 + e * v * 0.45
        }

        return SIMD4<Float>(r, g, b, 1.0)
    }
}
