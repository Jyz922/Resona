//
//  ArrivalView.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI

/// Welcome screen — minimal, centered glass sphere with app title.
/// Tap anywhere to proceed to emotional field.
struct ArrivalView: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var glassNamespace
    @State private var appeared = false
    @State private var breathScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1.0 : 0)

            // Title
            VStack(spacing: 12) {
                Text("Resona")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Emotional Composition System")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1.0 : 0)

            Spacer()

            // Prompt
            Text("Touch to begin")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
                .opacity(appeared ? 0.7 : 0)

            Spacer()
                .frame(height: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appState.currentPage = .main
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                appeared = true
            }
            // Breathing animation
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathScale = 1.15
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: appState.currentPage)
    }
}
