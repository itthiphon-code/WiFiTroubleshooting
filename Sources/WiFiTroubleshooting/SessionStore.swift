import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WiFiCore

@MainActor
final class SessionStore: ObservableObject {
    @Published var saved: [MeasurementSession] = []
    @Published var recording: MeasurementSession?
    @Published var name = ""
    @Published var note = ""
    @Published var duration: Double = 60
    @Published var status = "พร้อมเริ่มรอบงาน"
    @Published var error: String?
    @Published var busy = false
    @Published var unsavedIDs: Set<UUID> = []
    var hasUnsavedChanges: Bool { !unsavedIDs.isEmpty }
    private let archive: SessionArchive
    private var deadline: Date?
    private var checkpointAt = Date.distantPast
    private var clockTask: Task<Void, Never>?
    var isRecording: Bool { recording != nil }
    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = Bundle.main.bundleIdentifier?.hasSuffix(".QA") == true ? "WiFiTroubleshooting-QA" : "WiFiTroubleshooting"
        archive = SessionArchive(directory: root.appendingPathComponent(folder).appendingPathComponent("Sessions"))
        Task { await reload() }
    }
    func reload() async {
        do {
            let result = try await archive.list()
            let pending = saved.filter { unsavedIDs.contains($0.id) }
            saved = pending + result.sessions.filter { !unsavedIDs.contains($0.id) }
            if result.skipped > 0 { error = "ข้ามไฟล์รอบงานที่อ่านไม่ได้ \(result.skipped) ไฟล์ ไฟล์ต้นฉบับยังอยู่ในเครื่อง" }
        } catch { self.error = error.localizedDescription }
    }
    func start(threshold: Int, interval: Double) async {
        guard recording == nil, !busy else { return }
        busy = true; defer { busy = false }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = MeasurementSession(name: title.isEmpty ? "รอบวัด \(Date().formatted(date: .abbreviated, time: .shortened))" : title,
                                         note: note, threshold: threshold, sampleInterval: interval)
        do {
            try await archive.save(session)
            recording = session; deadline = Date().addingTimeInterval(duration); checkpointAt = Date()
            status = "กำลังบันทึก · checkpoint ทุกประมาณ 10 วินาที"
            clockTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, recording != nil else { return }
                    if let deadline, Date() >= deadline { await stop(); return }
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func receive(_ sample: LinkSample, events: [SignalEvent], networks: [NetworkRecord]) async {
        guard var session = recording, sample.timestamp >= session.startedAt else { return }
        if session.samples.count >= 3_600 { await stop(); return }
        session.samples.append(sample)
        session.events.append(contentsOf: events)
        if session.events.count > 10_000 { session.events.removeFirst(session.events.count - 10_000) }
        session.networks = Array(networks.prefix(10_000))
        recording = session
        if Date().timeIntervalSince(checkpointAt) >= 10 {
            checkpointAt = Date()
            do { try await archive.save(session) }
            catch { self.error = "Checkpoint ไม่สำเร็จ: \(error.localizedDescription)" }
        }
    }
    func stop() async {
        guard var session = recording else { return }
        recording = nil; busy = true; clockTask?.cancel(); clockTask = nil
        session.endedAt = max(Date(), session.samples.last?.timestamp ?? session.startedAt)
        do {
            try await archive.save(session); error = nil; status = "บันทึกแล้ว \(session.samples.count) ตัวอย่าง"
            await reload()
        } catch {
            // Keep the complete in-memory session available for export / retry after a disk failure.
            saved.removeAll { $0.id == session.id }; saved.insert(session, at: 0)
            unsavedIDs.insert(session.id)
            self.error = "บันทึกสุดท้ายไม่สำเร็จ ส่งออก JSON เพื่อเก็บข้อมูล: \(error.localizedDescription)"
        }
        busy = false
    }
    func snapshot(history: [LinkSample], events: [SignalEvent], networks: [NetworkRecord], threshold: Int, interval: Double) async {
        guard !history.isEmpty, !busy else { return }
        busy = true; defer { busy = false }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var session = MeasurementSession(name: title.isEmpty ? "Snapshot \(Date().formatted(date: .omitted, time: .standard))" : title,
                                         note: note, threshold: threshold, sampleInterval: interval,
                                         startedAt: history[0].timestamp, samples: history, networks: Array(networks.prefix(10_000)),
                                         events: events.filter { $0.timestamp >= history[0].timestamp })
        session.endedAt = max(Date(), history.last!.timestamp)
        do { try await archive.save(session); status = "บันทึก snapshot แล้ว"; await reload() }
        catch { self.error = error.localizedDescription }
    }
    func retrySave(_ session: MeasurementSession) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do { try await archive.save(session); unsavedIDs.remove(session.id); error = nil; await reload() }
        catch { self.error = error.localizedDescription }
    }
    func importSession() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 25_000_000 else { throw SessionError.invalid }
                var session = try MeasurementSession.decode(Data(contentsOf: url))
                // Import as a new entry, preserving the existing session even if IDs collide.
                session.id = UUID()
                try await archive.save(session); await reload(); status = "นำเข้ารอบงานแล้ว"
            } catch { self.error = error.localizedDescription }
        }
    }
    func exportComparison(before: MeasurementSession, after: MeasurementSession, threshold: Int) {
        let comparison = SessionComparison(before: before, after: after, threshold: threshold)
        func number(_ value: Double?) -> String { value.map { String(format: "%.2f", $0) } ?? "N/A" }
        let text = """
        Wi-Fi Troubleshooting — Comparison
        Exported: \(Date().ISO8601Format())
        Before: \(before.name) / \(before.startedAt.ISO8601Format())
        Notes: \(before.note)
        After: \(after.name) / \(after.startedAt.ISO8601Format())
        Notes: \(after.note)
        Common threshold: \(threshold) dBm
        Valid RSSI samples: \(comparison.before.valid) → \(comparison.after.valid)
        Mean RSSI (dBm): \(number(comparison.before.mean)) → \(number(comparison.after.mean))
        Mean difference, after minus before (dB): \(number(comparison.delta))
        Samples below threshold (%): \(number(comparison.before.belowPercent)) → \(number(comparison.after.belowPercent))
        Sample percentages are not uptime. RSSI is not internet throughput.
        Compare under similar location, device orientation, AP, adapter and load.
        Differences alone do not establish causation. Raw evidence: export each session JSON.
        """
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "wifi-comparison.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try Data(text.utf8).write(to: url, options: .atomic) }
        catch { self.error = error.localizedDescription }
    }
    func export(_ session: MeasurementSession, csv: Bool = false) {
        let panel = NSSavePanel(); panel.allowedContentTypes = csv ? [.commaSeparatedText] : [.json]
        panel.nameFieldStringValue = csv ? "measurement.csv" : "measurement.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = csv ? Data(("\u{FEFF}" + CSV.history(session.samples)).utf8) : try JSONEncoder().encode(session)
            try data.write(to: url, options: .atomic)
            if !csv { unsavedIDs.remove(session.id) }
        } catch { self.error = error.localizedDescription }
    }
}
