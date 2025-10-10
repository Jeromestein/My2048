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
    @Published private(set) var bestScore: Int

    var score: Int {
        board.score
    }

    var highestTile: Int {
        board.highestValue
    }

    var rows: [[GameTile?]] {
        board.rows()
    }

    var canContinue: Bool {
        status == .won && !hasContinuedAfterWin
    }

    private let initialTileCount: Int
    private var hasContinuedAfterWin = false
    private let persistence: ScorePersistence
    private let persistenceKey: String

    init(
        boardSize: Int = 4,
        targetValue: Int = 2048,
        initialTiles: Int = 2,
        persistence: ScorePersistence = UserDefaultsScorePersistence(),
        persistenceKey: String = "bestScore"
    ) {
        self.initialTileCount = max(0, min(initialTiles, boardSize * boardSize))
        self.persistence = persistence
        self.persistenceKey = persistenceKey

        var startingBoard = GameBoard(size: boardSize, targetValue: targetValue)
        startingBoard.reset(initialTiles: self.initialTileCount)

        self.board = startingBoard
        self.status = startingBoard.isWin ? .won : .playing
        self.lastMove = nil

        let persistedBest = persistence.loadBestScore(forKey: persistenceKey)
        self.bestScore = max(persistedBest, startingBoard.score)
        persistBestScoreIfNeeded()
    }

    init(
        board: GameBoard,
        persistence: ScorePersistence = UserDefaultsScorePersistence(),
        persistenceKey: String = "bestScore"
    ) {
        self.initialTileCount = 2
        self.persistence = persistence
        self.persistenceKey = persistenceKey
        self.board = board
        self.status = board.isWin ? .won : .playing
        self.lastMove = nil
        let persistedBest = persistence.loadBestScore(forKey: persistenceKey)
        self.bestScore = max(persistedBest, board.score)
        persistBestScoreIfNeeded()
    }

    func move(_ direction: MoveDirection) {
        guard status == .playing else { return }

        var workingBoard = board
        let result = workingBoard.move(direction)

        lastMove = result
        guard result.didMove else { return }

        board = workingBoard
        updateBestScoreIfNeeded()
        updateStatus(with: result)
    }

    func restart() {
        var newBoard = GameBoard(size: board.size, targetValue: board.targetValue)
        newBoard.reset(initialTiles: initialTileCount)
        board = newBoard
        status = newBoard.isWin ? .won : .playing
        lastMove = nil
        hasContinuedAfterWin = false
        updateBestScoreIfNeeded()
    }

    func restart<G: RandomNumberGenerator>(using generator: inout G) {
        var newBoard = GameBoard(size: board.size, targetValue: board.targetValue)
        newBoard.reset(initialTiles: initialTileCount, using: &generator)
        board = newBoard
        status = newBoard.isWin ? .won : .playing
        lastMove = nil
        hasContinuedAfterWin = false
        updateBestScoreIfNeeded()
    }

    func move<G: RandomNumberGenerator>(_ direction: MoveDirection, using generator: inout G) {
        guard status == .playing else { return }

        var workingBoard = board
        let result = workingBoard.move(direction, using: &generator)

        lastMove = result
        guard result.didMove else { return }

        board = workingBoard
        updateBestScoreIfNeeded()
        updateStatus(with: result)
    }

    func continuePlaying() {
        guard status == .won else { return }
        hasContinuedAfterWin = true
        status = .playing
    }

    private func updateStatus(with result: MoveResult) {
        if result.didWin {
            status = hasContinuedAfterWin ? .playing : .won
        } else if result.isGameOver {
            status = .lost
        } else {
            status = .playing
        }
    }

    private func updateBestScoreIfNeeded() {
        if board.score > bestScore {
            bestScore = board.score
            persistBestScoreIfNeeded()
        }
    }

    private func persistBestScoreIfNeeded() {
        persistence.save(bestScore: bestScore, forKey: persistenceKey)
    }
}
