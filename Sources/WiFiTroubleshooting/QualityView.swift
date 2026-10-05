import SwiftUI
import WiFiCore

struct QualityView: View {
    @EnvironmentObject var store: AppStore
    @State private var eventFilter = "ทั้งหมด"
    private var summary: SignalSummary { SignalSummary(samples: store.history, threshold: store.weakThreshold) }
    private var visibleEvents: [SignalEvent] { store.events.reversed().filter { eventFilter == "ทั้งหมด" || $0.kind == eventFilter } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    LiveStatus(); Spacer()
                    Button("ส่งออกประวัติ CSV") { store.exportHistory() }.disabled(store.history.isEmpty)
                    Button("ส่งออกเหตุการณ์ CSV") { store.exportEvents() }.disabled(store.events.isEmpty)
                }
                HStack(spacing: 12) {
                    Metric(title: "RSSI เฉลี่ย", value: summary.mean.map { String(format: "%.1f", $0) } ?? "—", unit: "dBm", caption: "ค่าเฉลี่ยเลขคณิตของ dBm")
                    Metric(title: "ต่ำสุด / สูงสุด", value: summary.minimum.map(String.init) ?? "—", unit: summary.maximum.map { "/ \($0)" } ?? "", caption: "dBm ในประวัติปัจจุบัน", color: StudioTheme.purple)
                    Metric(title: "ความผันผวน RSSI", value: summary.deviation.map { String(format: "%.1f", $0) } ?? "—", unit: "dB", caption: "ส่วนเบี่ยงเบนมาตรฐาน", color: .orange)
                    Metric(title: "ตัวอย่างต่ำกว่าเกณฑ์", value: summary.belowPercent.map { String(format: "%.0f", $0) } ?? "—", unit: "%", caption: "ต่ำกว่า \(store.weakThreshold) dBm", color: StudioTheme.green)
                }
                Text("สรุป \(summary.valid) ตัวอย่างที่มี RSSI จากทั้งหมด \(summary.total) ตัวอย่างล่าสุด (สูงสุด 300) · สัดส่วนตามจำนวนตัวอย่าง ไม่ใช่เปอร์เซ็นต์ uptime หรือ packet loss").font(.caption).foregroundStyle(.secondary)
                Panel(title: "ตั้งค่าการติดตามและแจ้งเหตุการณ์") {
                    HStack {
                        Picker("อ่านลิงก์", selection: $store.sampleInterval) { ForEach([1.0, 2, 5], id: \.self) { Text("\(Int($0)) วินาที").tag($0) } }
                        Picker("สแกน AP", selection: $store.scanInterval) { ForEach([15.0, 30, 60], id: \.self) { Text("\(Int($0)) วินาที").tag($0) } }
                    }
                    HStack {
                        Toggle("ติดตาม Live", isOn: $store.monitoring)
                        Toggle("สแกนอัตโนมัติ", isOn: $store.autoScan)
                        Toggle("บันทึกเหตุการณ์", isOn: $store.observeEvents)
                    }.toggleStyle(.switch)
                    Stepper("เกณฑ์สัญญาณอ่อน: \(store.weakThreshold) dBm", value: $store.weakThreshold, in: -90 ... -50)
                    Text("แจ้งเตือนในแอปเมื่ออ่อนติดต่อกัน 3 ตัวอย่าง และแจ้งฟื้นตัวเมื่อสูงกว่าเกณฑ์อย่างน้อย 3 dB การเปลี่ยน AP ตรวจได้เมื่อ macOS เปิดเผย BSSID เท่านั้น; เปลี่ยน adapter/หยุด Live/เปลี่ยนเกณฑ์จะเริ่มนับใหม่").font(.caption).foregroundStyle(.secondary)
                }
                Panel(title: "บันทึกเหตุการณ์") {
                    HStack {
                        Picker("แสดง", selection: $eventFilter) {
                            Text("ทั้งหมด").tag("ทั้งหมด")
                            ForEach(["สัญญาณอ่อน", "สัญญาณฟื้นตัว", "เปลี่ยน AP", "เปลี่ยนช่อง", "ไม่มีค่าสัญญาณ", "กลับมาอ่านค่าได้"], id: \.self) { Text($0).tag($0) }
                        }.frame(width: 300)
                        Spacer(); Text("\(visibleEvents.count) รายการ").foregroundStyle(.secondary)
                    }
                    if visibleEvents.isEmpty {
                        ContentUnavailableView("ยังไม่มีเหตุการณ์ที่ตรงเงื่อนไข", systemImage: "checkmark.shield", description: Text("ติดตามต่อเพื่อบันทึกการเปลี่ยนแปลงที่ตรวจพบ")).frame(height: 120)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(visibleEvents) { event in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: event.kind == "สัญญาณอ่อน" ? "exclamationmark.triangle.fill" : "waveform.path.ecg").foregroundStyle(event.kind == "สัญญาณอ่อน" ? .orange : StudioTheme.cyan)
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack { Text(event.kind).fontWeight(.semibold); Spacer(); Text("\(event.interface) · \(event.timestamp.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundStyle(.secondary) }
                                        Text(event.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                                    }
                                }.padding(12).background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    Text("เก็บ 200 เหตุการณ์ล่าสุดระหว่างเปิดแอป รวมทุก adapter ที่เลือกในรอบนี้ ส่งออก CSV ก่อนปิดแอปหากต้องการเก็บไว้ เหตุการณ์ไม่ใช่การยืนยันสาเหตุปัญหาเครือข่าย").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(28)
        }
    }
}
struct RecentSignalEvent: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        if let event = store.events.last {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("เหตุการณ์ล่าสุด · \(event.kind)").font(.callout.bold())
                    Text("\(event.timestamp.formatted(date: .omitted, time: .standard)) · \(event.detail)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(14).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
