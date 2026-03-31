//
//  ResonaApp.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI

@main
struct ResonaApp: App {
    @StateObject private var emotionEngine = EmotionEngine()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(emotionEngine)
                .environmentObject(appState)
        }
    }
}
