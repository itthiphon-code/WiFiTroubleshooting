import SwiftUI
import AppKit
import CoreLocation
import UniformTypeIdentifiers
import WiFiCore

@MainActor
final class AppStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    let sessions = SessionStore()
    @Published var interfaces: [String] = []
    @Published var selectedInterface = ""
    @Published var supportedChannels: [ChannelCapability]?
    @Published var channelsUpdatedAt: Date?
    private var channelCountry: String?
    @Published var link: LinkSample?
    @Published var history: [LinkSample] = []
    @Published var networks: [NetworkRecord] = []
    @Published var scanning = false
    @Published var monitoring = true { didSet { observer.reset() } }
    @Published var autoScan = true { didSet { UserDefaults.standard.set(autoScan, forKey: "autoScan") } }
    @Published var sampleInterval: Double = 1 { didSet { UserDefaults.standard.set(sampleInterval, forKey: "sampleInterval"); observer.reset() } }
    @Published var scanInterval: Double = 30 { didSet { UserDefaults.standard.set(scanInterval, forKey: "scanInterval") } }
    @Published var weakThreshold: Int = -70 { didSet { UserDefaults.standard.set(weakThreshold, forKey: "weakThreshold"); observer.reset() } }
    @Published var observeEvents = true { didSet { UserDefaults.standard.set(observeEvents, forKey: "observeEvents"); observer.reset() } }
    @Published var events: [SignalEvent] = []
    private var observer = SignalObserver()
    @Published var lastScan: Date?
    @Published var error: String?
    @Published var permission = "ยังไม่ได้ตรวจสอบ"
    @Published var diagnosticResults: [DiagnosticResult] = []
    @Published var diagnosing = false
    @Published var survey = Survey()
    @Published var pointLabel = ""
    @Published var surveyStatus = "บันทึกอัตโนมัติในเครื่อง"
    @Published var capturing = false
    private let service = WiFiService()
    private let scanService = WiFiService()
    private let location = CLLocationManager()
    private var loop: Task<Void, Never>?
    private var scanLoop: Task<Void, Never>?
    private var generation = 0
    private var sampling = false
    private var lastScanAttempt: Date?
    private let storage: URL
    override init() {
        storage = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WiFiTroubleshooting", isDirectory: true).appendingPathComponent("survey.json")
        super.init()
        let defaults = UserDefaults.standard
        if let value = defaults.object(forKey: "sampleInterval") as? Double, [1.0, 2, 5].contains(value) { sampleInterval = value }
        if let value = defaults.object(forKey: "scanInterval") as? Double, [15.0, 30, 60].contains(value) { scanInterval = value }
        if let value = defaults.object(forKey: "weakThreshold") as? Int, (-90 ... -50).contains(value) { weakThreshold = value }
        if defaults.object(forKey: "autoScan") != nil { autoScan = defaults.bool(forKey: "autoScan") }
        if defaults.object(forKey: "observeEvents") != nil { observeEvents = defaults.bool(forKey: "observeEvents") }
        location.delegate = self
        updatePermission()
        if FileManager.default.fileExists(atPath: storage.path) {
            do { survey = try Survey.decode(Data(contentsOf: storage)) }
            catch { self.error = "เปิดการสำรวจเดิมไม่ได้: \(error.localizedDescription)" }
        }
    }
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            guard let self else { return }
            self.interfaces = await service.interfaces()
            self.selectedInterface = interfaces.first ?? ""
            startScanning()
            while !Task.isCancelled {
                if monitoring { await refresh() }
                try? await Task.sleep(for: .seconds(sampleInterval))
            }
        }
    }
    func startScanning() {
        guard scanLoop == nil else { return }
        scanLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if autoScan && !scanning && (lastScanAttempt == nil || Date().timeIntervalSince(lastScanAttempt!) >= scanInterval) { await scan() }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    func changeInterface() {
        generation += 1; link = nil; history = []; networks = []; lastScan = nil; lastScanAttempt = nil; supportedChannels = nil; channelsUpdatedAt = nil; observer.reset()
        Task { await refresh() }
    }
    func refresh() async {
        guard !sampling else { return }
        sampling = true
        defer { sampling = false }
        let current = generation
        do {
            let value = try await service.sample(selectedInterface.isEmpty ? nil : selectedInterface)
            guard current == generation else { return }
            if channelsUpdatedAt == nil || value.country != channelCountry || Date().timeIntervalSince(channelsUpdatedAt!) >= 30 {
                let channels = try await service.capabilities(selectedInterface.isEmpty ? nil : selectedInterface)
                guard current == generation else { return }
                supportedChannels = channels; channelsUpdatedAt = Date(); channelCountry = value.country
            }
            let newEvents = observeEvents ? observer.consume(value, threshold: weakThreshold, maximumGap: max(5, sampleInterval * 3)) : []
            if observeEvents {
                events.append(contentsOf: newEvents)
                if events.count > 200 { events.removeFirst(events.count - 200) }
            }
            link = value; history.append(value)
            if history.count > 300 { history.removeFirst(history.count - 300) }
            await sessions.receive(value, events: newEvents, networks: networks)
        } catch { if current == generation { link = nil; observer.reset(); self.error = error.localizedDescription } }
    }
    func scan() async {
        guard !scanning else { return }
        scanning = true
        lastScanAttempt = Date()
        defer { scanning = false }
        let current = generation
        do {
            let result = try await scanService.scan(selectedInterface.isEmpty ? nil : selectedInterface)
            guard current == generation else { return }
            networks = result; lastScan = Date()
        } catch { if current == generation { self.error = error.localizedDescription } }
    }
    func requestLocation() { location.requestWhenInUseAuthorization() }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.updatePermission() }
    }
    private func updatePermission() {
        switch location.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: permission = "อนุญาตแล้ว"
        case .denied: permission = "ถูกปฏิเสธ — เปิดใน System Settings"
        case .restricted: permission = "ถูกจำกัดโดยระบบ"
        case .notDetermined: permission = "ต้องอนุญาตเพื่ออ่าน SSID / BSSID"
        @unknown default: permission = "ไม่ทราบสถานะ"
        }
    }
    func diagnose() {
        guard !diagnosing else { return }
        diagnosing = true; diagnosticResults = []
        Task {
            let results = await Task.detached(priority: .utility) { Diagnostics.check() }.value
            diagnosticResults = results; diagnosing = false
        }
    }
    func capture(x: Double, y: Double) {
        guard !capturing else { return }
        capturing = true
        let current = generation
        Task {
            defer { capturing = false }
            do {
                let sample = try await service.sample(selectedInterface.isEmpty ? nil : selectedInterface)
                guard current == generation else { return }
                guard sample.rssi != nil else { error = "ปักจุดไม่ได้: ยังไม่มีค่าระดับสัญญาณจาก Wi‑Fi ที่เชื่อมต่อ"; return }
                survey.points.append(SurveyPoint(x: min(1, max(0, x)), y: min(1, max(0, y)), label: pointLabel.isEmpty ? "จุด \(survey.points.count + 1)" : pointLabel, sample: sample))
                pointLabel = ""; link = sample; saveSurvey()
            } catch { self.error = error.localizedDescription }
        }
    }
    func saveSurvey() {
        do {
            try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(survey).write(to: storage, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storage.path)
            surveyStatus = "บันทึกแล้ว \(Date().formatted(date: .omitted, time: .shortened))"
        } catch { self.error = "บันทึกไม่สำเร็จ: \(error.localizedDescription)" }
    }
    func importPlan() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png, .jpeg]; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 20_000_000, NSImage(data: data) != nil else { error = "ใช้ภาพ PNG/JPEG ขนาดไม่เกิน 20 MB"; return }
            survey.floorPlan = data; saveSurvey()
        } catch { self.error = error.localizedDescription }
    }
    func openSurvey() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < 50_000_000 else { error = "ไฟล์ใหญ่เกิน 50 MB"; return }
            let imported = try Survey.decode(data)
            if let plan = imported.floorPlan, NSImage(data: plan) == nil { error = "ภาพแผนผังในไฟล์ไม่ถูกต้อง"; return }
            survey = imported; saveSurvey()
        } catch { self.error = "เปิดไฟล์ไม่ได้: \(error.localizedDescription)" }
    }
    func exportSurvey() {
        do { try saveFile(JSONEncoder().encode(survey), name: "survey.json", type: .json) }
        catch { self.error = error.localizedDescription }
    }
    func exportCSV(surveyMode: Bool) {
        let text = surveyMode ? CSV.survey(survey) : CSV.networks(networks)
        do { try saveFile(Data(("\u{FEFF}" + text).utf8), name: surveyMode ? "survey.csv" : "networks.csv", type: .commaSeparatedText) }
        catch { self.error = error.localizedDescription }
    }
    func exportHistory() { exportText(CSV.history(history), name: "signal-history.csv") }
    func exportEvents() { exportText(CSV.events(events), name: "signal-events.csv") }
    func exportNetworks(_ records: [NetworkRecord]) { exportText(CSV.networks(records), name: "filtered-networks.csv") }
    private func exportText(_ text: String, name: String) {
        do { try saveFile(Data(("\u{FEFF}" + text).utf8), name: name, type: .commaSeparatedText) }
        catch { self.error = error.localizedDescription }
    }
    func exportReport() {
        let text = "Wi-Fi Troubleshooting\n\(Date().ISO8601Format())\nRoute tests use macOS default route (may be VPN/Ethernet).\n\n" + diagnosticResults.map { "\($0.name): \($0.status)\n\($0.detail)" }.joined(separator: "\n\n")
        do { try saveFile(Data(text.utf8), name: "diagnostics.txt", type: .plainText) }
        catch { self.error = error.localizedDescription }
    }
    private func saveFile(_ data: Data, name: String, type: UTType) throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try data.write(to: url, options: .atomic)
    }
    func settings(_ privacy: Bool = false) {
        if let url = URL(string: privacy ? "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices" : "x-apple.systempreferences:com.apple.wifi-settings-extension") { NSWorkspace.shared.open(url) }
    }
}
