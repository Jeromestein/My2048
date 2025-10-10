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
}
