//
//  EmotionalField.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI

struct EmotionalFieldView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var emotionEngine: EmotionEngine

    @State private var isDragging = false

    private let matrixSize: CGFloat = 320

    var body: some View {

        ZStack {

            // MARK: - Background Layer
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(.systemBackground), location: 0.0),
                    .init(color: Color(.systemBackground), location: 0.5),
                    .init(color: Color(hex: emotionEngine.dominantColorHex), location: 0.9),
                    .init(color: Color(hex: emotionEngine.dominantColorHex), location: 1.0),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()   // ✅ Only background ignores safe area
            .sensoryFeedback(.selection, trigger: emotionEngine.emotionName)

            // MARK: - Content Layer
            VStack {
                // Title
                Text("Create")
                    .font(.system(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                Spacer()

                // Emotion Label
                Text(emotionEngine.emotionName)
                    .font(.system(size: 20, weight: .semibold))
                    .animation(.easeInOut(duration: 0.1), value: emotionEngine.emotionName)
                
                Spacer()
                
                // MARK: Emotion Matrix
                ZStack {
                    
                    // Color Palette
                    ZStack {
                        Color.white
                        RadialGradient(colors: [.coral, .clear],
                                       center: .topLeading,
                                       startRadius: 0,
                                       endRadius: matrixSize * 0.9)
                            .opacity(0.85)

                        RadialGradient(colors: [.gold, .clear],
                                       center: .topTrailing,
                                       startRadius: 0,
                                       endRadius: matrixSize * 0.9)
                            .opacity(0.85)

                        RadialGradient(colors: [.deepIndigo, .clear],
                                       center: .bottomLeading,
                                       startRadius: 0,
                                       endRadius: matrixSize * 0.8)
                            .opacity(0.75)

                        RadialGradient(colors: [.teal, .clear],
                                       center: .bottomTrailing,
                                       startRadius: 0,
                                       endRadius: matrixSize * 0.8)
                            .opacity(0.75)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .frame(width: matrixSize, height: matrixSize)


                    // Axis Labels
                    ZStack {

                        VStack {
                            Text("Energetic")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text("Calm")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.vertical, 8)

                        HStack {
                            Text("Negative")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text("Positive")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(width: matrixSize, height: matrixSize)


                    // MARK: Draggable Glass Sphere
                    Circle()
                        .fill(Color.clear)
                        .frame(width: isDragging ? 65 : 55,
                               height: isDragging ? 65 : 55)
                        .glassEffect(.clear)
                        .contentShape(Circle())
                        .position(
                            x: matrixSize / 2 + CGFloat(emotionEngine.valence) * (matrixSize / 2 - 30),
                            y: matrixSize / 2 - CGFloat(emotionEngine.energy - 0.5) * (matrixSize - 60)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    isDragging = true

                                    let x = gesture.location.x
                                    let y = gesture.location.y

                                    let newValence = Float((x - matrixSize / 2) / (matrixSize / 2 - 30))
                                    let newEnergy = Float(0.5 - (y - matrixSize / 2) / (matrixSize - 60))

                                    emotionEngine.valence = min(max(newValence, -1), 1)
                                    emotionEngine.energy = min(max(newEnergy, 0), 1)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                }
                .frame(width: matrixSize, height: matrixSize)
                Spacer()

                // Continue Button
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        appState.showExpression = true
                    }
                } label: {
                    Text("Express")
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 32)
                        .frame(height: 48)
                        .glassEffect(.clear.interactive(), in: .capsule)
                }
                .padding(.bottom, 30)

            }
        }
        .onAppear {
            emotionEngine.valence = 0
            emotionEngine.energy = 0.5
        }
        .onChange(of: appState.showExpression) { _, isShowing in
            if !isShowing {
                // Wait for fade-out animation to finish before resetting emotion (background color)
                // This ensures the background retains the original page's emotion color during transition, achieving seamless color blending
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        emotionEngine.valence = 0
                        emotionEngine.energy = 0.5
                    }
                }
            }
        }
    }
}
