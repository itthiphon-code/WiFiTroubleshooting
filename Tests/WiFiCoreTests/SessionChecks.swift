import Foundation
import WiFiCore

func sessionFixture(name: String = "ห้อง 201") -> MeasurementSession {
    var session = MeasurementSession(name: name, note: "ก่อนย้าย AP", threshold: -70, sampleInterval: 1,
                                     startedAt: Date(timeIntervalSince1970: 100), samples: [measured(-80, time: 100), measured(-60, time: 101)])
    session.endedAt = Date(timeIntervalSince1970: 102)
    return session
}
func checkSessionValidation() throws {
    let session = sessionFixture()
    let decoded = try MeasurementSession.decode(JSONEncoder().encode(session))
    XCTAssertEqual(decoded.name, session.name); XCTAssertEqual(decoded.samples.count, 2)
    XCTAssertEqual(decoded.id, session.id)
    var invalid = session; invalid.version = 2
    XCTAssertThrowsError(try MeasurementSession.decode(JSONEncoder().encode(invalid)))
    invalid = session; invalid.samples[1] = invalid.samples[0]
    XCTAssertThrowsError(try MeasurementSession.decode(JSONEncoder().encode(invalid)))
    invalid = session; invalid.samples[0].timestamp = Date(timeIntervalSince1970: 99)
    XCTAssertThrowsError(try MeasurementSession.decode(JSONEncoder().encode(invalid)))
    invalid = session; invalid.samples.reverse()
    XCTAssertThrowsError(try MeasurementSession.decode(JSONEncoder().encode(invalid)))
    invalid = session; invalid.samples[0].rssi = 0
    XCTAssertThrowsError(try MeasurementSession.decode(JSONEncoder().encode(invalid)))
    invalid = session
    let event = SignalEvent(timestamp: Date(timeIntervalSince1970: 101), kind: "test", detail: "test", interface: "en0")
    invalid.events = [event, event]
    XCTAssertThrowsError(try MeasurementSession.decode(JSONEncoder().encode(invalid)))
    invalid = session; invalid.endedAt = nil
    XCTAssertEqual(try MeasurementSession.decode(JSONEncoder().encode(invalid)).samples.count, 2)
}
func checkSessionComparison() {
    let a = sessionFixture()
    var b = sessionFixture(name: "หลัง")
    b.threshold = -80
    b.samples = [measured(-60, time: 100), measured(-40, time: 101)]
    let result = SessionComparison(before: a, after: b, threshold: -70)
    XCTAssertEqual(result.delta, 20)
    XCTAssertEqual(result.before.belowPercent, 50)
    XCTAssertEqual(result.after.belowPercent, 0)
    b.samples = []
    XCTAssertNil(SessionComparison(before: a, after: b, threshold: -70).delta)
}
func checkSessionArchive() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = SessionArchive(directory: root)
    XCTAssertEqual(try await archive.list().sessions.count, 0)
    var session = sessionFixture(); session.endedAt = nil
    try await archive.save(session)
    let opened = try await SessionArchive(directory: root).list()
    XCTAssertEqual(opened.sessions.count, 1); XCTAssertNil(opened.sessions[0].endedAt)
    session.endedAt = Date(timeIntervalSince1970: 102)
    try await archive.save(session)
    let saved = try await archive.list()
    XCTAssertEqual(saved.sessions.count, 1); XCTAssertEqual(saved.sessions[0].endedAt, session.endedAt)
    try Data("broken".utf8).write(to: root.appendingPathComponent("broken.json"))
    let final = try await archive.list()
    XCTAssertEqual(final.sessions.count, 1); XCTAssertEqual(final.skipped, 1)
}
