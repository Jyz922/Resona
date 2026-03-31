//
//  ExpressionView.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI

// MARK: - Glass Blob Model

struct GlassBlob: Identifiable, Codable, Equatable {
    let id: UUID
    var x: CGFloat              // Base center x (relative to card width ratio 0~1)
    var y: CGFloat              // Base center y (relative to card height ratio 0~1)
    var size: CGFloat           // Target diameter
    var previousSize: CGFloat   // Diameter before previous change
    var sizeChangeTime: TimeInterval = 0 // Time of previous change
    let creationTime: TimeInterval       // Absolute creation time (for fade-in lighting effect)
    var colorHex: String        // Emotion color at creation
    var wanderSeed: Double      // Random seed (unique wander path for each blob)
    
    static let initialSize: CGFloat = 120
    static let maxSize: CGFloat = 330
    static let growthPerClick: CGFloat = (maxSize - initialSize) / 15
    static let wanderSpeed: Double = 0.10
    static let wanderRadius: CGFloat = 200
    static let growAnimDuration: Double = 0.30 // Growth animation duration (seconds)
}

/// Expression screen — view emotion, adjust intensity, compose description, and save.
/// Features emotion orb, arc selector, glass card preview, and hold-to-save button.
struct ExpressionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var emotionEngine: EmotionEngine
    @Namespace private var glassNamespace
    @Namespace private var toolNamespace
    
    @State private var cardSize: CGSize = .zero
    @State private var toolsExpanded = false
    @State private var newDotOpacity: Double = 0
    @State private var holdTimer: Timer?
    @State private var isHolding = false

    var body: some View {
        ZStack {

            // 1️⃣ Fixed page background
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(.systemBackground), location: 0.0),
                    .init(color: Color(.systemBackground), location: 0.75),
                    .init(color: Color(hex: emotionEngine.dominantColorHex), location: 0.98),
                    .init(color: Color(hex: emotionEngine.dominantColorHex), location: 1.0),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                
                Text("Express")
                    .font(.system(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                Spacer()

                // 2️⃣ Main emotion white card + Metaball Glass Shader
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    
                    ZStack {
                        // Bottom layer: White drawing card + metaball shader
                        ZStack {
                            // Slightly dark base color, appears normal white after brightening by middle glass panel
                            RoundedRectangle(cornerRadius: 36)
                                .fill(Color(white: 0.90))

                            if let image = emotionEngine.accumulatedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cardSize.width, height: cardSize.height)
                                    .clipped()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 36))
                        .frame(height: 680)
                        .frame(maxWidth: .infinity)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { cardSize = geo.size }
                            }
                        )
                        .layerEffect(
                            makeMetaballShader(time: time),
                            maxSampleOffset: CGSize(width: 20, height: 20),
                            isEnabled: true
                        )


                        // New dot fade-in layer — above shader, below glass, doesn't affect metaball rendering
                        if let dotLayer = emotionEngine.newDotLayer {
                            Image(uiImage: dotLayer)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: cardSize.width, height: cardSize.height)
                                .clipped()
                                .opacity(newDotOpacity)
                                .allowsHitTesting(false)
                                .clipShape(RoundedRectangle(cornerRadius: 36))
                        }

                        // Middle layer: Glass texture panel (refraction only, reduced opacity to avoid overexposure)
                        RoundedRectangle(cornerRadius: 36)
                            .fill(Color.clear)
                            .glassEffect(.clear, in: .rect)
                            .frame(height: 680)
                            .frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .padding(.horizontal, 20)
                Spacer()

                HStack(spacing: 16) {

                    // Main button: Tap = single add, Long press = continuous add every 0.6s
                    Text("Add Color")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(Rectangle())
                        .glassEffect(.clear.interactive(), in: .capsule)
                        .foregroundStyle(.tint)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    guard !isHolding else { return }
                                    isHolding = true
                                    if toolsExpanded {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                            toolsExpanded = false
                                        }
                                    }
                                    // Trigger first immediately
                                    triggerPulse()
                                    // Start continuous trigger after 0.6s
                                    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                                        Task { @MainActor in
                                            triggerPulse()
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    holdTimer?.invalidate()
                                    holdTimer = nil
                                    isHolding = false
                                }
                        )

                    //----------------------------------------------
                    // ExpressionView Tool Controls
                    // Rewritten in Stewart Lynch style
                    //----------------------------------------------

                    GlassEffectContainer {

                        // MARK: - Tool Group

                        if toolsExpanded {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .onTapGesture {
                                        emotionEngine.accumulatedImage = nil
                                        clearGlassBlobs()
                                        collapseTools()
                                    }

                                Image(systemName: "plus")
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .onTapGesture {
                                        appState.showExpression = false
                                    }

                                Image(systemName: "checkmark")
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .onTapGesture {
                                        saveAndDismiss()
                                    }
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .onTapGesture {
                                        collapseTools()
                                    }
                            }
                            .foregroundStyle(.tint)
                            .glassEffect(.clear)
                            .glassEffectUnion(id: "toolsGroup", namespace: toolNamespace)
                            .glassEffectTransition(.matchedGeometry)
                        } else {
                            Button {
                                expandTools()
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 44, height: 44)
                            }
                            .glassEffect(.clear.interactive(), in: .capsule)
                            .glassEffectID("toolsGroup", in: toolNamespace)
                            .glassEffectTransition(.matchedGeometry)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - Metaball Shader Builder
    
    /// Build Metal metaball shader, pass current time to calculate floating position
    private func makeMetaballShader(time: TimeInterval) -> Shader {
        let blobs = emotionEngine.glassBlobs
        let count = min(blobs.count, 8)
        let smoothK: Float = 30.0 // Blend coefficient, larger is smoother
        
        var blobData: [SIMD4<Float>] = []
        var colorData: [SIMD4<Float>] = []
        var opacities = [Float](repeating: 1.0, count: 8)

        for i in 0..<8 {
            if i < count {
                let blob = blobs[i]
                let s = blob.wanderSeed
                let t = time * GlassBlob.wanderSpeed

                // 4 sine waves of different frequencies superimposed -> organic random wander path
                let dx = sin(t * 1.0 + s) * 0.5
                     + sin(t * 1.7 + s * 2.3) * 0.3
                     + sin(t * 0.4 + s * 4.1) * 0.2
                let dy = sin(t * 1.3 + s * 1.7) * 0.5
                     + sin(t * 0.8 + s * 3.1) * 0.3
                     + sin(t * 2.1 + s * 0.7) * 0.2

                // Velocity (derivative of position) -> used for movement direction deformation
                let vx = cos(t * 1.0 + s) * 1.0 * 0.5
                       + cos(t * 1.7 + s * 2.3) * 1.7 * 0.3
                       + cos(t * 0.4 + s * 4.1) * 0.4 * 0.2
                let vy = cos(t * 1.3 + s * 1.7) * 1.3 * 0.5
                       + cos(t * 0.8 + s * 3.1) * 0.8 * 0.3
                       + cos(t * 2.1 + s * 0.7) * 2.1 * 0.2
                let speed = sqrt(vx * vx + vy * vy)
                let angle = Float(atan2(vy, vx))
                let stretch = Float(1.0 + speed * 0.12) // 12% max stretch

                let r = GlassBlob.wanderRadius
                // Center point limited within card (edges can exceed, clipped by clipShape)
                let px = Float(min(max(blob.x * cardSize.width + CGFloat(dx) * r, 0), cardSize.width))
                let py = Float(min(max(blob.y * cardSize.height + CGFloat(dy) * r, 0), cardSize.height))
                let sz: Float
                let elapsed = time - blob.sizeChangeTime
                if elapsed < GlassBlob.growAnimDuration && blob.previousSize != blob.size {
                    // Smoothstep easing: smooth transition
                    let progress = min(elapsed / GlassBlob.growAnimDuration, 1.0)
                    let eased = CGFloat(progress * progress * (3.0 - 2.0 * progress))
                    sz = Float(blob.previousSize + (blob.size - blob.previousSize) * eased)
                } else {
                    sz = Float(blob.size)
                }
                
                // Calculate fade-in opacity for EACH newly spawned blob
                let spawnElapsed = time - blob.creationTime
                if spawnElapsed < 0.60 && spawnElapsed >= 0.0 {
                    opacities[i] = Float(spawnElapsed / 0.60)
                } else if spawnElapsed < 0.0 {
                    opacities[i] = 0.0
                }

                blobData.append(SIMD4<Float>(px, py, sz, angle))

                // Parse color hex -> RGB (0~1), w = stretch
                let color = UIColor(Color(hex: blob.colorHex))
                var cr: CGFloat = 0
                var cg: CGFloat = 0
                var cb: CGFloat = 0
                var ca: CGFloat = 0
                color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
                colorData.append(SIMD4<Float>(Float(cr), Float(cg), Float(cb), stretch))
            } else {
                blobData.append(SIMD4<Float>(0, 0, 0, 0))
                colorData.append(SIMD4<Float>(0, 0, 0, 0))
            }
        }
        
        return ShaderLibrary.metaballGlass(
            .float(Float(count)),
            .float(smoothK),
            .float4(opacities[0], opacities[1], opacities[2], opacities[3]),
            .float4(opacities[4], opacities[5], opacities[6], opacities[7]),
            .float4(blobData[0].x, blobData[0].y, blobData[0].z, blobData[0].w),
            .float4(blobData[1].x, blobData[1].y, blobData[1].z, blobData[1].w),
            .float4(blobData[2].x, blobData[2].y, blobData[2].z, blobData[2].w),
            .float4(blobData[3].x, blobData[3].y, blobData[3].z, blobData[3].w),
            .float4(blobData[4].x, blobData[4].y, blobData[4].z, blobData[4].w),
            .float4(blobData[5].x, blobData[5].y, blobData[5].z, blobData[5].w),
            .float4(blobData[6].x, blobData[6].y, blobData[6].z, blobData[6].w),
            .float4(blobData[7].x, blobData[7].y, blobData[7].z, blobData[7].w),
            .float4(colorData[0].x, colorData[0].y, colorData[0].z, colorData[0].w),
            .float4(colorData[1].x, colorData[1].y, colorData[1].z, colorData[1].w),
            .float4(colorData[2].x, colorData[2].y, colorData[2].z, colorData[2].w),
            .float4(colorData[3].x, colorData[3].y, colorData[3].z, colorData[3].w),
            .float4(colorData[4].x, colorData[4].y, colorData[4].z, colorData[4].w),
            .float4(colorData[5].x, colorData[5].y, colorData[5].z, colorData[5].w),
            .float4(colorData[6].x, colorData[6].y, colorData[6].z, colorData[6].w),
            .float4(colorData[7].x, colorData[7].y, colorData[7].z, colorData[7].w)
        )
    }
    
    private func triggerPulse() {
        // Record the color click for emotion analysis
        emotionEngine.recordColorClick()

        guard cardSize.width > 0 else { return }

        let colorHex = emotionEngine.dominantColorHex

        // ── Step 1: Advance composition state (counts, dominant, focal drift) ──
        emotionEngine.advanceComposition(colorHex: colorHex)

        // ── Step 2: Get visual hierarchy params ──
        let params = emotionEngine.dotVisualParams(colorHex: colorHex)
        let dotSize = params.size
        let radius  = dotSize / 2

        // ── Step 3: Sample brightest area (brightness-based placement) ──
        var bestX = CGFloat.random(in: radius...(cardSize.width - radius))
        var bestY = CGFloat.random(in: radius...(cardSize.height - radius))
        var bestBrightness: CGFloat = -1

        if let img = emotionEngine.accumulatedImage,
           let cgImage = img.cgImage {
            let w = cgImage.width
            let h = cgImage.height
            let bytesPerRow = cgImage.bytesPerRow
            let bytesPerPixel = cgImage.bitsPerPixel / 8

            if let cfData = cgImage.dataProvider?.data,
               let ptr = CFDataGetBytePtr(cfData) {
                let dataLen = CFDataGetLength(cfData)
                for _ in 0..<50 {
                    let cx = CGFloat.random(in: radius...(cardSize.width - radius))
                    let cy = CGFloat.random(in: radius...(cardSize.height - radius))
                    let px = min(Int(cx / cardSize.width * CGFloat(w)), w - 1)
                    let py = min(Int(cy / cardSize.height * CGFloat(h)), h - 1)
                    let offset = py * bytesPerRow + px * bytesPerPixel
                    if offset + 3 < dataLen {
                        let r = CGFloat(ptr[offset]) / 255.0
                        let g = CGFloat(ptr[offset + 1]) / 255.0
                        let b = CGFloat(ptr[offset + 2]) / 255.0
                        let a = CGFloat(ptr[offset + 3]) / 255.0
                        // Transparent area = white background = empty, brightness considered 1.0
                        let brightness = a < 0.01 ? 1.0 : (r + g + b) / 3.0
                        if brightness > bestBrightness {
                            bestBrightness = brightness
                            bestX = cx
                            bestY = cy
                        }
                    }
                }
            }
        }

        // ── Step 4: Get focal-system placement ──
        let focalPoint = emotionEngine.focalPlacement(colorHex: colorHex, cardSize: cardSize)

        // ── Step 5: Blend focal + brightness — weight shifts toward empty area as canvas fills ──
        // Early taps: composition matters more (50% focal).
        // Later taps: empty-area sampler takes over to avoid piling up in the center.
        let dotCount    = CGFloat(emotionEngine.placedDots.count)
        let focalWeight = max(0.35, 0.55 - dotCount * 0.008)
        var finalX = focalPoint.x * focalWeight + bestX * (1.0 - focalWeight)
        var finalY = focalPoint.y * focalWeight + bestY * (1.0 - focalWeight)

        // ── Step 5b: Enforce spacing — slide progressively toward empty area ──
        // Each retry reduces focal influence further until we're almost entirely at bestX/bestY.
        // bestX/bestY is the brightness-sampled empty area, so high attempts naturally
        // reach unoccupied corners instead of staying near the already-filled center.
        if emotionEngine.hasOverlap(center: CGPoint(x: finalX, y: finalY), radius: radius) {
            let lo = radius
            for attempt in 0..<50 {
                let t               = CGFloat(attempt) / 49.0               // 0 → 1
                let retryFocal      = focalWeight * (1.0 - t * 0.95)        // rapidly → 0
                let jitter          = cardSize.width * (0.02 + t * 0.4)
                let jx              = CGFloat.random(in: -jitter...jitter)
                let jy              = CGFloat.random(in: -jitter...jitter)
                let px = focalPoint.x * retryFocal + (bestX + jx) * (1.0 - retryFocal)
                let py = focalPoint.y * retryFocal + (bestY + jy) * (1.0 - retryFocal)
                let cx = min(max(px, lo), cardSize.width  - lo)
                let cy = min(max(py, lo), cardSize.height - lo)
                if !emotionEngine.hasOverlap(center: CGPoint(x: cx, y: cy), radius: radius) {
                    finalX = cx; finalY = cy; break
                }
                // Final attempt: accept the candidate (canvas is genuinely full)
                if attempt == 49 { finalX = cx; finalY = cy }
            }
        }

        // ── Step 6: Render new dot as separate layer with easeIn fade ──

        // If a previous dot overlay is still pending, bake it first
        if let pending = emotionEngine.newDotLayer {
            let comp = UIGraphicsImageRenderer(size: cardSize).image { ctx in
                emotionEngine.accumulatedImage?.draw(in: CGRect(origin: .zero, size: cardSize))
                pending.draw(in: CGRect(origin: .zero, size: cardSize))
            }
            emotionEngine.accumulatedImage = comp
            emotionEngine.newDotLayer = nil
        }

        // Render only the new dot on transparent background
        let dotImage = UIGraphicsImageRenderer(size: cardSize).image { context in
            context.cgContext.setBlendMode(.normal)
            let uiColor = emotionEngine.harmonizedColor(from: colorHex)
            let center = CGPoint(x: finalX, y: finalY)
            let gradientColors = [
                uiColor.withAlphaComponent(1).cgColor,
                uiColor.withAlphaComponent(0.95).cgColor,
                uiColor.withAlphaComponent(0.0).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: gradientColors,
                locations: [0.0, 0.15, 0.85]
            ) {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: radius * 2.2,
                    options: []
                )
            }
        }
        
        // Show overlay and animate opacity
        emotionEngine.newDotLayer = dotImage
        newDotOpacity = 0
        withAnimation(.easeIn(duration: 0.4)) {
            newDotOpacity = 1
        }
        
        emotionEngine.recordPlacedDot(center: CGPoint(x: finalX, y: finalY), radius: radius)
        emotionEngine.totalClicks += 1

        let isFirstEverBlob = emotionEngine.glassBlobs.isEmpty

        // Schedule baking after animation completes
        let capturedSize = cardSize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [emotionEngine] in
            guard let layer = emotionEngine.newDotLayer else { return }
            let comp = UIGraphicsImageRenderer(size: capturedSize).image { ctx in
                emotionEngine.accumulatedImage?.draw(in: CGRect(origin: .zero, size: capturedSize))
                layer.draw(in: CGRect(origin: .zero, size: capturedSize))
            }
            emotionEngine.accumulatedImage = comp
            emotionEngine.newDotLayer = nil
            
            // If completely blank canvas (first drop), wait for color to settle and render before generating bubble to avoid shader sampling white background and causing black edges
            if isFirstEverBlob {
                self.updateGlassBlobs()
            }
        }

        // For non-first bubble, color fade-in and bubble bounce/grow can sync, won't cause large black edge flickering
        if !isFirstEverBlob {
            updateGlassBlobs()
        }
    }
    
    // MARK: - Glass Blob Logic
    
    /// Core logic: Generate new bubble on first click or when switching to new emotion, same color click only increases volume
    private func updateGlassBlobs() {
        let currentColor = emotionEngine.dominantColorHex

        if emotionEngine.glassBlobs.isEmpty {
            spawnBlob()
            emotionEngine.lastSpawnedColorHex = currentColor
        } else if currentColor != emotionEngine.lastSpawnedColorHex {
            spawnBlob()
            emotionEngine.lastSpawnedColorHex = currentColor
        } else {
            growLast()
        }
    }
    
    /// Generate a new glass bubble at random position on card
    private func spawnBlob() {
        guard cardSize.width > 0 else { return }
        
        let margin: CGFloat = 0.15
        let x = CGFloat.random(in: margin...(1 - margin))
        let y = CGFloat.random(in: margin...(1 - margin))
        
        let blob = GlassBlob(
            id: UUID(),
            x: x,
            y: y,
            size: GlassBlob.initialSize,
            previousSize: GlassBlob.initialSize,
            sizeChangeTime: Date.timeIntervalSinceReferenceDate,
            creationTime: Date.timeIntervalSinceReferenceDate,
            colorHex: emotionEngine.dominantColorHex,
            wanderSeed: Double.random(in: 0...100)
        )
        
        emotionEngine.glassBlobs.append(blob)
    }
    
    /// Only increase the newest bubble
    private func growLast() {
        guard !emotionEngine.glassBlobs.isEmpty else { return }
        let i = emotionEngine.glassBlobs.count - 1
        let now = Date.timeIntervalSinceReferenceDate
        let blob = emotionEngine.glassBlobs[i]
        let elapsed = now - blob.sizeChangeTime
        let currentDisplayed: CGFloat
        if elapsed < GlassBlob.growAnimDuration && blob.previousSize != blob.size {
            let progress = min(elapsed / GlassBlob.growAnimDuration, 1.0)
            let eased = CGFloat(progress * progress * (3.0 - 2.0 * progress))
            currentDisplayed = blob.previousSize + (blob.size - blob.previousSize) * eased
        } else {
            currentDisplayed = blob.size
        }
        let newSize = min(currentDisplayed + GlassBlob.growthPerClick, GlassBlob.maxSize)
        emotionEngine.glassBlobs[i].previousSize = currentDisplayed
        emotionEngine.glassBlobs[i].size = newSize
        emotionEngine.glassBlobs[i].sizeChangeTime = now
    }
    
    private func saveAndDismiss() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let isCardEmpty = emotionEngine.totalClicks == 0 && emotionEngine.glassBlobs.isEmpty && emotionEngine.accumulatedImage == nil
        
        if isCardEmpty {
            // Document is empty, do not create record, just return to Create tab
            appState.showExpression = false
            appState.selectedTab = 0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                emotionEngine.resetSession()
            }
            return
        }
        
        appState.saveRecord(
            energy: emotionEngine.energy,
            valence: emotionEngine.valence,
            dominantColorHex: emotionEngine.dominantColorHex,
            colorUsage: emotionEngine.buildColorUsage(),
            snapshot: emotionEngine.accumulatedImage,
            blobs: emotionEngine.glassBlobs
        )
        
        // Dismiss expression overlay and switch to Analysis tab
        appState.showExpression = false
        appState.selectedTab = 1
        
        // Delay resetting the creation session until the fade-out animation completes
        // This ensures the current visual state holds steady while cross-fading out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            emotionEngine.resetSession()
        }
    }
    
    private func expandTools() {

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            toolsExpanded = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                toolsExpanded = true
            }
        }
    }

    private func collapseTools() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            toolsExpanded = false
        }
    }
    
    private func clearGlassBlobs() {
        emotionEngine.glassBlobs.removeAll()
        emotionEngine.totalClicks = 0
        emotionEngine.placedDots = []
        emotionEngine.newDotLayer = nil
    }

}
