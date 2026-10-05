import SwiftUI
import Charts
import AppKit
import WiFiCore

enum Screen: String, CaseIterable, Identifiable {
    case channels = "ผังช่องสัญญาณ", workflows = "รูปแบบการใช้งาน", sessions = "รอบงานและเปรียบเทียบ", overview = "ภาพรวม", space = "Signal Space", quality = "คุณภาพและเหตุการณ์", networks = "เครือข่าย", survey = "สำรวจพื้นที่", diagnostics = "แก้ไขปัญหา", capabilities = "อุปกรณ์และสิทธิ์"
    var id: Self { self }
    var icon: String {
        switch self { case .channels: return "square.grid.3x3"; case .workflows: return "square.grid.2x2"; case .sessions: return "clock.arrow.circlepath"; case .quality: return "chart.bar.xaxis"; case .space: return "cube.transparent"; case .overview: return "waveform.path.ecg"; case .networks: return "wifi"; case .survey: return "map"; case .diagnostics: return "stethoscope"; case .capabilities: return "antenna.radiowaves.left.and.right" }
    }
    var subtitle: String {
        switch self {
        case .channels: return "แยกย่าน เลขช่อง ความถี่ และความกว้างตามผังอ้างอิง"
        case .workflows: return "เลือกขั้นตอนการทำงานให้ตรงกับสิ่งที่ต้องการตรวจ"
        case .sessions: return "บันทึกรอบวัด เปิดย้อนหลัง และเปรียบเทียบก่อน–หลัง"
        case .quality: return "สถิติสัญญาณ ประวัติการเปลี่ยนแปลง และตั้งค่าการติดตาม"
        case .space: return "เลือกกราฟเชิงเส้นหรือสามมิติเพื่อตรวจค่าที่วัดจริง"
        case .overview: return "ติดตามคุณภาพการเชื่อมต่อของคุณแบบสด"
        case .networks: return "สำรวจ access point และเปรียบเทียบช่องสัญญาณ"
        case .survey: return "วัดสัญญาณ ณ จุดจริงบนแผนผังพื้นที่"
        case .diagnostics: return "แยกปัญหาสัญญาณ เส้นทางเครือข่าย DNS และอินเทอร์เน็ต"
        case .capabilities: return "ตรวจสอบสิ่งที่ฮาร์ดแวร์และ macOS เปิดให้ใช้งาน"
        }
    }
}
func signalColor(_ value: Int?) -> Color {
    guard let value else { return .secondary }
    if value >= -67 { return StudioTheme.green }; if value >= -75 { return .orange }; return Color(red: 1, green: 0.28, blue: 0.4)
}
struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection: Screen? = .workflows
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Image(systemName: "wifi").font(.system(size: 27, weight: .bold)).foregroundStyle(StudioTheme.cyan).frame(width: 52, height: 52).background(StudioTheme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(StudioTheme.cyan.opacity(0.35)))
                    VStack(alignment: .leading) { Text("Wi-Fi").font(.title2.bold()); Text("SIGNAL STUDIO").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1) }
                }.padding(.top, 24).padding(.horizontal, 18)
                List(Screen.allCases, selection: $selection) { screen in Label(screen.rawValue, systemImage: screen.icon).padding(.vertical, 8).tag(screen) }.listStyle(.sidebar).scrollContentBackground(.hidden)
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.link?.powered == true ? "Wi-Fi เปิดอยู่" : "รอการเชื่อมต่อ", systemImage: "circle.fill").foregroundStyle(store.link?.powered == true ? .mint : .secondary).font(.caption)
                    Text("2.4 / 5 / 6 GHz").font(.system(.caption, design: .monospaced))
                    Text("REAL-TIME NETWORK INTELLIGENCE").font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                    LiveStatus()
                    RecordingBadge(archive: store.sessions)
                }.padding(20)
            }.background(StudioTheme.background).navigationSplitViewColumnWidth(235)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) { Text((selection ?? .overview).rawValue).font(.largeTitle.bold()); Text((selection ?? .overview).subtitle).foregroundStyle(.secondary) }
                    Spacer()
                    LiveStatus()
                    if !store.interfaces.isEmpty {
                        Picker("Adapter", selection: $store.selectedInterface) { ForEach(store.interfaces, id: \.self) { Text($0).tag($0) } }.frame(width: 145).onChange(of: store.selectedInterface) { store.changeInterface() }
                    }
                    Button { Task { await store.scan() } } label: { Label(store.scanning ? "กำลังสแกน…" : "สแกน Wi-Fi", systemImage: "arrow.clockwise") }.buttonStyle(.borderedProminent).tint(StudioTheme.cyan).foregroundStyle(store.scanning ? StudioTheme.cyan : .black).disabled(store.scanning)
                }.padding(28)
                Divider()
                if let error = store.error {
                    HStack { Image(systemName: "exclamationmark.triangle"); Text(error); Spacer(); Button("ปิด") { store.error = nil } }.font(.callout).padding(12).background(.orange.opacity(0.15))
                }
                Group {
                    switch selection ?? .overview {
                    case .channels: ChannelPlanView()
                    case .workflows: WorkflowView { selection = $0 }
                    case .sessions: SessionsView(archive: store.sessions)
                    case .overview: OverviewView()
                    case .space: SpaceView()
                    case .quality: QualityView()
                    case .networks: NetworksView()
                    case .survey: SurveyView()
                    case .diagnostics: DiagnosticsView()
                    case .capabilities: CapabilitiesView()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.background(LinearGradient(colors: [StudioTheme.background, Color(red: 0.04, green: 0.065, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }.tint(StudioTheme.cyan).preferredColorScheme(.dark)
    }
}
struct Panel<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { Text(title).font(.headline); content }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(StudioTheme.cyan.opacity(0.13)))
    }
}
struct Metric: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var title: String; var value: String; var unit: String; var caption: String; var color: Color = StudioTheme.cyan
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(title).font(.callout).foregroundStyle(.secondary); Spacer(); RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 18, height: 4) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 37, weight: .semibold, design: .rounded)).foregroundStyle(color)
                    .contentTransition(.numericText()).animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: value)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(LinearGradient(colors: [color.opacity(0.14), StudioTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(color.opacity(0.25)))
    }
}
struct OverviewView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label(store.link?.ssid ?? "SSID ไม่พร้อมใช้งาน", systemImage: "wifi").font(.title2.weight(.semibold))
                    Spacer()
                    Picker("รอบอ่าน", selection: $store.sampleInterval) { Text("1 วินาที").tag(1.0); Text("2 วินาที").tag(2.0); Text("5 วินาที").tag(5.0) }.frame(width: 155)
                    Toggle("Live", isOn: $store.monitoring).toggleStyle(.switch)
                }
                HStack(spacing: 14) {
                    Metric(title: "ความแรงสัญญาณ", value: store.link?.rssi.map(String.init) ?? "—", unit: "dBm", caption: Signal.quality(store.link?.rssi), color: signalColor(store.link?.rssi))
                    Metric(title: "Signal / Noise", value: store.link?.snr.map(String.init) ?? "—", unit: "dB", caption: "SNR จาก RSSI − Noise", color: StudioTheme.purple)
                    Metric(title: "อัตราลิงก์ส่ง", value: store.link?.rate.map { String(format: "%.0f", $0) } ?? "—", unit: "Mbps", caption: "ไม่ใช่ความเร็วอินเทอร์เน็ต", color: .orange)
                    Metric(title: "ช่องสัญญาณ", value: store.link?.channel.map(String.init) ?? "—", unit: store.link?.band.rawValue ?? "", caption: store.link?.phy ?? "รอข้อมูล")
                }
                RecentSignalEvent()
                HStack { SignalDisplayPicker(); Spacer(); Button("ส่งออกประวัติ CSV") { store.exportHistory() }.disabled(store.history.isEmpty) }
                SignalDisplay().frame(height: 520)
                HStack(alignment: .top, spacing: 18) {
                    Panel(title: "ข้อสังเกตและแนวทางแก้ไข") {
                        ForEach(Signal.advice(rssi: store.link?.rssi, snr: store.link?.snr), id: \.self) { Text($0) }
                        Text("เกณฑ์ RSSI / SNR เป็นแนวทางเบื้องต้น ต้องพิจารณาประเภทงานและวัดซ้ำในพื้นที่จริง").font(.caption).foregroundStyle(.secondary)
                    }
                    Panel(title: "ข้อมูลการเชื่อมต่อ") {
                        LabeledContent("BSSID", value: store.link?.bssid ?? "ไม่เปิดเผย")
                        LabeledContent("Noise", value: store.link?.noise.map { "\($0) dBm" } ?? "ไม่มีข้อมูล")
                        LabeledContent("ประเทศ", value: store.link?.country ?? "ไม่เปิดเผย")
                        LabeledContent("อัปเดต", value: store.link?.timestamp.formatted(date: .omitted, time: .standard) ?? "—")
                    }
                }
            }.padding(28)
        }
    }
}

struct SpaceView: View {
    @EnvironmentObject var store: AppStore
    @State private var surveyMode = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Picker("ชุดข้อมูล", selection: $surveyMode) { Text("สัญญาณเครือข่าย").tag(false); Text("จุดสำรวจบนแผนผัง").tag(true) }.pickerStyle(.segmented).frame(width: 360)
                Spacer(); Toggle("Live", isOn: $store.monitoring).toggleStyle(.switch)
            }
            SignalDisplayPicker()
            SignalDisplay(survey: surveyMode).id(surveyMode)
            HStack(spacing: 18) {
                Label("สีแยกย่าน / คุณภาพสัญญาณ", systemImage: "circle.lefthalf.filled")
                Label("ค่าที่วัดจริง · dBm", systemImage: "waveform.path")
                Spacer(); Text("SIGNAL VISUALIZATION").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(StudioTheme.cyan)
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(28)
    }
}
