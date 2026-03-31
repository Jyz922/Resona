//
//  EmotionalAnalysis.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI

/// Emotion Analysis page — shown after saving a creation.
/// Top: Emotion analysis matrix with intensity rings, data points, and category breakdown.
/// Bottom: Interactive timeline chart with draggable data points.
/// Everything fits on one screen — no scrolling.
struct EmotionAnalysisView: View {
    @EnvironmentObject var appState: AppState

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text("Analysis")
                    .font(.system(size: 24, weight: .bold))

                Spacer()

                if appState.displayedRecord != nil {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .confirmationDialog(
                        "Delete this record?",
                        isPresented: $showDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            deleteCurrentRecord()
                        }
                    } message: {
                        Text("This will remove the analysis and its emotion card from the gallery.")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 15)

            
            // MARK: - Upper: Emotion Matrix
            if let record = appState.displayedRecord {
                EmotionMatrixAnalysis(record: record)
                    .padding(.horizontal, 30)

                // MARK: - Middle: Metrics (fills remaining space)
                EmotionMetricsExpanded(record: record)
                    .padding(.horizontal, 30)
                    .padding(.top, 15)
                    .padding(.bottom, 15)
                Spacer()
            } else {
                Spacer()
                emptyState
                Spacer()
            }

            // MARK: - Bottom: Thin Timeline Strip
            if appState.savedRecords.count > 0 {
                TimelineStripView(
                    records: appState.savedRecords,
                    selectedIndex: Binding(
                        get: { appState.selectedRecordIndex ?? 0 },
                        set: { appState.selectedRecordIndex = $0 }
                    )
                )
                .padding(.horizontal, 30)
                .padding(.bottom, 15)
            }
        }
    }

    private func deleteCurrentRecord() {
        let index = appState.selectedRecordIndex ?? 0
        guard index < appState.savedRecords.count else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            appState.savedRecords.remove(at: index)
            if appState.savedRecords.isEmpty {
                appState.selectedRecordIndex = nil
            } else {
                appState.selectedRecordIndex = min(index, appState.savedRecords.count - 1)
            }
        }
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


// MARK: - Emotion Matrix Analysis
/// Displays the 4-corner emotion matrix with:
/// - Concentric intensity rings (closer to edge = stronger emotion)
/// - Data points sized by click count, positioned by energy/valence
/// - Overall position indicator
struct EmotionMatrixAnalysis: View {
    let record: EmotionRecord

    var body: some View {
        VStack(spacing: 15) {
            // Matrix — fills available width, keeps square aspect
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                ZStack {
                    // Background gradient matrix
                    ZStack {
                        Color.white
                        RadialGradient(colors: [.coral, .clear],
                                       center: .topLeading,
                                       startRadius: 0,
                                       endRadius: size * 0.9)
                            .opacity(0.85)

                        RadialGradient(colors: [.gold, .clear],
                                       center: .topTrailing,
                                       startRadius: 0,
                                       endRadius: size * 0.9)
                            .opacity(0.85)

                        RadialGradient(colors: [.deepIndigo, .clear],
                                       center: .bottomLeading,
                                       startRadius: 0,
                                       endRadius: size * 0.8)
                            .opacity(0.75)

                        RadialGradient(colors: [.teal, .clear],
                                       center: .bottomTrailing,
                                       startRadius: 0,
                                       endRadius: size * 0.8)
                            .opacity(0.75)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Intensity rings — concentric circles from center
                    // showing the intensity zones: Subtle → Moderate → Strong → Intense
                    ForEach([0.25, 0.5, 0.75] as [CGFloat], id: \.self) { level in
                        Circle()
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.8)
                            .frame(
                                width: size * level,
                                height: size * level
                            )
                    }

                    // Center crosshair (neutral point)
                    Path { path in
                        let center = size / 2
                        let armLen: CGFloat = 8
                        path.move(to: CGPoint(x: center - armLen, y: center))
                        path.addLine(to: CGPoint(x: center + armLen, y: center))
                        path.move(to: CGPoint(x: center, y: center - armLen))
                        path.addLine(to: CGPoint(x: center, y: center + armLen))
                    }
                    .stroke(.white.opacity(0.3), lineWidth: 1)

                    // Data points — each color click plotted at its energy/valence position
                    // Wrapped in Group with .id so only dots fade, background stays stable
                    Group {
                        ForEach(Array(record.colorUsage.enumerated()), id: \.offset) { _, entry in
                            let ptSize = pointSize(for: entry.count)
                            Circle()
                                .fill(Color(hex: entry.colorHex))
                                .frame(width: ptSize, height: ptSize)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
                                )
                                .shadow(color: Color(hex: entry.colorHex).opacity(0.5), radius: 4)
                                .position(
                                    x: size / 2 + CGFloat(entry.valence) * (size / 2 - 20),
                                    y: size / 2 - CGFloat(entry.energy - 0.5) * (size - 40)
                                )
                        }
                    }
                    .id(record.id)
                    .transition(.opacity)
                }
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)

