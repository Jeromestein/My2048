import Combine
import SpriteKit

#if os(macOS)
import AppKit
#endif

final class GameScene: SKScene {

    var store: GameStore? {
        didSet { bindStore() }
    }

    private struct TileSprite {
        let container: SKNode
        let shape: SKShapeNode
        let label: SKLabelNode
    }

    private struct Layout {
        let boardSize: CGFloat
        let tileSize: CGFloat
        let spacing: CGFloat
        let dimension: Int
    }

    // Board + tiles
    private var layout: Layout?
    private let boardBackground = SKShapeNode()
    private let tileLayer = SKNode()
    private var tileSprites: [UUID: TileSprite] = [:]
    private var boardOffsetY: CGFloat = 0

    // HUD
    private let hudLayer = SKNode()
    private let titleLabel = SKLabelNode(text: "2048")
    private let subtitleLabel = SKLabelNode(text: "Join the numbers and get to the 2048 tile!")
    private let scorePanel = SKShapeNode()
    private let bestPanel = SKShapeNode()
    private let restartPanel = SKShapeNode()
    private let scoreTitleLabel = SKLabelNode(text: "SCORE")
    private let scoreValueLabel = SKLabelNode(text: "0")
    private let bestTitleLabel = SKLabelNode(text: "BEST")
    private let bestValueLabel = SKLabelNode(text: "0")
    private let restartLabel = SKLabelNode(text: "New Game")

    // Status overlay
    private let statusOverlay = SKNode()
    private let statusBackground = SKShapeNode()
    private let statusTitleLabel = SKLabelNode(text: "")
    private let statusDetailLabel = SKLabelNode(text: "Tap restart to try again.")

    private var bestScore: Int = 0
    private var lastRenderedStatus: GameStore.Status?
    private var panelSize: CGSize = .zero

    private var cancellables: Set<AnyCancellable> = []
    private var touchStartLocation: CGPoint?
    private var restartTrackingTouch = false
    private var restartTouchInside = false

