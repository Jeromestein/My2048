@testable import My2048Core
import XCTest

final class GameStorePersistenceTests: XCTestCase {

    func testBestScorePersistsAcrossInstances() {
        let persistence = MemoryScorePersistence()
        let key = "test.bestScore"

        var initialBoard = GameBoard(size: 4, targetValue: 32)
        initialBoard.setScoreForTesting(128)
        let store = GameStore(board: initialBoard, persistence: persistence, persistenceKey: key)
        XCTAssertEqual(store.bestScore, 128)

        var improvedBoard = initialBoard
        improvedBoard.setScoreForTesting(512)
        let secondStore = GameStore(board: improvedBoard, persistence: persistence, persistenceKey: key)
        XCTAssertEqual(secondStore.bestScore, 512)

        let restored = GameStore(boardSize: 4, targetValue: 32, initialTiles: 0, persistence: persistence, persistenceKey: key)
        XCTAssertEqual(restored.bestScore, 512)
    }

    func testContinuePlayingClearsWinState() {
        let persistence = MemoryScorePersistence()
        var winningBoard = GameBoard(size: 4, targetValue: 16)
        let winningTile = GameTile(value: 16)
        winningBoard.setTileForTesting(winningTile, at: BoardPosition(row: 0, column: 0))
        winningBoard.setHighestValueForTesting(16)
        winningBoard.setScoreForTesting(320)

        let store = GameStore(board: winningBoard, persistence: persistence, persistenceKey: "test.continue")
        XCTAssertEqual(store.status, .won)

        store.continuePlaying()
        XCTAssertEqual(store.status, .playing)
        XCTAssertFalse(store.canContinue)
        XCTAssertEqual(store.bestScore, 320)

        let persistedStore = GameStore(boardSize: 4, targetValue: 16, persistence: persistence, persistenceKey: "test.continue")
        XCTAssertEqual(persistedStore.bestScore, 320)
    }

    func testNoMovesTriggersGameOver() {
        let persistence = MemoryScorePersistence()
        var fullBoard = GameBoard(size: 4, targetValue: 2048)
        let values = [
            4, 2, 8, 2,
            2, 8, 32, 64,
            32, 128, 512, 128,
            2, 4, 1024, 2048
        ]

        for (index, value) in values.enumerated() {
            let position = BoardPosition(row: index / 4, column: index % 4)
            fullBoard.setTileForTesting(GameTile(value: value), at: position)
        }
        fullBoard.setHighestValueForTesting(values.max() ?? 0)
        fullBoard.setScoreForTesting(1000)

        let store = GameStore(board: fullBoard, persistence: persistence, persistenceKey: "test.gameover")
        XCTAssertEqual(store.status, .playing)

        store.move(.left)
        XCTAssertEqual(store.status, .lost)
    }

    func testContinueThenNoMovesEventuallyLoses() {
        let persistence = MemoryScorePersistence()

        // Board with a win tile but still has an easy merge (two adjacent 4s)
        var boardWithMoves = GameBoard(size: 4, targetValue: 2048)
        let initialValues = [
            4, 4, 2, 2,
            2, 8, 16, 32,
            64, 128, 256, 512,
            1024, 2048, 4, 2
        ]
        for (index, value) in initialValues.enumerated() {
            let position = BoardPosition(row: index / 4, column: index % 4)
            boardWithMoves.setTileForTesting(GameTile(value: value), at: position)
        }
        boardWithMoves.setHighestValueForTesting(2048)
        boardWithMoves.setScoreForTesting(4096)

        let store = GameStore(board: boardWithMoves, persistence: persistence, persistenceKey: "test.continue.stuck")
        XCTAssertEqual(store.status, .won)

        store.continuePlaying()
        XCTAssertEqual(store.status, .playing)

        // Now replace the board with a stuck configuration and attempt a move
        var stuckBoard = boardWithMoves
        let stuckValues = [
            4, 16, 8, 4,
            8, 128, 32, 16,
            32, 256, 128, 32,
            4096, 8, 4, 2
        ]
        for (index, value) in stuckValues.enumerated() {
            let position = BoardPosition(row: index / 4, column: index % 4)
            stuckBoard.setTileForTesting(GameTile(value: value), at: position)
        }
        stuckBoard.setHighestValueForTesting(4096)
        stuckBoard.setScoreForTesting(48016)

        store.setBoardForTesting(stuckBoard)
        store.move(.left)
        XCTAssertEqual(store.status, .lost)
    }
}
