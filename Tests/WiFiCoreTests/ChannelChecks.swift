import WiFiCore

func checkChannelPlans() {
    XCTAssertEqual(ChannelPlan.primary(.two), Array(1...14))
    XCTAssertEqual(ChannelPlan.primary(.five).count, 28)
    XCTAssertTrue(!ChannelPlan.primary(.five).contains(68))
    XCTAssertEqual(ChannelPlan.primary(.six).count, 60) // 59 ordinary + special channel 2.
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .two, channel: 1, width: 20), 2412)
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .two, channel: 14, width: 20), 2484)
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .two, channel: 11, width: 40), 2462)
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .five, channel: 36, width: 20), 5180)
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .five, channel: 42, width: 80), 5210)
    XCTAssertNil(ChannelPlan.centerFrequency(band: .five, channel: 36, width: 80))
    XCTAssertNil(ChannelPlan.centerFrequency(band: .five, channel: 50, width: 320))
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .six, channel: 1, width: 20), 5955)
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .six, channel: 2, width: 20), 5935)
    XCTAssertNil(ChannelPlan.centerFrequency(band: .six, channel: 2, width: 40))
    XCTAssertEqual(ChannelPlan.centerFrequency(band: .six, channel: 233, width: 20), 7115)
    XCTAssertEqual(ChannelPlan.centers(band: .six, width: 40).count, 29)
    XCTAssertEqual(ChannelPlan.centers(band: .six, width: 80).count, 14)
    XCTAssertEqual(ChannelPlan.centers(band: .six, width: 160).count, 7)
    XCTAssertEqual(ChannelPlan.centers(band: .six, width: 320), [31,63,95,127,159,191])
}
func checkChannelLabelsAndGeometry() {
    XCTAssertEqual(ChannelPlan.primary(.six).filter { ChannelPlan.isPSC($0, band: .six) }.count, 15)
    XCTAssertTrue(ChannelPlan.isPSC(5, band: .six))
    XCTAssertTrue(ChannelPlan.isPSC(229, band: .six))
    XCTAssertTrue(!ChannelPlan.isPSC(5, band: .two))
    XCTAssertTrue(!ChannelPlan.isPSC(2, band: .six))
    XCTAssertTrue(ChannelPlan.xPosition(band: .six, channel: 2)! < ChannelPlan.xPosition(band: .six, channel: 1)!)
    XCTAssertNil(ChannelPlan.xPosition(band: .unknown, channel: 1))
    for band in [Band.two, .five, .six] {
        for channel in ChannelPlan.primary(band) {
            XCTAssertTrue((-4.5...6.5).contains(ChannelPlan.xPosition(band: band, channel: channel)!))
            XCTAssertEqual(ChannelPlan.centerFrequency(band: band, channel: channel, width: 20), band.frequency(channel: channel))
        }
    }
}
