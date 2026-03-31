//
//  MainTabView.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/25/26.
//

import SwiftUI

/// Tab bar container shown after ArrivalView.
/// Three tabs: Emotional Field, Analysis, Gallery.
/// ExpressionView is presented as a fullscreen overlay from the Field tab.
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var emotionEngine: EmotionEngine

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            EmotionalFieldView()
                .tabItem {
                    Label("Create", systemImage: "paintbrush.pointed")
                }
                .tag(0)

            EmotionAnalysisView()
                .tabItem {
                    Label("Analysis", systemImage: "chart.dots.scatter")
                }
                .tag(1)

            GalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "square.grid.2x2")
                }
                .tag(2)
        }
        .overlay {
            if appState.showExpression {
                ExpressionView()
                    .environmentObject(appState)
                    .environmentObject(emotionEngine)
                    // Apply a cross-fade transition instead of the default bottom slide
                    .transition(.opacity)
                    // Ensure the overlay uses its own stacking context to prevent layout shifts
                    .zIndex(1)
            }
        }
        // Animate the appearance and disappearance of ExpressionView
        .animation(.easeInOut(duration: 0.4), value: appState.showExpression)
    }
}
