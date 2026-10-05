import SwiftUI
import Charts
import WiFiCore

struct SessionsView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var archive: SessionStore
    @State private var selected: UUID?
    @State private var beforeID: UUID?
    @State private var afterID: UUID?
    @State private var tab = "บันทึก / ย้อนหลัง"
    private var selectedSession: MeasurementSession? { archive.saved.first { $0.id == selected } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Picker("โหมด", selection: $tab) { Text("บันทึก / ย้อนหลัง").tag("บันทึก / ย้อนหลัง"); Text("เปรียบเทียบก่อน–หลัง").tag("เปรียบเทียบก่อน–หลัง") }.pickerStyle(.segmented).frame(width: 380)
                    Spacer(); Button("นำเข้า JSON") { archive.importSession() }.disabled(archive.busy)
                }
                if let error = archive.error {
                    HStack { Label(error, systemImage: "exclamationmark.triangle"); Spacer(); Button("ปิด") { archive.error = nil } }.padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                if tab == "บันทึก / ย้อนหลัง" {
                    recordingPanel
                    Panel(title: "คลังรอบงาน · \(archive.saved.count) รายการ") {
                        if archive.saved.isEmpty { Text("ยังไม่มีรอบงาน บันทึกช่วงเวลาใหม่ หรือเก็บ snapshot ของประวัติสด").foregroundStyle(.secondary) }
                        else {
                            Picker("เลือกรอบงาน", selection: $selected) {
                                Text("เลือกรอบงาน…").tag(nil as UUID?)
                                ForEach(archive.saved) { session in Text(label(session)).tag(Optional(session.id)) }
                            }
                        }
                        if let session = selectedSession {
                            sessionDetail(session)
                        }
                    }
                } else {
                    comparisonPanel
                }
            }.padding(28)
        }.onChange(of: archive.saved.map(\.id)) { if selected == nil { selected = archive.saved.first?.id } }
    }
    private var recordingPanel: some View {
        Panel(title: "บันทึกรอบวัด") {
            if let session = archive.recording {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        Label(session.name, systemImage: "record.circle.fill").foregroundStyle(.red)
                        Spacer(); Text("\(Int(max(0, context.date.timeIntervalSince(session.startedAt)))) วินาที · \(session.samples.count) ตัวอย่าง").monospacedDigit()
                        Button("หยุดและบันทึก") { Task { await archive.stop() } }.buttonStyle(.borderedProminent)
                    }
                }
                if !store.monitoring { Text("Live หยุดอยู่ รอบงานยังนับเวลาต่อ แต่ไม่มีตัวอย่างเพิ่มจนกว่าจะเปิด Live").foregroundStyle(.orange) }
                Text("รอบนี้เริ่มด้วยเกณฑ์ \(session.threshold) dBm และรอบอ่าน \(Int(session.sampleInterval)) วินาที; timestamp ของแต่ละตัวอย่างเป็นเวลาจริง").font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("ชื่อรอบงาน เช่น ก่อนย้าย AP / ห้อง 201", text: $archive.name).textFieldStyle(.roundedBorder)
                TextField("บันทึกย่อ เช่น ตำแหน่ง ทิศทางเครื่อง และสิ่งที่เปลี่ยน", text: $archive.note).textFieldStyle(.roundedBorder)
                HStack {
                    Picker("ระยะเวลาสูงสุด", selection: $archive.duration) {
                        Text("30 วินาที").tag(30.0); Text("1 นาที").tag(60.0); Text("5 นาที").tag(300.0); Text("15 นาที").tag(900.0); Text("1 ชั่วโมง").tag(3_600.0)
                    }.frame(width: 260)
                    Button("เริ่มบันทึก") {
                        store.monitoring = true
                        Task { await archive.start(threshold: store.weakThreshold, interval: store.sampleInterval) }
                    }.buttonStyle(.borderedProminent).disabled(archive.busy || store.link == nil)
                    Button("เก็บ snapshot ประวัติสด") {
                        Task { await archive.snapshot(history: store.history, events: store.events, networks: store.networks, threshold: store.weakThreshold, interval: store.sampleInterval) }
                    }.disabled(archive.busy || store.history.isEmpty)
                    if archive.busy { ProgressView().controlSize(.small) }
                }
            }
            Text(archive.status).font(.caption).foregroundStyle(StudioTheme.cyan)
            Text("บันทึกในเครื่องสูงสุด 3,600 ตัวอย่างต่อรอบ พร้อม AP snapshot ล่าสุดและเหตุการณ์ที่เกิดระหว่างรอบ บันทึกเป็นระยะ ~10 วินาทีและเมื่อหยุด/ปิดแอปตามปกติ; หาก force quit อาจขาดข้อมูลหลัง checkpoint ล่าสุด").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func sessionDetail(_ session: MeasurementSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(session.note.isEmpty ? "ไม่มีบันทึกย่อ" : session.note).foregroundStyle(.secondary).textSelection(.enabled)
            Text("\(session.startedAt.formatted()) · \(session.endedAt == nil ? "checkpoint / รอบงานไม่สิ้นสุดตามปกติ" : "บันทึกเสร็จแล้ว")").font(.caption)
            Text("\(session.samples.count) ตัวอย่าง · \(session.networks.count) AP ใน snapshot · \(session.events.count) เหตุการณ์").font(.callout)
            SampleSignalChart(samples: session.samples, showNoise: false).frame(height: 340)
            HStack { Button("ส่งออก JSON ครบชุด") { archive.export(session) }; Button("ส่งออกค่าที่วัด CSV") { archive.export(session, csv: true) } }
            if archive.unsavedIDs.contains(session.id) {
                Button("ลองบันทึกลงคลังอีกครั้ง") { Task { await archive.retrySave(session) } }.disabled(archive.busy)
                Text("รอบนี้ยังไม่ถูกบันทึกลงดิสก์ ส่งออก JSON หรือลองบันทึกใหม่ก่อนปิดแอป").foregroundStyle(.orange).font(.caption)
            }
            if !session.events.isEmpty {
                DisclosureGroup("เหตุการณ์ 20 รายการล่าสุด") {
                    ForEach(session.events.suffix(20).reversed()) { event in
                        Text("\(event.timestamp.formatted(date: .omitted, time: .standard)) · \(event.kind) · \(event.detail)").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
    private var comparisonPanel: some View {
        Panel(title: "เปรียบเทียบสองรอบงาน") {
            HStack {
                Picker("ก่อน", selection: $beforeID) { Text("เลือก…").tag(nil as UUID?); ForEach(archive.saved) { Text(label($0)).tag(Optional($0.id)) } }
                Picker("หลัง", selection: $afterID) { Text("เลือก…").tag(nil as UUID?); ForEach(archive.saved) { Text(label($0)).tag(Optional($0.id)) } }
            }
            if let a = archive.saved.first(where: { $0.id == beforeID }), let b = archive.saved.first(where: { $0.id == afterID }), a.id != b.id {
                let comparison = SessionComparison(before: a, after: b, threshold: store.weakThreshold)
                Button("ส่งออกรายงานเปรียบเทียบ TXT") { archive.exportComparison(before: a, after: b, threshold: store.weakThreshold) }
                HStack(spacing: 16) {
                    Metric(title: "ก่อน · RSSI เฉลี่ย", value: number(comparison.before.mean), unit: "dBm", caption: "\(comparison.before.valid) ตัวอย่างที่มีค่า")
                    Metric(title: "หลัง · RSSI เฉลี่ย", value: number(comparison.after.mean), unit: "dBm", caption: "\(comparison.after.valid) ตัวอย่างที่มีค่า", color: StudioTheme.purple)
                    Metric(title: "หลัง − ก่อน", value: number(comparison.delta), unit: "dB", caption: "บวก = ค่า RSSI เฉลี่ยสูงขึ้น", color: .orange)
                }
                LabeledContent("ตัวอย่างต่ำกว่า \(store.weakThreshold) dBm", value: "ก่อน \(number(comparison.before.belowPercent))% → หลัง \(number(comparison.after.belowPercent))%")
                Text("ใช้เกณฑ์เดียวกันทั้งสองรอบ: \(store.weakThreshold) dBm (ปรับได้ในหน้าคุณภาพ) เป็นสัดส่วนตัวอย่าง ไม่ใช่ uptime").font(.caption).foregroundStyle(.secondary)
                Chart {
                    ForEach(a.samples) { sample in
                        if let rssi = sample.rssi { LineMark(x: .value("วินาที", sample.timestamp.timeIntervalSince(a.startedAt)), y: .value("dBm", rssi), series: .value("รอบ", "ก่อน")).foregroundStyle(by: .value("รอบ", "ก่อน")) }
                    }
                    ForEach(b.samples) { sample in
                        if let rssi = sample.rssi { LineMark(x: .value("วินาที", sample.timestamp.timeIntervalSince(b.startedAt)), y: .value("dBm", rssi), series: .value("รอบ", "หลัง")).foregroundStyle(by: .value("รอบ", "หลัง")) }
                    }
                }.chartYScale(domain: -130 ... 0).chartForegroundStyleScale(["ก่อน": StudioTheme.cyan, "หลัง": StudioTheme.purple]).chartXAxisLabel("วินาทีหลังเริ่มแต่ละรอบ").frame(height: 260)
                Text("ก่อน: \(context(a))\nหลัง: \(context(b))").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                if comparison.before.valid < 10 || comparison.after.valid < 10 { Text("อย่างน้อยหนึ่งรอบมีตัวอย่างที่ใช้ได้ต่ำกว่า 10 ค่า ควรวัดเพิ่มก่อนสรุป").foregroundStyle(.orange).font(.caption) }
                Text("เปรียบเทียบภายใต้ตำแหน่ง ทิศทางเครื่อง adapter/AP และสภาพใช้งานใกล้เคียงกัน ค่าเฉลี่ยที่ต่างกันไม่ยืนยันสาเหตุหรือความเร็วอินเทอร์เน็ต").font(.caption).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView("เลือกสองรอบงานที่ต่างกัน", systemImage: "arrow.left.arrow.right", description: Text("บันทึกก่อนและหลังการปรับปรุง หรือใช้ไฟล์ JSON ที่นำเข้า")).frame(height: 200)
            }
        }
    }
    private func number(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "—" }
    private func label(_ session: MeasurementSession) -> String { "\(session.name) · \(session.startedAt.formatted(date: .abbreviated, time: .shortened))" }
    private func context(_ session: MeasurementSession) -> String {
        let interfaces = Set(session.samples.map(\.interface)).sorted().joined(separator: ", ")
        let bands = Set(session.samples.map(\.band.rawValue)).sorted().joined(separator: ", ")
        let aps = Set(session.samples.compactMap(\.bssid)).count
        let links = Set(session.samples.map { sample in
            "SSID: \(sample.ssid ?? "ไม่เปิดเผย") · \(sample.band.rawValue) · CH \(sample.channel.map(String.init) ?? "—") · \(sample.channel.flatMap { sample.band.frequency(channel: $0) }.map { "\($0) MHz" } ?? "ไม่ทราบ MHz")"
        }).sorted().joined(separator: "\n")
        return "\(interfaces) · \(bands) · BSSID ที่ทราบ \(aps) ตัว · รอบอ่านตั้งต้น \(Int(session.sampleInterval))s\n\(links)"
    }
}
