import SwiftUI
import Charts
import WiFiCore

/// The label always belongs to the selected historical sample, never to today's link.
struct SampleSignalChart: View {
    var samples: [LinkSample]
    var indexed = false
    var showNoise = true
    @State private var selectedX: Double?

    private struct Entry: Identifiable {
        var sample: LinkSample
        var x: Double
        var segment: Int
        var id: UUID { sample.id }
    }
    private var entries: [Entry] {
        var segment = 0
        return samples.enumerated().map { index, sample in
            if index > 0 {
                let previous = samples[index - 1]
                if previous.ssid != sample.ssid || previous.bssid != sample.bssid || previous.band != sample.band || previous.channel != sample.channel || previous.interface != sample.interface || previous.rssi == nil || sample.rssi == nil || previous.noise == nil || sample.noise == nil { segment += 1 }
            }
            return Entry(sample: sample, x: indexed ? Double(index + 1) : sample.timestamp.timeIntervalSince1970, segment: segment)
        }
    }
    private func selected(_ values: [Entry]) -> Entry? {
        guard let selectedX else { return values.last }
        return values.min { abs($0.x - selectedX) < abs($1.x - selectedX) }
    }
    var body: some View {
        let values = entries
        let focused = selected(values)
        let start = values.first?.x ?? 0
        let end = max(start + 1, values.last?.x ?? 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                ForEach([Band.two, .five, .six, .unknown], id: \.self) { band in
                    Label(band.rawValue, systemImage: "circle.fill").foregroundStyle(StudioTheme.band(band))
                }
                Spacer()
                Text(showNoise ? "RSSI ━   Noise ┄" : "RSSI ━")
            }.font(.caption)
            if let focused {
                SignalSampleLabel(sample: focused.sample)
                HStack {
                    Text(indexed ? "จุดที่ \(Int(focused.x)) · \(focused.sample.timestamp.formatted(date: .omitted, time: .standard))" : focused.sample.timestamp.formatted(date: .omitted, time: .standard))
                    Text("RSSI \(focused.sample.rssi.map { "\($0)" } ?? "—") dBm")
                    if showNoise { Text("Noise \(focused.sample.noise.map { "\($0)" } ?? "—") dBm") }
                    Spacer()
                    if selectedX != nil { Button("กลับค่าล่าสุด") { selectedX = nil }.buttonStyle(.plain).foregroundStyle(StudioTheme.cyan) }
                }.font(.caption).monospacedDigit()
            }
            Chart {
                ForEach(values) { entry in
                    if let rssi = entry.sample.rssi {
                        LineMark(x: .value("X", entry.x), y: .value("dBm", rssi), series: .value("ช่วง", "RSSI-\(entry.segment)"))
                            .foregroundStyle(StudioTheme.band(entry.sample.band)).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.linear)
                        PointMark(x: .value("X", entry.x), y: .value("dBm", rssi)).foregroundStyle(StudioTheme.band(entry.sample.band)).symbolSize(12)
                    }
                    if showNoise, let noise = entry.sample.noise {
                        LineMark(x: .value("X", entry.x), y: .value("dBm", noise), series: .value("ช่วง", "Noise-\(entry.segment)"))
                            .foregroundStyle(StudioTheme.band(entry.sample.band).opacity(0.65)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
                if let focused, selectedX != nil {
                    RuleMark(x: .value("เลือก", focused.x)).foregroundStyle(.white.opacity(0.6)).lineStyle(StrokeStyle(dash: [3, 3]))
                    if let rssi = focused.sample.rssi {
                        PointMark(x: .value("เลือก", focused.x), y: .value("dBm", rssi)).foregroundStyle(StudioTheme.band(focused.sample.band)).symbolSize(85)
                    }
                }
            }
            .chartXScale(domain: start...end, range: .plotDimension(padding: 12))
            .chartXSelection(value: $selectedX)
            .chartYScale(domain: -130 ... 0)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(); AxisTick()
                AxisValueLabel { if let x = value.as(Double.self) {
                    if indexed { Text("\(Int(x))") }
                    else { Text(Date(timeIntervalSince1970: x), format: .dateTime.hour().minute().second()) }
                } }
            } }
            .chartXAxisLabel(indexed ? "ลำดับจุดวัด" : "เวลาที่อ่านค่า")
            .chartYAxisLabel("dBm")
            .frame(minHeight: 160)
            Text("คลิกหรือลากบนกราฟเพื่อดู SSID / Channel / MHz ของตัวอย่างนั้น · สีแทนย่านความถี่").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SignalSampleLabel: View {
    var sample: LinkSample
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("SSID: \(sample.ssid.flatMap { $0.isEmpty ? nil : $0 } ?? "ไม่เปิดเผย / ไม่ทราบ")").font(.headline).textSelection(.enabled)
            Text("\(sample.band.rawValue) · CH \(sample.channel.map(String.init) ?? "—") · \(sample.channel.flatMap { sample.band.frequency(channel: $0) }.map { "\($0) MHz" } ?? "ความถี่ไม่ทราบ")")
                .font(.callout.monospaced()).foregroundStyle(StudioTheme.band(sample.band))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
