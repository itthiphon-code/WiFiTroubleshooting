import Foundation

struct DiagnosticResult: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var status: String
    var detail: String
}
struct CommandResult: Sendable { var code: Int32; var output: String; var timedOut: Bool }
enum Diagnostics {
    // Runs fixed executables with separate arguments. Never invokes a shell.
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 12) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
        process.environment = ["PATH":"/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL":"C"]
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
        defer { try? FileManager.default.removeItem(at: file) }
        guard let handle = try? FileHandle(forWritingTo: file) else { return .init(code: -1, output: "Cannot create output file", timedOut: false) }
        defer { try? handle.close() }
        process.standardOutput = handle; process.standardError = handle
        do { try process.run() } catch { return .init(code: -1, output: error.localizedDescription, timedOut: false) }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        let timedOut = process.isRunning
        if timedOut {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.2)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        process.waitUntilExit()
        let output = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        return .init(code: process.terminationStatus, output: String(output.prefix(20_000)), timedOut: timedOut)
    }
    static func check() -> [DiagnosticResult] {
        var results: [DiagnosticResult] = []
        let route = run("/sbin/route", ["-n", "get", "default"])
        let gateway = route.output.split(separator: "\n").first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("gateway:") }?.split(separator: " ").last.map(String.init)
        results.append(.init(name: "Default route", status: route.code == 0 ? "พบเส้นทาง" : "ไม่พบเส้นทาง", detail: route.output))
        if let gateway, gateway.range(of: "^[0-9a-fA-F:.%a-zA-Z0-9]+$", options: .regularExpression) != nil {
            let ping = run("/sbin/ping", ["-n", "-c", "4", "-W", "1000", gateway], timeout: 8)
            results.append(.init(name: "Gateway · \(gateway)", status: ping.code == 0 ? "ได้รับ ICMP response" : "ไม่ได้รับ response / ICMP อาจถูกบล็อก", detail: ping.output))
        }
        let dns = run("/usr/bin/dscacheutil", ["-q", "host", "-a", "name", "www.apple.com"], timeout: 8)
        results.append(.init(name: "System DNS · www.apple.com", status: dns.code == 0 && dns.output.contains("ip_address:") ? "แปลงชื่อสำเร็จ" : "ไม่พบคำตอบ / หมดเวลา", detail: dns.output))
        let https = run("/usr/bin/curl", ["--head", "--silent", "--show-error", "--max-time", "10", "--connect-timeout", "5", "--write-out", "\nHTTP %{http_code} · connect %{time_connect}s · total %{time_total}s\n", "https://www.apple.com"], timeout: 12)
        results.append(.init(name: "HTTPS · www.apple.com", status: https.code == 0 ? "ได้รับ HTTP response ผ่าน TLS" : "เชื่อมต่อไม่สำเร็จ", detail: https.output))
        return results
    }
}