    private let restartButtonColor = SKColor(red: 0.64, green: 0.53, blue: 0.44, alpha: 1.0)
    private let restartButtonHighlightColor = SKColor(red: 0.71, green: 0.58, blue: 0.48, alpha: 1.0)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class func makeScene(size: CGSize, store: GameStore) -> GameScene {
        let scene = GameScene(size: size)
        scene.store = store
        return scene
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0)
        setupBoardIfNeeded()
        setupHUDIfNeeded()
        updateLayout()
        syncBoard(animated: false)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateLayout()
        syncBoard(animated: false)
    }

    private func bindStore() {
        cancellables.removeAll()
        guard let store = store else { return }

        setupBoardIfNeeded()
        setupHUDIfNeeded()
        updateLayout()

        store.$board
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncBoard(animated: true)
            }
            .store(in: &cancellables)

        store.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncBoard(animated: false)
            }
            .store(in: &cancellables)

        syncBoard(animated: false)
    }

    private func setupBoardIfNeeded() {
        if boardBackground.parent == nil {
            boardBackground.lineWidth = 0
            boardBackground.fillColor = SKColor(red: 0.73, green: 0.67, blue: 0.63, alpha: 1.0)
            addChild(boardBackground)
        }

        if tileLayer.parent == nil {
            tileLayer.zPosition = 1
            addChild(tileLayer)
        }
    }

    private func setupHUDIfNeeded() {
        if hudLayer.parent == nil {
            hudLayer.zPosition = 10
            addChild(hudLayer)
        }

        if titleLabel.parent == nil {
            titleLabel.fontName = "AvenirNext-Heavy"
            titleLabel.fontColor = SKColor(red: 0.42, green: 0.36, blue: 0.32, alpha: 1.0)
            titleLabel.horizontalAlignmentMode = .left
            titleLabel.verticalAlignmentMode = .center
            hudLayer.addChild(titleLabel)
        }

        if subtitleLabel.parent == nil {
            subtitleLabel.fontName = "AvenirNext-Medium"
            subtitleLabel.fontColor = SKColor(red: 0.55, green: 0.49, blue: 0.45, alpha: 1.0)
            subtitleLabel.horizontalAlignmentMode = .left
            subtitleLabel.verticalAlignmentMode = .center
            hudLayer.addChild(subtitleLabel)
        }

        if scorePanel.parent == nil {
            configurePanelNode(scorePanel, fillColor: SKColor(red: 0.81, green: 0.75, blue: 0.69, alpha: 1.0))
            configurePanelLabels(title: scoreTitleLabel, value: scoreValueLabel)
            hudLayer.addChild(scorePanel)
            scorePanel.addChild(scoreTitleLabel)
            scorePanel.addChild(scoreValueLabel)
        }

        if bestPanel.parent == nil {
            configurePanelNode(bestPanel, fillColor: SKColor(red: 0.81, green: 0.75, blue: 0.69, alpha: 1.0))
            configurePanelLabels(title: bestTitleLabel, value: bestValueLabel)
            hudLayer.addChild(bestPanel)
            bestPanel.addChild(bestTitleLabel)
            bestPanel.addChild(bestValueLabel)
        }

        if restartPanel.parent == nil {
            configurePanelNode(restartPanel, fillColor: restartButtonColor)
            restartLabel.fontName = "AvenirNext-Bold"
            restartLabel.fontColor = .white
            restartLabel.horizontalAlignmentMode = .center
            restartLabel.verticalAlignmentMode = .center
            restartPanel.name = "restartPanel"
            hudLayer.addChild(restartPanel)
            restartPanel.addChild(restartLabel)
        }

        if statusOverlay.parent == nil {
            statusOverlay.zPosition = 30
            statusOverlay.isHidden = true
            statusOverlay.alpha = 0

            statusBackground.fillColor = SKColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.55)
            statusBackground.strokeColor = .clear

            statusTitleLabel.fontName = "AvenirNext-Heavy"
            statusTitleLabel.fontColor = .white
            statusTitleLabel.horizontalAlignmentMode = .center
            statusTitleLabel.verticalAlignmentMode = .center

            statusDetailLabel.fontName = "AvenirNext-Regular"
            statusDetailLabel.fontColor = .white
            statusDetailLabel.horizontalAlignmentMode = .center
            statusDetailLabel.verticalAlignmentMode = .center

            statusOverlay.addChild(statusBackground)
            statusOverlay.addChild(statusTitleLabel)
            statusOverlay.addChild(statusDetailLabel)
            hudLayer.addChild(statusOverlay)
        }
    }

    private func configurePanelNode(_ node: SKShapeNode, fillColor: SKColor) {
        node.fillColor = fillColor
        node.strokeColor = .clear
        node.zPosition = 1
        node.lineWidth = 0
    }

    private func configurePanelLabels(title: SKLabelNode, value: SKLabelNode) {
        title.fontName = "AvenirNext-DemiBold"
        title.fontColor = SKColor(red: 0.98, green: 0.95, blue: 0.92, alpha: 1.0)
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center

        value.fontName = "AvenirNext-Bold"
        value.fontColor = .white
        value.verticalAlignmentMode = .center
        value.horizontalAlignmentMode = .center
    }

    private func updateLayout() {
        guard let store = store else { return }
        let dimension = store.board.size
        guard dimension > 0 else { return }
        let dimensionCGFloat = CGFloat(dimension)

        let availableLength = min(size.width, size.height) * 0.82
        guard availableLength > 0 else { return }

        let spacing = max(availableLength * 0.04, 8)
        let tileSize = (availableLength - spacing * (dimensionCGFloat + 1)) / dimensionCGFloat
        guard tileSize > 0 else { return }

        let panelWidth = max(tileSize * 1.35, 120)
        let panelHeight = max(tileSize * 0.85, 64)
        panelSize = CGSize(width: panelWidth, height: panelHeight)
        let topMargin: CGFloat = 24
        let bottomMargin: CGFloat = 24

        let titleFontSize = max(tileSize * 0.85, 54)
        titleLabel.fontSize = titleFontSize
        let subtitleFontSize = max(panelHeight * 0.38, 20)
        subtitleLabel.fontSize = subtitleFontSize

        var offset: CGFloat = 0
        let boardSize = availableLength
        let boardTop = boardSize / 2
        let titleTopAboveBoard = spacing + panelHeight / 2 + panelHeight * 0.32 + titleLabel.frame.height / 2
        let scoreTopAboveBoard = spacing + panelHeight
        let headerAboveBoard = max(scoreTopAboveBoard, titleTopAboveBoard)
        let requiredTop = boardTop + headerAboveBoard
        let availableTop = size.height / 2 - topMargin
        if requiredTop > availableTop {
            offset = availableTop - requiredTop
        }

        let boardBottom = offset - boardSize / 2
        let minBottom = -size.height / 2 + bottomMargin
        if boardBottom < minBottom {
            offset += (minBottom - boardBottom)
        }

        boardOffsetY = offset
        layout = Layout(boardSize: boardSize, tileSize: tileSize, spacing: spacing, dimension: dimension)

        let rect = CGRect(
            origin: CGPoint(x: -availableLength / 2, y: -availableLength / 2),
            size: CGSize(width: availableLength, height: availableLength)
        )
        boardBackground.path = CGPath(
            roundedRect: rect,
            cornerWidth: 16,
            cornerHeight: 16,
            transform: nil
        )
        boardBackground.position = CGPoint(x: 0, y: boardOffsetY)

        updateGridBackground()
        updateHUDLayout()
    }

    private func updateHUDLayout() {
        guard let layout = layout else { return }

        let panelWidth = max(layout.tileSize * 1.35, 120)
        let panelHeight = max(layout.tileSize * 0.85, 64)
        panelSize = CGSize(width: panelWidth, height: panelHeight)

        let panelRect = CGRect(x: -panelWidth / 2, y: -panelHeight / 2, width: panelWidth, height: panelHeight)
        let panelPath = CGPath(roundedRect: panelRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        scorePanel.path = panelPath
        bestPanel.path = panelPath
        restartPanel.path = panelPath

        layoutPanelLabels(title: scoreTitleLabel, value: scoreValueLabel, panelHeight: panelHeight)
        layoutPanelLabels(title: bestTitleLabel, value: bestValueLabel, panelHeight: panelHeight)

        let boardTop = boardBackground.frame.maxY
        let controlsY = boardTop + layout.spacing + panelHeight / 2
        let boardRight = layout.boardSize / 2
        let buttonSpacing = layout.spacing * 0.6

        let restartX = boardRight - panelWidth / 2
        let bestX = restartX - panelWidth - buttonSpacing
        let scoreX = bestX - panelWidth - buttonSpacing

        scorePanel.position = CGPoint(x: scoreX, y: controlsY)
        bestPanel.position = CGPoint(x: bestX, y: controlsY)
        restartPanel.position = CGPoint(x: restartX, y: controlsY)

        restartLabel.fontSize = panelHeight * 0.34
        restartLabel.position = .zero

        let titleFontSize = max(layout.tileSize * 0.85, 54)
        titleLabel.fontSize = titleFontSize
        let subtitleFontSize = max(panelHeight * 0.38, 20)
        subtitleLabel.fontSize = subtitleFontSize

        let headerLeftX = -layout.boardSize / 2
        let titleYOffset = panelHeight * 0.32
        titleLabel.position = CGPoint(x: headerLeftX, y: controlsY + titleYOffset)

        let scoreboardBottom = controlsY - panelHeight / 2
        let subtitleGap = layout.spacing * 0.35
        let minSubtitleY = boardTop + subtitleLabel.frame.height / 2 + 6
        let subtitleTarget = scoreboardBottom - subtitleGap - subtitleLabel.frame.height / 2
        let subtitleY = max(minSubtitleY, subtitleTarget)
        subtitleLabel.position = CGPoint(x: headerLeftX, y: subtitleY)

        let overlayWidth = layout.boardSize * 0.8
        let overlayHeight = layout.boardSize * 0.38
        let overlayRect = CGRect(x: -overlayWidth / 2, y: -overlayHeight / 2, width: overlayWidth, height: overlayHeight)
        statusBackground.path = CGPath(roundedRect: overlayRect, cornerWidth: 20, cornerHeight: 20, transform: nil)
        statusOverlay.position = CGPoint(x: 0, y: boardOffsetY)
        statusTitleLabel.fontSize = overlayHeight * 0.28
        statusTitleLabel.position = CGPoint(x: 0, y: overlayHeight * 0.1)
        statusDetailLabel.fontSize = overlayHeight * 0.16
        statusDetailLabel.position = CGPoint(x: 0, y: -overlayHeight * 0.18)
    }

    private func layoutPanelLabels(title: SKLabelNode, value: SKLabelNode, panelHeight: CGFloat) {
        title.fontSize = panelHeight * 0.26
        value.fontSize = panelHeight * 0.45
        title.position = CGPoint(x: 0, y: panelHeight * 0.2)
        value.position = CGPoint(x: 0, y: -panelHeight * 0.12)
    }

    private func updateGridBackground() {
        guard let layout = layout else { return }

        boardBackground.removeAllChildren()
        for row in 0..<layout.dimension {
            for column in 0..<layout.dimension {
                let placeholder = SKShapeNode(rectOf: CGSize(width: layout.tileSize, height: layout.tileSize), cornerRadius: 12)
                placeholder.fillColor = SKColor(red: 0.80, green: 0.75, blue: 0.71, alpha: 1.0)
                placeholder.strokeColor = .clear
                placeholder.position = localPositionFor(row: row, column: column, layout: layout)
                boardBackground.addChild(placeholder)
            }
        }
    }

    private func syncBoard(animated: Bool) {
        guard let store = store else { return }
        refreshHUD()
        guard let layout = layout else { return }

        var seen: Set<UUID> = []
        for (rowIndex, row) in store.rows.enumerated() {
            for (columnIndex, tile) in row.enumerated() {
                guard let tile = tile else { continue }
                seen.insert(tile.id)
                let targetPosition = positionFor(row: rowIndex, column: columnIndex, layout: layout)

                if let sprite = tileSprites[tile.id] {
                    update(sprite: sprite, with: tile, targetPosition: targetPosition, animated: animated)
                } else {
                    let sprite = makeSprite(for: tile, tileSize: layout.tileSize)
                    sprite.container.position = targetPosition
                    tileLayer.addChild(sprite.container)
                    tileSprites[tile.id] = sprite
                    let spawnAnimation = SKAction.sequence([
                        SKAction.scale(to: 0.6, duration: 0),
                        SKAction.scale(to: 1.0, duration: 0.12)
                    ])
                    sprite.container.run(spawnAnimation)
                }
            }
        }

        let obsoleteIds = tileSprites.keys.filter { !seen.contains($0) }
        for id in obsoleteIds {
            if let sprite = tileSprites[id] {
                sprite.container.removeAllActions()
                let fade = SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.1),
                    SKAction.removeFromParent()
                ])
                sprite.container.run(fade)
            }
            tileSprites.removeValue(forKey: id)
        }
    }

    private func refreshHUD() {
        guard let store = store else { return }
        bestScore = max(bestScore, store.score)
        scoreValueLabel.text = "\(store.score)"
        bestValueLabel.text = "\(bestScore)"
        updateStatusOverlay(status: store.status)
    }

    private func updateStatusOverlay(status: GameStore.Status) {
        guard status != lastRenderedStatus else { return }
        lastRenderedStatus = status

        switch status {
        case .playing:
            hideStatusOverlay()
        case .won:
            statusTitleLabel.text = "You Win!"
            statusDetailLabel.text = "Tap restart to play again."
            statusBackground.fillColor = SKColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.92)
            presentStatusOverlay()
        case .lost:
            statusTitleLabel.text = "Game Over"
            statusDetailLabel.text = "Tap restart to try again."
            statusBackground.fillColor = SKColor(red: 0.54, green: 0.31, blue: 0.27, alpha: 0.92)
            presentStatusOverlay()
        }
    }

    private func presentStatusOverlay() {
        statusOverlay.removeAllActions()
        if statusOverlay.isHidden {
            statusOverlay.alpha = 0
            statusOverlay.isHidden = false
        }
        let fade = SKAction.fadeIn(withDuration: 0.18)
        statusOverlay.run(fade)
    }

    private func hideStatusOverlay() {
        guard !statusOverlay.isHidden else { return }
        statusOverlay.removeAllActions()
        let fade = SKAction.fadeOut(withDuration: 0.18)
        statusOverlay.run(fade) { [weak self] in
            self?.statusOverlay.isHidden = true
        }
    }

    private func makeSprite(for tile: GameTile, tileSize: CGFloat) -> TileSprite {
        let container = SKNode()
        container.zPosition = 1
        let shape = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize), cornerRadius: 12)
        shape.fillColor = fillColor(for: tile.value)
        shape.strokeColor = .clear

        let label = SKLabelNode(text: "\(tile.value)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = fontSize(for: tile.value, tileSize: tileSize)
        label.fontColor = textColor(for: tile.value)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        container.addChild(shape)
        container.addChild(label)

        return TileSprite(container: container, shape: shape, label: label)
    }

    private func update(sprite: TileSprite, with tile: GameTile, targetPosition: CGPoint, animated: Bool) {
        sprite.shape.fillColor = fillColor(for: tile.value)
        sprite.label.text = "\(tile.value)"
        sprite.label.fontColor = textColor(for: tile.value)
        if let layout = layout {
            sprite.label.fontSize = fontSize(for: tile.value, tileSize: layout.tileSize)
        }

        sprite.container.removeAllActions()
        if animated {
            let move = SKAction.move(to: targetPosition, duration: 0.08)
            move.timingMode = .easeOut
            sprite.container.run(move)
        } else {
            sprite.container.position = targetPosition
        }
    }

    private func localPositionFor(row: Int, column: Int, layout: Layout) -> CGPoint {
        let origin = -layout.boardSize / 2 + layout.spacing + layout.tileSize / 2
        let x = origin + CGFloat(column) * (layout.tileSize + layout.spacing)
        let y = origin + CGFloat(layout.dimension - 1 - row) * (layout.tileSize + layout.spacing)
        return CGPoint(x: x, y: y)
    }

    private func positionFor(row: Int, column: Int, layout: Layout) -> CGPoint {
        let local = localPositionFor(row: row, column: column, layout: layout)
        return CGPoint(x: local.x, y: local.y + boardOffsetY)
    }

    private func fillColor(for value: Int) -> SKColor {
        switch value {
        case 2: return SKColor(red: 0.93, green: 0.89, blue: 0.85, alpha: 1.0)
        case 4: return SKColor(red: 0.93, green: 0.88, blue: 0.78, alpha: 1.0)
        case 8: return SKColor(red: 0.95, green: 0.69, blue: 0.47, alpha: 1.0)
        case 16: return SKColor(red: 0.97, green: 0.58, blue: 0.39, alpha: 1.0)
        case 32: return SKColor(red: 0.96, green: 0.49, blue: 0.38, alpha: 1.0)
        case 64: return SKColor(red: 0.96, green: 0.37, blue: 0.23, alpha: 1.0)
        case 128: return SKColor(red: 0.93, green: 0.81, blue: 0.45, alpha: 1.0)
        case 256: return SKColor(red: 0.93, green: 0.80, blue: 0.38, alpha: 1.0)
        case 512: return SKColor(red: 0.93, green: 0.78, blue: 0.31, alpha: 1.0)
        case 1024: return SKColor(red: 0.93, green: 0.76, blue: 0.24, alpha: 1.0)
        case 2048: return SKColor(red: 0.93, green: 0.74, blue: 0.17, alpha: 1.0)
        default: return SKColor(red: 0.09, green: 0.66, blue: 0.83, alpha: 1.0)
        }
    }

    private func textColor(for value: Int) -> SKColor {
        value <= 4 ? SKColor(red: 0.47, green: 0.43, blue: 0.40, alpha: 1.0) : .white
    }

    private func fontSize(for value: Int, tileSize: CGFloat) -> CGFloat {
        let base = tileSize * 0.45
        if value >= 1024 {
            return base * 0.7
        } else if value >= 128 {
            return base * 0.8
        } else {
            return max(base, 18)
        }
    }

    private func restartButtonContains(sceneLocation: CGPoint) -> Bool {
        guard restartPanel.parent != nil else { return false }
        let hudPoint = hudLayer.convert(sceneLocation, from: self)
        return restartPanel.contains(hudPoint)
    }

    private func setRestartButtonHighlighted(_ highlighted: Bool) {
        let targetColor = highlighted ? restartButtonHighlightColor : restartButtonColor
        if restartPanel.fillColor != targetColor {
            restartPanel.fillColor = targetColor
        }
    }

    private func triggerRestart() {
        guard let store = store else { return }
        bestScore = max(bestScore, store.score)
        store.restart()
    }
}

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if restartButtonContains(sceneLocation: location) {
            restartTrackingTouch = true
            restartTouchInside = true
            setRestartButtonHighlighted(true)
            touchStartLocation = nil
        } else {
            restartTrackingTouch = false
            restartTouchInside = false
            touchStartLocation = location
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard restartTrackingTouch, let location = touches.first?.location(in: self) else { return }
        let inside = restartButtonContains(sceneLocation: location)
        if inside != restartTouchInside {
            restartTouchInside = inside
            setRestartButtonHighlighted(inside)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else {
            resetTouchTracking()
            return
        }

        if restartTrackingTouch {
            let inside = restartButtonContains(sceneLocation: location)
            setRestartButtonHighlighted(false)
            restartTrackingTouch = false
            restartTouchInside = false
            if inside {
                triggerRestart()
            }
            return
        }

        guard let start = touchStartLocation else {
            resetTouchTracking()
            return
        }

        let delta = CGPoint(x: location.x - start.x, y: location.y - start.y)
        handleSwipe(delta: delta)
        resetTouchTracking()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        setRestartButtonHighlighted(false)
        resetTouchTracking()
    }
}
#endif

