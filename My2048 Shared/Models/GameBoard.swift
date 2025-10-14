import Foundation

struct BoardPosition: Hashable {
    let row: Int
    let column: Int

    func index(in size: Int) -> Int {
        precondition(row >= 0 && row < size && column >= 0 && column < size, "Position out of bounds")
        return row * size + column
    }
}

enum MoveDirection: CaseIterable {
    case up
    case down
    case left
    case right
}

struct GameTile: Identifiable, Equatable {
    let id: UUID
    let value: Int

    init(value: Int, id: UUID = UUID()) {
        self.id = id
        self.value = value
    }
}

struct MoveResult {
    struct Spawn {
        let position: BoardPosition
        let tile: GameTile
    }

    let didMove: Bool
    let scoreGained: Int
    let spawnedTile: Spawn?
    let didWin: Bool
    let isGameOver: Bool
}

struct GameBoard {
    private(set) var tiles: [GameTile?]
    private(set) var score: Int = 0
    private(set) var highestValue: Int = 0

    let size: Int
    let targetValue: Int

    init(size: Int = 4, targetValue: Int = 2048) {
        precondition(size > 1, "Board must be at least 2x2")
        self.size = size
        self.targetValue = targetValue
        self.tiles = Array(repeating: nil, count: size * size)
    }

    var isWin: Bool {
        highestValue >= targetValue
    }

    var isBoardFull: Bool {
        !tiles.contains(where: { $0 == nil })
    }

    /// Determines whether there are any possible moves left on the board.
    /// Returns `true` if at least one move can be made, otherwise `false`.
    ///
    /// A move is possible if:
    /// 1. There is at least one empty cell (board not full), OR
    /// 2. There are two adjacent tiles with the same value (merge possible)
    var hasMoves: Bool {
        
        // 1️⃣ If there are any empty spaces, the player can always move.
        //    Example: even if no tiles can merge, you can still slide a new tile in.
        if !isBoardFull {
            return true
        }
        
        // 2️⃣ If the board is full, check if any adjacent tiles can merge.
        //    We only need to check right and down neighbors to avoid duplicate checks.
        for row in 0..<size {
            for column in 0..<size {
                
                // Get the current tile at (row, column)
                let currentTile = tiles[index(for: row, column: column)]
                
                // --- Check right neighbor ---
                if let rightNeighbor = neighbor(ofRow: row, column: column, direction: .right) {
                    let rightTile = tiles[index(for: rightNeighbor.row, column: rightNeighbor.column)]
                    
                    // If the right neighbor has the same value, a merge is possible.
                    if rightTile?.value == currentTile?.value {
                        return true
                    }
                }
                
                // --- Check bottom neighbor ---
                if let bottomNeighbor = neighbor(ofRow: row, column: column, direction: .down) {
                    let bottomTile = tiles[index(for: bottomNeighbor.row, column: bottomNeighbor.column)]
                    
                    // If the bottom neighbor has the same value, a merge is possible.
                    if bottomTile?.value == currentTile?.value {
                        return true
                    }
                }
            }
        }
        
        // 3️⃣ No empty cells and no mergeable neighbors → no moves left.
        return false
    }

    func tile(at position: BoardPosition) -> GameTile? {
        tiles[position.index(in: size)]
    }

    mutating func reset(initialTiles: Int = 2) {
        var generator = SystemRandomNumberGenerator()
        reset(initialTiles: initialTiles, using: &generator)
    }

    mutating func reset<G: RandomNumberGenerator>(initialTiles: Int = 2, using generator: inout G) {
        tiles = Array(repeating: nil, count: size * size)
        score = 0
        highestValue = 0
        let spawnCount = min(initialTiles, tiles.count)
        for _ in 0..<spawnCount {
            _ = spawnTile(using: &generator)
        }
    }

    @discardableResult
    mutating func move(_ direction: MoveDirection) -> MoveResult {
        var generator = SystemRandomNumberGenerator()
        return move(direction, using: &generator)
    }

    @discardableResult
    mutating func move<G: RandomNumberGenerator>(_ direction: MoveDirection, using generator: inout G) -> MoveResult {
        let previousTiles = tiles
        var totalScoreGained = 0

        for line in lines(for: direction) {
            let (updated, scoreGained) = collapse(line: line, reversing: shouldReverse(direction))
            totalScoreGained += scoreGained
            for (offset, position) in line.enumerated() {
                tiles[position.index(in: size)] = updated[offset]
            }
        }

        let boardChanged = tiles != previousTiles
        score += totalScoreGained
        highestValue = max(highestValue, tiles.compactMap { $0?.value }.max() ?? 0)

        let spawn = boardChanged ? spawnTile(using: &generator) : nil
        let didWin = isWin
        let gameOver = !didWin && !hasMoves

        return MoveResult(
            didMove: boardChanged,
            scoreGained: totalScoreGained,
            spawnedTile: spawn,
            didWin: didWin,
            isGameOver: gameOver
        )
    }

