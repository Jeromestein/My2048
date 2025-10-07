import Combine
import Foundation

final class GameStore: ObservableObject {

    enum Status {
        case playing
        case won
        case lost
    }

    @Published private(set) var board: GameBoard
    @Published private(set) var status: Status
    @Published private(set) var lastMove: MoveResult?

    var score: Int {
        board.score
    }

    var highestTile: Int {
        board.highestValue
    }

    var rows: [[GameTile?]] {
        board.rows()
    }

    private let initialTileCount: Int

    init(boardSize: Int = 4, targetValue: Int = 2048, initialTiles: Int = 2) {
        self.initialTileCount = max(0, min(initialTiles, boardSize * boardSize))
        var startingBoard = GameBoard(size: boardSize, targetValue: targetValue)
        startingBoard.reset(initialTiles: self.initialTileCount)

        self.board = startingBoard
        self.status = startingBoard.isWin ? .won : .playing
        self.lastMove = nil
    }

    func move(_ direction: MoveDirection) {
        guard status == .playing else {
            return
        }

        var workingBoard = board
        let result = workingBoard.move(direction)

        lastMove = result
        guard result.didMove else {
            return
        }

        board = workingBoard
        updateStatus(with: result)
    }

    func restart() {
        var newBoard = GameBoard(size: board.size, targetValue: board.targetValue)
        newBoard.reset(initialTiles: initialTileCount)
        board = newBoard
        status = newBoard.isWin ? .won : .playing
        lastMove = nil
    }

    func restart<G: RandomNumberGenerator>(using generator: inout G) {
        var newBoard = GameBoard(size: board.size, targetValue: board.targetValue)
        newBoard.reset(initialTiles: initialTileCount, using: &generator)
        board = newBoard
        status = newBoard.isWin ? .won : .playing
        lastMove = nil
    }

    func move<G: RandomNumberGenerator>(_ direction: MoveDirection, using generator: inout G) {
        guard status == .playing else {
            return
        }

        var workingBoard = board
        let result = workingBoard.move(direction, using: &generator)

        lastMove = result
        guard result.didMove else {
            return
        }

        board = workingBoard
        updateStatus(with: result)
    }

    private func updateStatus(with result: MoveResult) {
        if result.didWin {
            status = .won
        } else if result.isGameOver {
            status = .lost
        } else {
            status = .playing
        }
    }
}
