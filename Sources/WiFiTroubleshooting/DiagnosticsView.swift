import SwiftUI
import WiFiCore

struct DiagnosticsView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Panel(title: "ตรวจการเชื่อมต่อทีละชั้น") {
                    Text("ตรวจ default route → ping gateway 4 ครั้ง → DNS → HTTPS ไปยัง www.apple.com ใช้เส้นทางเริ่มต้นของ macOS ซึ่งอาจเป็น VPN หรือ Ethernet จึงไม่ใช่การทดสอบเฉพาะ Wi‑Fi adapter ที่เลือก")
                    HStack { Button(store.diagnosing ? "กำลังตรวจสอบ…" : "เริ่มตรวจสอบ") { store.diagnose() }.buttonStyle(.borderedProminent).disabled(store.diagnosing); if store.diagnosing { ProgressView().controlSize(.small) }; Spacer(); Button("ส่งออกรายงาน") { store.exportReport() }.disabled(store.diagnosticResults.isEmpty) }
                }
                ForEach(store.diagnosticResults) { result in
                    Panel(title: result.name) {
                        Text(result.status).fontWeight(.semibold)
                        DisclosureGroup("รายละเอียดผลตรวจ") { Text(result.detail.isEmpty ? "ไม่มีข้อมูลตอบกลับ" : result.detail).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8) }
                    }
                }
                Panel(title: "แนวทางแก้ไขตามอาการ") {
                    ForEach(Signal.advice(rssi: store.link?.rssi, snr: store.link?.snr), id: \.self) { Text("• " + $0) }
                    Text("• ไม่มี default route: ตรวจ DHCP และสถานะการเชื่อมต่อใน System Settings")
                    Text("• Gateway ไม่ตอบ ping: อาจเกิด packet loss หรืออุปกรณ์บล็อก ICMP ให้ตรวจ HTTPS ประกอบ")
                    Text("• DNS ไม่ตอบ: ตรวจ DNS ที่ DHCP แจกและ VPN; คำตอบอาจมาจาก cache ของระบบ")
                    Text("• HTTPS ล้มเหลว: ตรวจ captive portal, proxy, VPN, วันเวลา และการเชื่อมต่อ WAN")
                    Text("• HTTP response ไม่ยืนยันว่าอินเทอร์เน็ตทุกบริการใช้งานได้; เปิดรายละเอียดเพื่อตรวจ status code")
                    HStack { Button("เปิด Wi‑Fi Settings") { store.settings() }; Button("เปิด Wireless Diagnostics") { openWirelessDiagnostics() } }
                }
            }.padding(28)
        }
    }
    private func openWirelessDiagnostics() {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/Applications/Wireless Diagnostics.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error { Task { @MainActor in store.error = error.localizedDescription } }
        }
    }
}
struct CapabilitiesView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Panel(title: "สิทธิ์การอ่านเครือข่าย") {
                    LabeledContent("Location Services", value: store.permission)
                    Text("macOS ต้องใช้สิทธิ์ตำแหน่งเพื่อเปิดเผย SSID, BSSID และรหัสประเทศ แอปไม่บันทึก GPS; จุดสำรวจเกิดจากการคลิกบนแผนผังเท่านั้น")
                    HStack { Button("ขอสิทธิ์ตำแหน่ง") { store.requestLocation() }; Button("เปิด Location Settings") { store.settings(true) } }
                }
                Panel(title: "ความสามารถของ adapter ที่เลือก") {
                    LabeledContent("Interface", value: store.link?.interface ?? "ไม่พบ")
                    LabeledContent("ย่านที่ CoreWLAN รายงาน", value: store.link?.supportedBands.map(\.rawValue).joined(separator: ", ") ?? "รอข้อมูล")
                    LabeledContent("โหมดลิงก์ปัจจุบัน", value: store.link?.phy ?? "ไม่ทราบ")
                    Text("การพบ 6 GHz ขึ้นกับชิป Wi‑Fi, รุ่นเครื่อง, ประเทศ, AP, ไดรเวอร์ และ macOS หากเครื่องไม่รองรับ ซอฟต์แวร์ไม่สามารถเพิ่มย่านนี้ให้ฮาร์ดแวร์ได้").foregroundStyle(.secondary)
                }
                Panel(title: "มาตรฐานและขอบเขตข้อมูล") {
                    Text("อ่านมาตรฐานที่ CoreWLAN รายงาน: 802.11a/b/g/n/ac/ax/be (Wi‑Fi 4/5/6/6E/7) พร้อมแยก 2.4, 5 และ 6 GHz จาก channel band โดยตรง")
                    Text("ความกว้างช่องที่ public API เปิดเผย: 20/40/80/160 MHz ค่าที่ไม่รู้จักจะแสดง —; ไม่อนุมาน 320 MHz, MLO, puncturing หรือ Wi‑Fi 7 จากชื่อเครือข่าย")
                    Text("Wi‑Fi 6E ใช้ 802.11ax บน 6 GHz; การพบ ax เพียงอย่างเดียวไม่ยืนยันว่าเป็น 6E การสแกนไม่รับประกันว่าจะเห็นทุก AP หรือเครือข่ายซ่อนในพื้นที่")
                    Text("แอปนี้ไม่ใช่ spectrum analyzer และไม่วัดสัญญาณรบกวนที่ไม่ใช่ Wi‑Fi โดยตรง การสแกนอาจกระทบ latency ชั่วคราว")
                    Link("เอกสาร CoreWLAN ของ Apple", destination: URL(string: "https://developer.apple.com/documentation/corewlan")!)
                }
                Panel(title: "ข้อมูลที่เก็บในเครื่อง") {
                    Text("โครงการปัจจุบันเก็บอัตโนมัติที่ ~/Library/Application Support/WiFiTroubleshooting/survey.json ไฟล์ JSON รวมภาพแผนผังและจุดวัด; CSV รวม SSID/BSSID และเวลาวัด ตรวจข้อมูลก่อนแบ่งปัน")
                    Text("ไม่มีบัญชีผู้ใช้หรือระบบส่ง telemetry การตรวจ DNS/HTTPS จะติดต่อ www.apple.com เมื่อกดเริ่มตรวจสอบเท่านั้น")
                }
            }.padding(28)
        }
    }
}
