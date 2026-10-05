import SwiftUI
import WiFiCore

enum StudioTheme {
    static let background = Color(red: 0.025, green: 0.045, blue: 0.09)
    static let surface = Color(red: 0.055, green: 0.085, blue: 0.15)
    static let cyan = Color(red: 0.12, green: 0.85, blue: 1)
    static let purple = Color(red: 0.65, green: 0.45, blue: 1)
    static let green = Color(red: 0.20, green: 0.94, blue: 0.67)
    static func band(_ band: Band) -> Color {
        switch band { case .two: return cyan; case .five: return purple; case .six: return .orange; case .unknown: return .gray }
    }
}
struct LiveStatus: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = SampleFreshness.state(timestamp: store.link?.timestamp, now: context.date, monitoring: store.monitoring, interval: store.sampleInterval)
            HStack(spacing: 7) {
                Circle().fill(state == .live ? StudioTheme.green : .orange).frame(width: 7, height: 7)
                    .opacity(state == .live && !reduceMotion ? (Int(context.date.timeIntervalSince1970) % 2 == 0 ? 1 : 0.4) : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: context.date)
                Text(state.rawValue).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                if let timestamp = store.link?.timestamp {
                    Text("\(max(0, Int(context.date.timeIntervalSince(timestamp))))s").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 11).padding(.vertical, 7).background(.white.opacity(0.05), in: Capsule())
                .accessibilityLabel("สถานะข้อมูล \(state.rawValue)")
        }
    }
}
struct BandLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach([Band.two, .five, .six], id: \.self) { band in
                HStack(spacing: 5) { Circle().fill(StudioTheme.band(band)).frame(width: 7, height: 7); Text(band.rawValue).font(.system(size: 10, weight: .semibold, design: .monospaced)) }
            }
        }
    }
}