#if os(macOS)
extension GameScene {

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        if restartButtonContains(sceneLocation: location) {
            restartTrackingTouch = true
            restartTouchInside = true
            setRestartButtonHighlighted(true)
            touchStartLocation = nil
        } else {
            restartTrackingTouch = false
            restartTouchInside = false
            touchStartLocation = location
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard restartTrackingTouch else { return }
        let location = event.location(in: self)
        let inside = restartButtonContains(sceneLocation: location)
        if inside != restartTouchInside {
            restartTouchInside = inside
            setRestartButtonHighlighted(inside)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let location = event.location(in: self)
        if restartTrackingTouch {
            let inside = restartButtonContains(sceneLocation: location)
            setRestartButtonHighlighted(false)
            restartTrackingTouch = false
            restartTouchInside = false
            if inside {
                triggerRestart()
            }
            return
        }

        guard let start = touchStartLocation else {
            resetTouchTracking()
            return
        }
        let delta = CGPoint(x: location.x - start.x, y: location.y - start.y)
        handleSwipe(delta: delta)
        resetTouchTracking()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123:
            store?.move(.left)
        case 124:
            store?.move(.right)
        case 125:
            store?.move(.down)
        case 126:
            store?.move(.up)
        case 53:
            resetTouchTracking()
            super.keyDown(with: event)
        case 49:
            triggerRestart()
        default:
            super.keyDown(with: event)
        }
    }
}
#endif

private extension GameScene {
    func handleSwipe(delta: CGPoint) {
        guard let store = store, store.status == .playing else { return }
        let threshold: CGFloat = 24
        let absX = abs(delta.x)
        let absY = abs(delta.y)
        guard max(absX, absY) > threshold else { return }

        if absX > absY {
            store.move(delta.x > 0 ? .right : .left)
        } else {
            store.move(delta.y > 0 ? .up : .down)
        }
    }

    func resetTouchTracking() {
        touchStartLocation = nil
        restartTrackingTouch = false
        restartTouchInside = false
        setRestartButtonHighlighted(false)
    }
}