    func rows() -> [[GameTile?]] {
        stride(from: 0, to: tiles.count, by: size).map { start in
            Array(tiles[start..<start + size])
        }
    }

    private mutating func spawnTile<G: RandomNumberGenerator>(using generator: inout G) -> MoveResult.Spawn? {
        let emptyPositions = availablePositions()
        guard !emptyPositions.isEmpty else {
            return nil
        }

        let index = Int.random(in: 0..<emptyPositions.count, using: &generator)
        let position = emptyPositions[index]
        let value = Double.random(in: 0..<1, using: &generator) < 0.9 ? 2 : 4
        let tile = GameTile(value: value)
        tiles[position.index(in: size)] = tile
        highestValue = max(highestValue, value)

        return MoveResult.Spawn(position: position, tile: tile)
    }

    private func index(for row: Int, column: Int) -> Int {
        BoardPosition(row: row, column: column).index(in: size)
    }

    private func availablePositions() -> [BoardPosition] {
        var positions: [BoardPosition] = []
        for row in 0..<size {
            for column in 0..<size {
                let idx = index(for: row, column: column)
                if tiles[idx] == nil {
                    positions.append(BoardPosition(row: row, column: column))
                }
            }
        }
        return positions
    }

    private func lines(for direction: MoveDirection) -> [[BoardPosition]] {
        switch direction {
        case .left, .right:
            return (0..<size).map { row in
                (0..<size).map { column in
                    BoardPosition(row: row, column: column)
                }
            }
        case .up, .down:
            return (0..<size).map { column in
                (0..<size).map { row in
                    BoardPosition(row: row, column: column)
                }
            }
        }
    }

    private func shouldReverse(_ direction: MoveDirection) -> Bool {
        switch direction {
        case .right, .down:
            return true
        case .left, .up:
            return false
        }
    }

    private mutating func collapse(line: [BoardPosition], reversing: Bool) -> ([GameTile?], Int) {
        var workingLine = line
        if reversing {
            workingLine.reverse()
        }

        let currentTiles = workingLine.map { tiles[$0.index(in: size)] }
        var compacted = currentTiles.compactMap { $0 }
        var result: [GameTile?] = []
        var gainedScore = 0
        var skipNext = false

        for (index, tile) in compacted.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }

            if index + 1 < compacted.count && compacted[index + 1].value == tile.value {
                let mergedValue = tile.value * 2
                let mergedTile = GameTile(value: mergedValue)
                result.append(mergedTile)
                gainedScore += mergedValue
                skipNext = true
            } else {
                result.append(tile)
            }
        }

        while result.count < size {
            result.append(nil)
        }

        if reversing {
            result.reverse()
        }

        let changed = !result.elementsEqual(line.map { tiles[$0.index(in: size)] }, by: { lhs, rhs in
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case let (lhsTile?, rhsTile?):
                return lhsTile.id == rhsTile.id && lhsTile.value == rhsTile.value
            default:
                return false
            }
        })

        if !changed {
            return (line.map { tiles[$0.index(in: size)] }, 0)
        }

        return (result, gainedScore)
    }

    private func neighbor(ofRow row: Int, column: Int, direction: MoveDirection) -> BoardPosition? {
        switch direction {
        case .left:
            guard column > 0 else { return nil }
            return BoardPosition(row: row, column: column - 1)
        case .right:
            guard column < size - 1 else { return nil }
            return BoardPosition(row: row, column: column + 1)
        case .up:
            guard row > 0 else { return nil }
            return BoardPosition(row: row - 1, column: column)
        case .down:
            guard row < size - 1 else { return nil }
            return BoardPosition(row: row + 1, column: column)
        }
    }
}

#if DEBUG
extension GameBoard {
    mutating func setTileForTesting(_ tile: GameTile?, at position: BoardPosition) {
        tiles[position.index(in: size)] = tile
    }

    mutating func setScoreForTesting(_ newScore: Int) {
        score = newScore
    }

    mutating func setHighestValueForTesting(_ value: Int) {
        highestValue = value
    }
}
#endif
