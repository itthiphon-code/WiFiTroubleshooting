import SwiftUI
import WiFiCore
import AppKit

struct SurveyView: View {
    @EnvironmentObject var store: AppStore
    @State private var show3D = false
    @State private var clearPrompt = false
    @State private var replacePlan = false
    @State private var openPrompt = false
    @State private var selectedPoint: UUID?
    var plan: NSImage? { store.survey.floorPlan.flatMap(NSImage.init(data:)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    TextField("ชื่อโครงการ", text: $store.survey.name).textFieldStyle(.roundedBorder).frame(maxWidth: 250).onSubmit { store.saveSurvey() }
                    Spacer()
                    Button("เปิด…") { if store.survey.points.isEmpty { store.openSurvey() } else { openPrompt = true } }
                    Button("แผนผัง…") { if store.survey.points.isEmpty { store.importPlan() } else { replacePlan = true } }
                    Menu("ส่งออก") { Button("โครงการ JSON พร้อมแผนผัง") { store.exportSurvey() }; Button("จุดวัด CSV") { store.exportCSV(surveyMode: true) } }
                }
                HStack {
                    TextField("ชื่อจุดวัด (ไม่จำเป็น)", text: $store.pointLabel).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                    Text(store.capturing ? "กำลังอ่านสัญญาณ…" : "คลิกบนแผนผังเพื่อวัด Wi‑Fi ที่กำลังเชื่อมต่อ").font(.callout).foregroundStyle(.secondary)
                    Spacer(); Text("\(store.survey.points.count) จุด").font(.headline)
                }
                Picker("มุมมอง", selection: $show3D) { Text("2D · ปักจุดวัด").tag(false); Text("3D · หมุนสำรวจ").tag(true) }.pickerStyle(.segmented).frame(width: 310)
                if show3D {
                    SignalStage(survey: true).frame(height: 460)
                } else {
                GeometryReader { geometry in
                    let available = geometry.size
                    let size = fittedSize(image: plan?.size, available: available)
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor))
                        if let image = plan { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit) }
                        else {
                            Canvas { context, dimensions in
                                var path = Path()
                                for x in stride(from: 0.0, to: dimensions.width, by: 32) { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: dimensions.height)) }
                                for y in stride(from: 0.0, to: dimensions.height, by: 32) { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: dimensions.width, y: y)) }
                                context.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 1)
                            }
                            if store.survey.points.isEmpty { VStack(spacing: 10) { Image(systemName: "map").font(.largeTitle); Text("นำเข้าแผนผัง PNG/JPEG หรือใช้พื้นที่ตารางนี้"); Text("ตำแหน่งเป็นพิกัดสัมพัทธ์ ไม่ใช่ GPS").font(.caption) }.foregroundStyle(.secondary).allowsHitTesting(false) }
                        }
                        ForEach(store.survey.points) { point in
                            VStack(spacing: 2) {
                                Text(point.sample.rssi.map(String.init) ?? "—").font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black).frame(width: 36, height: 36).background(signalColor(point.sample.rssi), in: Circle()).overlay(Circle().stroke(.white, lineWidth: 2))
                                Text(point.label).font(.system(size: 9)).padding(3).background(.regularMaterial, in: Capsule())
                            }.position(x: point.x * size.width, y: point.y * size.height).allowsHitTesting(false)
                        }
                    }.frame(width: size.width, height: size.height).contentShape(Rectangle())
                        .onTapGesture { location in store.capture(x: location.x / size.width, y: location.y / size.height) }
                        .frame(width: available.width, height: available.height)
                }.frame(height: 390).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                let summary = SignalSummary(samples: store.survey.points.map(\.sample), threshold: store.weakThreshold)
                HStack {
                    Text("RSSI เฉลี่ย: " + (summary.mean.map { String(format: "%.1f dBm", $0) } ?? "—"))
                    Spacer()
                    Text("ต่ำกว่า \(store.weakThreshold) dBm: \(summary.belowThreshold)/\(summary.valid) จุดที่มีค่า")
                }.font(.callout).padding(12).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Label("≥ −67 dBm ดี", systemImage: "circle.fill").foregroundStyle(.mint)
                    Label("−68 ถึง −75 พอใช้", systemImage: "circle.fill").foregroundStyle(.orange)
                    Label("< −75 อ่อน", systemImage: "circle.fill").foregroundStyle(.red)
                    Spacer(); Text(store.surveyStatus).foregroundStyle(.secondary)
                }.font(.caption)
                Text("สีแสดงค่าที่วัดจริงแต่ละจุด ไม่ประมาณสัญญาณระหว่างจุด ตรวจ BSSID เพื่อสังเกตการ roaming; แต่ละจุดเป็นหนึ่งตัวอย่าง ณ เวลาที่คลิก").font(.caption).foregroundStyle(.secondary)
                Table(store.survey.points.reversed(), selection: $selectedPoint) {
                    TableColumn("จุด", value: \.label)
                    TableColumn("เวลา") { p in Text(p.sample.timestamp.formatted(date: .omitted, time: .standard)) }
                    TableColumn("SSID") { p in Text(p.sample.ssid ?? "ไม่เปิดเผย") }
                    TableColumn("BSSID") { p in Text(p.sample.bssid ?? "ไม่เปิดเผย").font(.caption.monospaced()) }
                    TableColumn("ย่าน") { p in Text(p.sample.band.rawValue) }
                    TableColumn("RSSI") { p in Text(p.sample.rssi.map { "\($0) dBm" } ?? "—").foregroundStyle(signalColor(p.sample.rssi)) }
                }.frame(height: 190)
                HStack {
                    Button("ลบจุดที่เลือก", role: .destructive) { store.survey.points.removeAll { $0.id == selectedPoint }; store.saveSurvey() }.disabled(selectedPoint == nil)
                    Button("เริ่มการสำรวจใหม่", role: .destructive) { clearPrompt = true }
                    Spacer(); Button("บันทึก") { store.saveSurvey() }
                }
            }.padding(28)
        }
        .onChange(of: store.survey.name) { store.saveSurvey() }
        .alert("เริ่มการสำรวจใหม่?", isPresented: $clearPrompt) { Button("ยกเลิก", role: .cancel) {}; Button("เริ่มใหม่", role: .destructive) { store.survey = Survey(); store.saveSurvey() } } message: { Text("ส่งออก JSON หากต้องการเก็บโครงการเดิมก่อนล้างข้อมูล") }
        .alert("เปลี่ยนแผนผัง?", isPresented: $replacePlan) { Button("ยกเลิก", role: .cancel) {}; Button("เปลี่ยนแผนผัง") { store.importPlan() } } message: { Text("พิกัดจุดเดิมจะคงเดิม ตรวจให้แน่ใจว่าภาพใหม่ใช้ขอบเขตพื้นที่เดียวกัน") }
        .alert("เปิดโครงการอื่น?", isPresented: $openPrompt) { Button("ยกเลิก", role: .cancel) {}; Button("เปิด…") { store.openSurvey() } } message: { Text("โครงการที่เปิดจะมาแทนโครงการปัจจุบัน ส่งออก JSON เพื่อเก็บโครงการนี้ไว้ก่อน") }
    }
    func fittedSize(image: NSSize?, available: CGSize) -> CGSize {
        guard let image, image.width > 0, image.height > 0 else { return available }
        let scale = min(available.width / image.width, available.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
}
