//
//  EmotionRecord.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import Foundation
import Combine
import UIKit

// MARK: - Color Usage Entry
/// Tracks how many times a specific color was used during a creation session.
struct ColorUsageEntry: Codable, Equatable, Identifiable {
    var id: String { colorHex }
    let colorHex: String
    let count: Int
    /// The energy value when this color was used (0...1)
    let energy: Float
    /// The valence value when this color was used (-1...1)
    let valence: Float

    /// Emotional intensity: distance from the matrix center (energy=0.5, valence=0).
    /// Ranges 0...1 where 0 = perfectly neutral center, 1 = extreme corner.
    /// Formula: normalized euclidean distance in the energy/valence space.
    var intensity: Float {
        let dE = energy - 0.5          // -0.5 ... +0.5
        let dV = valence / 2.0         // -0.5 ... +0.5, scaled to match energy range
        let dist = sqrt(dE * dE + dV * dV)
        let maxDist: Float = sqrt(0.5)  // corner distance ≈ 0.707
        return min(dist / maxDist, 1.0)
    }

    /// Human-readable intensity level
    var intensityLabel: String {
        switch intensity {
        case 0..<0.25: return "Subtle"
        case 0.25..<0.5: return "Moderate"
        case 0.5..<0.75: return "Strong"
        default: return "Intense"
        }
    }

    /// Maps the energy/valence position to an emotion category.
    /// Uses a directional approach: the dominant axis determines the category,
    /// while intensity determines how pronounced the emotion is.
    var emotionCategory: String {
        let dE = energy - 0.5   // positive = energetic, negative = calm
        let dV = valence        // positive = positive, negative = negative

        // Near center — balanced/neutral
        if intensity < 0.2 { return "Balanced Harmony" }

        // Determine quadrant/axis based on which direction is strongest
        let absE = abs(dE)
        let absV = abs(dV) / 2  // scale valence to match energy range

        // Corner quadrants (both axes significant)
        if absE > 0.1 && absV > 0.1 {
            if dE > 0 && dV > 0 { return "Warm Excitement" }
            if dE > 0 && dV < 0 { return "Restless Tension" }
            if dE < 0 && dV > 0 { return "Peaceful Optimism" }
            if dE < 0 && dV < 0 { return "Deep Reflection" }
        }

        // Single-axis dominant
        if absE > absV {
            return dE > 0 ? "High Energy" : "Calm Presence"
        } else {
            return dV > 0 ? "Gentle Joy" : "Quiet Contemplation"
        }
    }
}

// MARK: - Emotion Category Summary
/// Aggregated summary of one emotion category across all color clicks.
struct EmotionCategorySummary: Identifiable {
    let id = UUID()
    let category: String
    let totalClicks: Int
    let percentage: Double
    let averageEnergy: Float
    let averageValence: Float
    let averageIntensity: Float
    let representativeColorHex: String
}

// MARK: - Emotion Record
struct EmotionRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let energy: Float
    let valence: Float
    let timestamp: Date
    let dominantColorHex: String
    let colorUsage: [ColorUsageEntry]
    let snapshotData: Data?
    let savedBlobs: [GlassBlob]

    // MARK: Derived emotion name (based on the overall session energy/valence)
    var emotionName: String {
        let e = energy
        let v = valence

        if e > 0.6 && v > 0.3 {
            return "Warm Excitement"
        } else if e > 0.6 && v < -0.3 {
            return "Restless Tension"
        } else if e < 0.4 && v > 0.3 {
            return "Peaceful Optimism"
        } else if e < 0.4 && v < -0.3 {
            return "Deep Reflection"
        } else if e > 0.6 {
            return "High Energy"
        } else if e < 0.4 {
            return "Calm Presence"
        } else if v > 0.3 {
            return "Gentle Joy"
        } else if v < -0.3 {
            return "Quiet Contemplation"
        } else {
            return "Balanced Harmony"
        }
    }

    // MARK: - Intensity Metrics

    /// Overall session intensity: weighted average of all clicks' intensities.
    var overallIntensity: Float {
        let totalClicks = colorUsage.reduce(0) { $0 + $1.count }
        guard totalClicks > 0 else { return 0 }
        let weightedSum = colorUsage.reduce(Float(0)) { $0 + $1.intensity * Float($1.count) }
        return weightedSum / Float(totalClicks)
    }

    /// How "scattered" the emotions are — high spread = conflicting emotions.
    /// Computed as the standard deviation of click positions from the centroid.
    var emotionalSpread: Float {
        let totalClicks = colorUsage.reduce(0) { $0 + $1.count }
        guard totalClicks > 1 else { return 0 }

        // Centroid
        let avgE = colorUsage.reduce(Float(0)) { $0 + $1.energy * Float($1.count) } / Float(totalClicks)
        let avgV = colorUsage.reduce(Float(0)) { $0 + $1.valence * Float($1.count) } / Float(totalClicks)

        // Variance
        var variance: Float = 0
        for entry in colorUsage {
            let dE = entry.energy - avgE
            let dV = (entry.valence - avgV) / 2
            variance += (dE * dE + dV * dV) * Float(entry.count)
        }
        variance /= Float(totalClicks)

        let maxSpread: Float = 0.5  // normalize
        return min(sqrt(variance) / maxSpread, 1.0)
    }

    /// Human-readable summary of emotional spread
    var spreadLabel: String {
        switch emotionalSpread {
        case 0..<0.2: return "Focused"
        case 0.2..<0.4: return "Centered"
        case 0.4..<0.6: return "Varied"
        case 0.6..<0.8: return "Diverse"
        default: return "Conflicted"
        }
    }

    /// Human-readable intensity label
    var intensityLabel: String {
        switch overallIntensity {
        case 0..<0.25: return "Subtle"
        case 0.25..<0.5: return "Moderate"
        case 0.5..<0.75: return "Strong"
        default: return "Intense"
        }
    }

    // MARK: Emotion Analysis
    /// Builds aggregated emotion category summaries from the color usage data.
    var emotionSummaries: [EmotionCategorySummary] {
        let totalClicks = colorUsage.reduce(0) { $0 + $1.count }
        guard totalClicks > 0 else { return [] }

        // Group color entries by emotion category
        var grouped: [String: (clicks: Int, energySum: Float, valenceSum: Float, intensitySum: Float, hex: String)] = [:]

        for entry in colorUsage {
            let cat = entry.emotionCategory
            var existing = grouped[cat] ?? (0, 0, 0, 0, entry.colorHex)
            existing.clicks += entry.count
            existing.energySum += entry.energy * Float(entry.count)
            existing.valenceSum += entry.valence * Float(entry.count)
            existing.intensitySum += entry.intensity * Float(entry.count)
            if existing.clicks == entry.count { existing.hex = entry.colorHex }
            grouped[cat] = existing
        }

        return grouped.map { (category, data) in
            EmotionCategorySummary(
                category: category,
                totalClicks: data.clicks,
                percentage: Double(data.clicks) / Double(totalClicks) * 100,
                averageEnergy: data.energySum / Float(data.clicks),
                averageValence: data.valenceSum / Float(data.clicks),
                averageIntensity: data.intensitySum / Float(data.clicks),
                representativeColorHex: data.hex
            )
        }
        .sorted { $0.totalClicks > $1.totalClicks }
    }

    /// The dominant emotion — the category with the most clicks
    var dominantEmotion: String {
        emotionSummaries.first?.category ?? emotionName
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var shortTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: timestamp)
    }
}
