//
//  ContentView.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var emotionEngine: EmotionEngine
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Layer 0: Base background (adapts to light/dark)
            Color(.systemBackground)
                .ignoresSafeArea()

            // Layer 1: Current page
            switch appState.currentPage {
            case .arrival:
                ArrivalView()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appState.currentPage)
    }
}