            // Legend
            HStack(spacing: 12) {
                legendItem(color: .coral, label: "Restless")
                legendItem(color: .gold, label: "Excited")
                legendItem(color: .deepIndigo, label: "Reflective")
                legendItem(color: .teal, label: "Peaceful")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func pointSize(for count: Int) -> CGFloat {
        let base: CGFloat = 10
        let scale = min(CGFloat(count) * 3, 20)
        return base + scale
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}


// MARK: - Expanded Emotion Metrics
/// Shows intensity gauge, emotional spread, and full category breakdown.
struct EmotionMetricsExpanded: View {
    let record: EmotionRecord

    var body: some View {
        VStack(spacing: 14) {
            // Gauges row
            HStack(spacing: 24) {
                // Intensity gauge
                gaugeView(
                    title: "Intensity",
                    value: CGFloat(record.overallIntensity),
                    label: record.intensityLabel,
                    colors: [.teal, .gold, .coral]
                )

                // Spread gauge
                gaugeView(
                    title: "Spread",
                    value: CGFloat(record.emotionalSpread),
                    label: record.spreadLabel,
                    colors: [.deepIndigo, .teal, .gold]
                )

                // Total clicks
                VStack(spacing: 4) {
                    Text("Clicks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text("\(record.colorUsage.reduce(0) { $0 + $1.count })")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("total")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Proportion bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(record.emotionSummaries) { summary in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: summary.representativeColorHex).opacity(0.8))
                            .frame(width: max(geo.size.width * summary.percentage / 100 - 2, 4))
                    }
                }
            }
            .frame(height: 10)

            // All categories list
            VStack(spacing: 6) {
                ForEach(record.emotionSummaries) { summary in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: summary.representativeColorHex))
                            .frame(width: 8, height: 8)

                        Text(summary.category)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        // Intensity badge
                        Text(summary.averageIntensity > 0.5 ? "Strong" : summary.averageIntensity > 0.25 ? "Moderate" : "Subtle")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: summary.representativeColorHex).opacity(0.15))
                            .clipShape(Capsule())

                        Text("\(Int(summary.percentage))%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func gaugeView(title: String, value: CGFloat, label: String, colors: [Color]) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        AngularGradient(colors: colors, center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            .frame(width: 56, height: 56)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}


// MARK: - Timeline Strip
/// Thin bar strip at the bottom — fixed-height bars, each colored by dominant emotion.
/// Tap or drag across to browse past sessions.
struct TimelineStripView: View {
    let records: [EmotionRecord]
    @Binding var selectedIndex: Int

    private let barHeight: CGFloat = 32
    private let barSpacing: CGFloat = 2

    private var chronological: [EmotionRecord] {
        records.reversed()
    }

    private func recordsIndex(from chronoIndex: Int) -> Int {
        records.count - 1 - chronoIndex
    }

    private var selectedChronoIndex: Int {
        records.count - 1 - selectedIndex
    }

    var body: some View {
        GeometryReader { geo in
            let totalBars = chronological.count
            let fixedBarWidth: CGFloat = 6
            let totalWidth = fixedBarWidth * CGFloat(totalBars) + barSpacing * CGFloat(max(totalBars - 1, 0))
            let leadingOffset = max((geo.size.width - totalWidth) / 2, 0)
           
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(Array(chronological.enumerated()), id: \.element.id) { i, record in
                    let isSelected = i == selectedChronoIndex
                    let emotionColor = Color(hex: record.dominantColorHex)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(emotionColor.opacity(isSelected ? 1.0 : 0.35))
                        .frame(
                            width: fixedBarWidth,
                            height: isSelected ? barHeight + 8 : barHeight
                        )
                        .animation(.easeInOut(duration: 0.1), value: isSelected)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: barHeight + 8, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let totalBars = chronological.count
                        guard totalBars > 0 else { return }

                        let step = fixedBarWidth + barSpacing
                        let x = value.location.x - leadingOffset

                        let chronoIndex = min(
                            max(Int(x / step), 0),
                            totalBars - 1
                        )

                        let newIndex = recordsIndex(from: chronoIndex)
                        if newIndex != selectedIndex {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                selectedIndex = newIndex
                            }
                        }
                    }
            )
        }
        .frame(height: barHeight + 8)
        .sensoryFeedback(.selection, trigger: selectedIndex)
    }
}


// MARK: - Safe Array Index Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
