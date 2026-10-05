import Foundation

public struct ChannelCapability: Identifiable, Sendable {
    public var band: Band
    public var channel: Int
    public var width: Int?
    public var id: String { "\(band.rawValue)-\(channel)-\(width ?? 0)" }
    public init(band: Band, channel: Int, width: Int?) { self.band = band; self.channel = channel; self.width = width }
}
/// Reference channelization, not a per-country permission list. See docs/CHANNEL-REFERENCES.md.
public enum ChannelPlan {
    public static func primary(_ band: Band) -> [Int] {
        switch band {
        case .two: return Array(1...14)
        case .five: return Array(stride(from: 36, through: 64, by: 4)) + Array(stride(from: 100, through: 144, by: 4)) + Array(stride(from: 149, through: 177, by: 4))
        case .six: return [2] + Array(stride(from: 1, through: 233, by: 4)) // CH 2 is the special 5935 MHz channel.
        case .unknown: return []
        }
    }
    public static func centers(band: Band, width: Int) -> [Int] {
        if width == 20 { return primary(band) }
        switch (band, width) {
        case (.two, 40): return Array(3...11)
        case (.five, 40): return [38,46,54,62,102,110,118,126,134,142,151,159,167,175]
        case (.five, 80): return [42,58,106,122,138,155,171]
        case (.five, 160): return [50,114,163]
        case (.six, 40): return Array(stride(from: 3, through: 227, by: 8))
        case (.six, 80): return Array(stride(from: 7, through: 215, by: 16))
        case (.six, 160): return Array(stride(from: 15, through: 207, by: 32))
        case (.six, 320): return [31,63,95,127,159,191]
        default: return []
        }
    }
    public static func widths(_ band: Band) -> [Int] {
        switch band { case .two: return [20,40]; case .five: return [20,40,80,160]; case .six: return [20,40,80,160,320]; case .unknown: return [] }
    }
    public static func centerFrequency(band: Band, channel: Int, width: Int) -> Int? {
        guard centers(band: band, width: width).contains(channel) else { return nil }
        switch band {
        case .two: return channel == 14 ? 2484 : 2407 + 5 * channel
        case .five: return 5000 + 5 * channel
        case .six: return channel == 2 && width == 20 ? 5935 : 5950 + 5 * channel
        case .unknown: return nil
        }
    }
    public static func isPSC(_ channel: Int, band: Band) -> Bool {
        band == .six && (5...229).contains(channel) && (channel - 5) % 16 == 0
    }
    public static func range(_ band: Band) -> ClosedRange<Double> {
        switch band { case .two: return 2400...2495; case .five: return 5170...5900; case .six: return 5925...7125; case .unknown: return 0...1 }
    }
    /// Position on a frequency axis shared by 3D tick labels and measurements.
    public static func xPosition(band: Band, channel: Int) -> Double? {
        guard let frequency = band.frequency(channel: channel) else { return nil }
        let bounds = range(band)
        guard bounds.contains(Double(frequency)) else { return nil }
        return -4.5 + (Double(frequency) - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound) * 11
    }
    public static func ticks(_ band: Band) -> [Int] {
        switch band {
        case .two: return [1,6,11,14]
        case .five: return [36,64,100,144,177]
        case .six: return [2,37,101,165,233]
        case .unknown: return []
        }
    }
}
