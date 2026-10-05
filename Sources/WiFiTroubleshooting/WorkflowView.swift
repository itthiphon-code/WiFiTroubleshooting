import SwiftUI

struct WorkflowView: View {
    @EnvironmentObject var store: AppStore
    var navigate: (Screen) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("เริ่มจากงานที่ต้องการทำ").font(.title2.bold())
                Text("เครื่องมือแต่ละแบบใช้ข้อมูล Wi‑Fi จริงร่วมกัน เลือกดูกราฟเชิงเส้นหรือ 3D ได้ระหว่างทำงาน").foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    card("ตรวจปัญหาด่วน", icon: "stethoscope", color: StudioTheme.cyan,
                         detail: "ตรวจสัญญาณ → gateway → DNS → HTTPS พร้อมผลตรวจและแนวทางแก้ไข", action: "เริ่มตรวจการเชื่อมต่อ") { store.diagnose(); navigate(.diagnostics) }
                    card("เฝ้าดูและบันทึก", icon: "record.circle", color: StudioTheme.green,
                         detail: "เลือกช่วงเวลา ตั้งชื่อรอบงาน และบันทึก RSSI/Noise กับเหตุการณ์เพื่อเปิดดูภายหลัง", action: "ตั้งค่ารอบบันทึก") { navigate(.sessions) }
                    card("สำรวจพื้นที่", icon: "map", color: StudioTheme.purple,
                         detail: "นำเข้าแผนผัง → ปักจุดใน 2D → ตรวจสัญญาณใน 3D → ส่งออกโครงการ", action: "เปิดเครื่องมือสำรวจ") { navigate(.survey) }
                    card("เปรียบเทียบก่อน–หลัง", icon: "arrow.left.arrow.right", color: .orange,
                         detail: "เลือกรอบงานสองรอบ เปรียบเทียบกราฟตามเวลาที่ผ่านไป ค่าเฉลี่ย และตัวอย่างต่ำกว่าเกณฑ์", action: "เปิดคลังรอบงาน") { navigate(.sessions) }
                }
                Panel(title: "เตรียมพร้อมก่อนวัด") {
                    LabeledContent("Wi‑Fi adapter", value: store.link?.interface ?? "รอข้อมูล")
                    LabeledContent("ย่านที่อุปกรณ์รายงาน", value: store.link?.supportedBands.map(\.rawValue).joined(separator: ", ") ?? "รอข้อมูล")
                    LabeledContent("สิทธิ์ตำแหน่ง", value: store.permission)
                    HStack { Button("ตรวจอุปกรณ์และสิทธิ์") { navigate(.capabilities) }; Button("เปิดภาพรวมสด") { navigate(.overview) }; Button("ค้นหาเครือข่าย") { navigate(.networks) } }
                }
                Text("การตรวจด่วนติดต่อ www.apple.com ผ่าน default route ของระบบซึ่งอาจเป็น VPN/Ethernet; การสำรวจพื้นที่ควรวัดตำแหน่งเดิมและทิศทางเครื่องเดียวกันเมื่อเปรียบเทียบ").font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }
    }
    private func card(_ title: String, icon: String, color: Color, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon).font(.system(size: 27)).foregroundStyle(color)
            Text(title).font(.title3.bold())
            Text(detail).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
            Button(action, action: perform).buttonStyle(.bordered)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [color.opacity(0.12), StudioTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.25)))
    }
}
struct RecordingBadge: View {
    @ObservedObject var archive: SessionStore
    var body: some View {
        if let recording = archive.recording {
            Label("REC · \(recording.samples.count) ตัวอย่าง", systemImage: "record.circle.fill").font(.caption).foregroundStyle(.red)
        }
    }
}
