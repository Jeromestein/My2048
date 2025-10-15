import Foundation

struct GameBoardPreset {
    let identifier: String
    let title: String
    let dimension: Int
    let targetValue: Int
    let score: Int

    private let additionalTilePool: [Int]
    private let additionalTileCountRange: ClosedRange<Int>

    init(
        identifier: String,
        title: String,
        dimension: Int = 4,
        targetValue: Int,
        score: Int? = nil,
        additionalTilePool: [Int],
        additionalTileCountRange: ClosedRange<Int>
    ) {
        precondition(dimension > 1, "Preset dimension must be at least 2")
        precondition(targetValue > 0 && (targetValue & (targetValue - 1)) == 0, "Target value must be a power of two")
        precondition(additionalTileCountRange.lowerBound >= 0, "Additional tile count cannot be negative")

        let maxSupportedAdditional = min(additionalTileCountRange.upperBound, 4)
        let minSupportedAdditional = min(additionalTileCountRange.lowerBound, maxSupportedAdditional)
        precondition(minSupportedAdditional <= maxSupportedAdditional, "Invalid additional tile count range")

        self.identifier = identifier
        self.title = title
        self.dimension = dimension
        self.targetValue = targetValue
        self.score = score ?? GameBoardPreset.defaultScore(forTargetValue: targetValue)
        self.additionalTilePool = additionalTilePool
        self.additionalTileCountRange = minSupportedAdditional...maxSupportedAdditional
    }

    func makeTileValues<G: RandomNumberGenerator>(using generator: inout G) -> [Int?] {
        let totalSlots = dimension * dimension
        guard totalSlots > 0 else { return [] }

        var positions = Array(0..<totalSlots)
        positions.shuffle(using: &generator)

        var values = Array(repeating: Int?.none, count: totalSlots)

        if let firstPosition = positions.first {
            values[firstPosition] = targetValue
        }

        let availablePositions = max(positions.count - 1, 0)
        let maxAdditional = min(additionalTileCountRange.upperBound, availablePositions)
        let minAdditional = min(additionalTileCountRange.lowerBound, maxAdditional)

        let additionalCount: Int
        if maxAdditional <= 0 {
            additionalCount = 0
        } else if minAdditional == maxAdditional {
            additionalCount = minAdditional
        } else {
            additionalCount = Int.random(in: minAdditional...maxAdditional, using: &generator)
        }

        guard additionalCount > 0, !additionalTilePool.isEmpty else {
            return values
        }

        var positionIndex = 1
        for _ in 0..<additionalCount {
            guard positionIndex < positions.count else { break }
            let position = positions[positionIndex]
            positionIndex += 1
            let value = additionalTilePool.randomElement(using: &generator) ?? 2
            values[position] = value
        }

        return values
    }

    private static func defaultScore(forTargetValue value: Int) -> Int {
        guard value > 0 else { return 0 }
        var exponent = 0
        var workingValue = value
        while workingValue > 1 {
            workingValue >>= 1
            exponent += 1
        }
        return value * max(exponent - 1, 0)
    }
}

enum GameBoardPresetOption: CaseIterable {
    case tile1024
    case tile2048
    case tile4096

    var preset: GameBoardPreset {
        switch self {
        case .tile1024:
            return GameBoardPreset(
                identifier: "preset-1024",
                title: "1024",
                targetValue: 1024,
                additionalTilePool: [2, 4, 8, 16, 32, 64, 128, 256, 512],
                additionalTileCountRange: 1...4
            )
        case .tile2048:
            return GameBoardPreset(
                identifier: "preset-2048",
                title: "2048",
                targetValue: 2048,
                additionalTilePool: [4, 8, 16, 32, 64, 128, 256, 512, 1024],
                additionalTileCountRange: 1...4
            )
        case .tile4096:
            return GameBoardPreset(
                identifier: "preset-4096",
                title: "4096",
                targetValue: 4096,
                additionalTilePool: [8, 16, 32, 64, 128, 256, 512, 1024, 2048],
                additionalTileCountRange: 1...4
            )
        }
    }

    var title: String {
        switch self {
        case .tile1024: return "1024"
        case .tile2048: return "2048"
        case .tile4096: return "4096"
        }
    }
}
