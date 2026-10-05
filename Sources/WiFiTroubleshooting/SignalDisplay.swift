import SwiftUI
import Charts
import WiFiCore

enum SignalDisplayMode: String, CaseIterable {
    case line = "กราฟเชิงเส้น"
    case threeD = "3D"
}

/// One persisted preference shared by Overview and Signal Space.
struct SignalDisplayPicker: View {
    @AppStorage("signalDisplayMode") private var mode: SignalDisplayMode = .threeD
    var body: some View {
        Picker("รูปแบบกราฟ", selection: $mode) {
            ForEach(SignalDisplayMode.allCases, id: \.self) { value in
                Label(value.rawValue, systemImage: value == .line ? "chart.xyaxis.line" : "cube.transparent").tag(value)
            }
        }.pickerStyle(.segmented).frame(width: 280)
            .accessibilityIdentifier("signal-display-picker")
    }
}

struct SignalDisplay: View {
    @AppStorage("signalDisplayMode") private var mode: SignalDisplayMode = .threeD
    var survey = false
    var body: some View {
        // Remove the inactive renderer so line mode does not keep a hidden 3D scene running.
        if mode == .threeD { SignalStage(survey: survey) }
        else { LinearSignalStage(survey: survey) }
    }
}

struct LinearSignalStage: View {
    @EnvironmentObject var store: AppStore
    var survey = false
    private var points: [SurveyPoint] { Array(store.survey.points.suffix(300)) }
    private var hasData: Bool {
        survey ? points.contains { $0.sample.rssi != nil } : store.history.contains { $0.rssi != nil || $0.noise != nil }
    }
    var body: some View {
        Panel(title: survey ? "กราฟเชิงเส้น · จุดสำรวจตามลำดับการวัด" : "กราฟเชิงเส้น · สัญญาณที่เชื่อมต่อตามเวลา") {
            if hasData {
                SampleSignalChart(samples: survey ? points.map(\.sample) : store.history, indexed: survey, showNoise: !survey)
            } else {
                ContentUnavailableView(survey ? "ยังไม่มีจุดสำรวจ" : "รอข้อมูลสัญญาณ", systemImage: "chart.xyaxis.line",
                                       description: Text(survey ? "ปักจุดวัดในหน้า สำรวจพื้นที่ → 2D" : "เชื่อมต่อ Wi‑Fi และเปิด Live เพื่อเริ่มเก็บค่าจริง"))
                    .frame(minHeight: 230, maxHeight: .infinity)
            }
            Text(survey
                 ? "แต่ละจุดเป็นค่าที่วัดจริง เส้นเชื่อมแสดงลำดับการวัด ไม่ใช่ระยะทางหรือการประมาณสัญญาณในพื้นที่ที่ยังไม่ได้วัด"
                 : "ประวัติสูงสุด 300 ตัวอย่างของลิงก์ที่เชื่อมต่อ · เส้นเชื่อมระหว่างค่าที่อ่านได้ · รอบอ่านและ Live ใช้ร่วมกับมุมมอง 3D; AP รอบข้างดูได้ใน 3D / หน้าเครือข่าย")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
