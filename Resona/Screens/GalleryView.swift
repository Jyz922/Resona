//
//  GalleryView.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/25/26.
//

import SwiftUI

/// Gallery page — browse saved expression creations one at a time.
/// Shows the selected expression canvas with glass bubbles and a timeline strip.
struct GalleryView: View {
    @EnvironmentObject var appState: AppState

    private var selectedIndex: Int {
        get { appState.selectedRecordIndex ?? 0 }
    }

    private var displayedRecord: EmotionRecord? {
        guard !appState.savedRecords.isEmpty else { return nil }
        let idx = min(selectedIndex, appState.savedRecords.count - 1)
        return appState.savedRecords[idx]
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Header
            HStack {
                Text("Gallery")
                    .font(.system(size: 24, weight: .bold))

                Spacer()

                if let record = displayedRecord {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(record.dominantEmotion)
                            .font(.system(size: 14, weight: .semibold))
                        Text(record.formattedDate)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 15)

            if !appState.savedRecords.isEmpty {
                // MARK: - Swipeable Expression Canvas Cards
                TabView(selection: Binding(
                    get: { appState.selectedRecordIndex ?? 0 },
                    set: { appState.selectedRecordIndex = $0 }
                )) {
                    ForEach(Array(appState.savedRecords.enumerated()), id: \.element.id) { index, record in
                        let isActive = appState.selectedTab == 2 && index == (appState.selectedRecordIndex ?? 0)
                        
                        TimelineView(.periodic(from: .now, by: isActive ? 1.0 / 30.0 : 60.0)) { context in
                            let time = context.date.timeIntervalSinceReferenceDate
                            
                            GeometryReader { geo in
                                ZStack {
                                    // Base card + snapshot + metaball shader
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 36)
                                            .fill(Color(white: 0.90))

                                        if let data = record.snapshotData,
                                           let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: geo.size.width, height: geo.size.height)
                                                .clipped()
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 36))
                                    .layerEffect(
                                        makeMetaballShader(blobs: record.savedBlobs, time: time, cardSize: geo.size),
                                        maxSampleOffset: CGSize(width: 20, height: 20),
                                        isEnabled: !record.savedBlobs.isEmpty
                                    )

                                    // Glass overlay
                                    RoundedRectangle(cornerRadius: 36)
                                        .fill(Color.clear)
                                        .glassEffect(.clear, in: .rect)
                                        .allowsHitTesting(false)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 36))
                            }
                        }
                        .padding(.horizontal, 20)
                        .tag(index)
                        // Rotate back the content so it's not mirrored
                        .rotation3DEffect(.degrees(-180), axis: (x: 0, y: 1, z: 0))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Rotate the TabView itself to reverse the swipe mapping direction
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                Spacer()

                // MARK: - Timeline Strip
                TimelineStripView(
                    records: appState.savedRecords,
                    selectedIndex: Binding(
                        get: { appState.selectedRecordIndex ?? 0 },
                        set: { appState.selectedRecordIndex = $0 }
                    )
                )
                .padding(.horizontal, 30)
                .padding(.bottom, 15)

            } else {
                Spacer()
                emptyState
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.selectedRecordIndex)
    }

    // MARK: - Metaball Shader Builder (same as ExpressionView)

    private func makeMetaballShader(blobs: [GlassBlob], time: TimeInterval, cardSize: CGSize) -> Shader {
        let count = min(blobs.count, 8)
        let smoothK: Float = 30.0

        var blobData: [SIMD4<Float>] = []
        var colorData: [SIMD4<Float>] = []
        let opacities = [Float](repeating: 1.0, count: 8)

        for i in 0..<8 {
            if i < count {
                let blob = blobs[i]
                let s = blob.wanderSeed
                let t = time * GlassBlob.wanderSpeed

                let dx = sin(t * 1.0 + s) * 0.5
                     + sin(t * 1.7 + s * 2.3) * 0.3
                     + sin(t * 0.4 + s * 4.1) * 0.2
                let dy = sin(t * 1.3 + s * 1.7) * 0.5
                     + sin(t * 0.8 + s * 3.1) * 0.3
                     + sin(t * 2.1 + s * 0.7) * 0.2

                let vx = cos(t * 1.0 + s) * 1.0 * 0.5
                       + cos(t * 1.7 + s * 2.3) * 1.7 * 0.3
                       + cos(t * 0.4 + s * 4.1) * 0.4 * 0.2
                let vy = cos(t * 1.3 + s * 1.7) * 1.3 * 0.5
                       + cos(t * 0.8 + s * 3.1) * 0.8 * 0.3
                       + cos(t * 2.1 + s * 0.7) * 2.1 * 0.2
                let speed = sqrt(vx * vx + vy * vy)
                let angle = Float(atan2(vy, vx))
                let stretch = Float(1.0 + speed * 0.12)

                let r = GlassBlob.wanderRadius
                let px = Float(min(max(blob.x * cardSize.width + CGFloat(dx) * r, 0), cardSize.width))
                let py = Float(min(max(blob.y * cardSize.height + CGFloat(dy) * r, 0), cardSize.height))
                let sz = Float(blob.size)  // Use final size (no grow animation in gallery)

                blobData.append(SIMD4<Float>(px, py, sz, angle))

                let color = UIColor(Color(hex: blob.colorHex))
                var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
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

    private var emptyState: some View {
        VStack(spacing: 8) {
                Text("No creations yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Go to Create to express your feelings.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
        }
    }
}
