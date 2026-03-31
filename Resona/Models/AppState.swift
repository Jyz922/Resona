//
//  AppState.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI
import Combine

class AppState: ObservableObject {
    enum Page: Equatable {
        case arrival
        case main       // Tab bar (Field, Analysis, Gallery)
    }

    @Published var currentPage: Page = .arrival
    @Published var selectedTab: Int = 0          // 0=Field, 1=Analysis, 2=Gallery
    @Published var showExpression: Bool = false   // fullscreen expression overlay
    @Published var savedRecords: [EmotionRecord] = []
    @Published var selectedRecordIndex: Int? = nil
    @Published var isTabBarMinimized: Bool = false // Tab bar minimize state

    /// The record currently selected (latest by default, or chosen via timeline)
    var displayedRecord: EmotionRecord? {
        guard !savedRecords.isEmpty else { return nil }
        if let index = selectedRecordIndex, index < savedRecords.count {
            return savedRecords[index]
        }
        return savedRecords.first  // most recent
    }

    func saveRecord(energy: Float, valence: Float, dominantColorHex: String, colorUsage: [ColorUsageEntry], snapshot: UIImage?, blobs: [GlassBlob]) {
        let snapshotData = snapshot?.pngData()
        let record = EmotionRecord(
            id: UUID(),
            energy: energy,
            valence: valence,
            timestamp: Date(),
            dominantColorHex: dominantColorHex,
            colorUsage: colorUsage,
            snapshotData: snapshotData,
            savedBlobs: blobs
        )
        savedRecords.insert(record, at: 0)
        selectedRecordIndex = 0  // select the newly saved record
    }
}
