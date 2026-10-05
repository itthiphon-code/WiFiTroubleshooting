import Foundation
import WiFiCore

final class WiFiCoreTests {
    func testBandMustNotBeInferredFromChannelNumber() {
        XCTAssertEqual(Band.two.frequency(channel: 1), 2412)
        XCTAssertEqual(Band.six.frequency(channel: 1), 5955)
        XCTAssertEqual(Band.six.frequency(channel: 2), 5935)
        XCTAssertEqual(Band.six.frequency(channel: 233), 7115)
        XCTAssertNil(Band.six.frequency(channel: 3))
        XCTAssertEqual(Band.five.frequency(channel: 36), 5180)
        XCTAssertEqual(Band.two.frequency(channel: 14), 2484)
        XCTAssertNil(Band.unknown.frequency(channel: 1))
        XCTAssertEqual(Band.from(raw: 99), .unknown)
    }
    func testUnavailableSignalIsNotPerfectSignal() {
        XCTAssertNil(Signal.valid(0)); XCTAssertNil(Signal.valid(-999))
        XCTAssertEqual(Signal.valid(-65), -65)
        XCTAssertEqual(Signal.quality(nil), "ไม่มีข้อมูล")
        XCTAssertEqual(Signal.quality(-67), "ดี")
        XCTAssertEqual(Signal.quality(-68), "พอใช้")
        XCTAssertEqual(Signal.quality(-76), "อ่อน")
    }
    func testCSVUntrustedNetworkNames() {
        XCTAssertEqual(CSV.cell("hello,\"world\"\n"), "\"hello,\"\"world\"\"\n\"")
        XCTAssertEqual(CSV.cell("-65"), "\"-65\"")
        XCTAssertEqual(CSV.cell("=HYPERLINK(1)"), "\"'=HYPERLINK(1)\"")
        XCTAssertEqual(CSV.cell("  @SUM(1)"), "\"'  @SUM(1)\"")
    }
    func testSurveyRoundTripAndSNR() throws {
        var survey = Survey()
        survey.name = "ห้องเรียน ชั้น 2"
        survey.floorPlan = Data([1, 2, 3])
        let sample = LinkSample(interface: "en0", powered: true, ssid: "Test", bssid: "aa:bb:cc:dd:ee:ff", rssi: -62, noise: -94, rate: 1200, channel: 5, band: .six, phy: "ax", country: "TH", supportedBands: [.two, .five, .six])
        survey.points = [SurveyPoint(x: 0.25, y: 0.75, label: "โต๊ะ 1", sample: sample)]
        let decoded = try Survey.decode(JSONEncoder().encode(survey))
        XCTAssertEqual(decoded.name, survey.name)
        XCTAssertEqual(decoded.floorPlan, survey.floorPlan)
        XCTAssertEqual(decoded.points[0].sample.snr, 32)
        XCTAssertEqual(decoded.points[0].sample.band, .six)
        XCTAssertTrue(CSV.survey(decoded).contains("โต๊ะ 1"))
        survey.points[0].x = 1.1
        XCTAssertThrowsError(try Survey.decode(JSONEncoder().encode(survey)))
        survey.points = []; survey.version = 2
        XCTAssertThrowsError(try Survey.decode(JSONEncoder().encode(survey)))
    }
    func testFreshness() {
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(SampleFreshness.state(timestamp: nil, now: now, monitoring: true, interval: 1), .waiting)
        XCTAssertEqual(SampleFreshness.state(timestamp: now, now: now, monitoring: false, interval: 1), .paused)
        XCTAssertEqual(SampleFreshness.state(timestamp: now.addingTimeInterval(-4), now: now, monitoring: true, interval: 1), .live)
        XCTAssertEqual(SampleFreshness.state(timestamp: now.addingTimeInterval(-6), now: now, monitoring: true, interval: 1), .stale)
        XCTAssertEqual(SampleFreshness.state(timestamp: now.addingTimeInterval(-14), now: now, monitoring: true, interval: 5), .live)
    }
    func test3DGeometry() {
        XCTAssertEqual(SignalGeometry.height(rssi: -120), SignalGeometry.height(rssi: -100))
        XCTAssertEqual(SignalGeometry.height(rssi: -1), SignalGeometry.height(rssi: -20))
        XCTAssertTrue(SignalGeometry.height(rssi: -40) > SignalGeometry.height(rssi: -80))
        let origin = SignalGeometry.surveyPosition(x: 0, y: 0, width: 16, depth: 10)
        let center = SignalGeometry.surveyPosition(x: 0.5, y: 0.5, width: 16, depth: 10)
        let end = SignalGeometry.surveyPosition(x: 1, y: 1, width: 16, depth: 10)
        XCTAssertEqual(origin.x, -8); XCTAssertEqual(origin.z, -5)
        XCTAssertEqual(center.x, 0); XCTAssertEqual(center.z, 0)
        XCTAssertEqual(end.x, 8); XCTAssertEqual(end.z, 5)
    }
    func testSNRRequiresBothValues() {
        let n = NetworkRecord(id: "1", ssid: nil, bssid: nil, rssi: -60, noise: nil, channel: 36, band: .five, width: nil, security: "Unknown", standards: [])
        XCTAssertNil(n.snr)
        XCTAssertTrue(CSV.networks([n]).contains("5180"))
    }
}

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == expected, "Expected \(expected), got \(actual)", file: file, line: line)
}
func XCTAssertNil<T>(_ actual: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == nil, "Expected nil", file: file, line: line)
}
func XCTAssertTrue(_ actual: Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(actual, "Expected true", file: file, line: line)
}
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try expression() } catch { return }
    preconditionFailure("Expected rejection", file: file, line: line)
}
@main struct CheckRunner {
    static func main() async throws {
        let tests = WiFiCoreTests()
        tests.testBandMustNotBeInferredFromChannelNumber()
        tests.testUnavailableSignalIsNotPerfectSignal()
        tests.testCSVUntrustedNetworkNames()
        try tests.testSurveyRoundTripAndSNR()
        tests.testSNRRequiresBothValues()
        tests.testFreshness()
        tests.test3DGeometry()
        checkSummary()
        checkWeakEvents()
        checkAPChanges()
        checkNetworkSorting()
        try checkSessionValidation()
        checkSessionComparison()
        try await checkSessionArchive()
        checkChannelPlans()
        checkChannelLabelsAndGeometry()
        print("PASS: 16 WiFiCore check groups")
    }
}
