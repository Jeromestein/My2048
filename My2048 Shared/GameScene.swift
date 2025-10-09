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

    private struct HeaderMetrics {
        let spacing: CGFloat
        let tileSize: CGFloat
        let basePanelWidth: CGFloat
        let panelHeight: CGFloat
        let scoreboardGap: CGFloat
        let scoreboardSpacing: CGFloat
        let minScoreboardSpacing: CGFloat
        let panelHorizontalPadding: CGFloat
        let titleFont: CGFloat
        let subtitleFont: CGFloat
        let titleSubtitleGap: CGFloat
        let subtitlePanelGap: CGFloat
        let headerHeight: CGFloat
    }

    // Board + tiles
    private var layout: Layout?
    private let boardBackground = SKShapeNode()
    private let tileLayer = SKNode()
    private var tileSprites: [UUID: TileSprite] = [:]
    private var boardOffsetY: CGFloat = 0
    private var headerMetrics: HeaderMetrics?
    private var topContentMargin: CGFloat = 0
    private var horizontalContentMargin: CGFloat = 0

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
    private let continueButton = SKShapeNode()
    private let continueLabel = SKLabelNode(text: "Keep Going")

    private var lastRenderedStatus: GameStore.Status?
    private var lastRenderedCanContinue: Bool = false
    private var panelSize: CGSize = .zero

    private var cancellables: Set<AnyCancellable> = []
    private var touchStartLocation: CGPoint?
    private var restartTrackingTouch = false
    private var restartTouchInside = false
    private var continueTrackingTouch = false
    private var continueTouchInside = false

    private let restartButtonColor = SKColor(red: 0.64, green: 0.53, blue: 0.44, alpha: 1.0)
    private let restartButtonHighlightColor = SKColor(red: 0.71, green: 0.58, blue: 0.48, alpha: 1.0)
    private let continueButtonColor = SKColor(red: 0.97, green: 0.80, blue: 0.28, alpha: 1.0)
    private let continueButtonHighlightColor = SKColor(red: 0.98, green: 0.84, blue: 0.40, alpha: 1.0)

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
            configurePanelNode(continueButton, fillColor: continueButtonColor)
            continueButton.zPosition = 1
            continueLabel.fontName = "AvenirNext-Bold"
            continueLabel.fontColor = SKColor(red: 0.48, green: 0.34, blue: 0.27, alpha: 1.0)
            continueLabel.verticalAlignmentMode = .center
            continueLabel.horizontalAlignmentMode = .center
            statusOverlay.addChild(continueButton)
            continueButton.addChild(continueLabel)
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

    private func computeHeaderMetrics(boardSize: CGFloat, dimension: CGFloat) -> HeaderMetrics {
        let spacing = max(boardSize * 0.04, 8)
        let tileSize = (boardSize - spacing * (dimension + 1)) / dimension
        let panelHeight = max(tileSize * 0.82, 58)
        let panelWidth = max(panelHeight * 1.32, 110)
        let panelHorizontalPadding = max(panelHeight * 0.5, 26)
        let scoreboardGap = max(spacing * 0.78, 16)
        let scoreboardSpacing = max(spacing * 0.55, 14)
        let minScoreboardSpacing = max(spacing * 0.35, 10)
        let titleFont = max(boardSize * 0.18, 56)
        let subtitleFont = max(panelHeight * 0.36, 20)
        let titleSubtitleGap = max(spacing * 0.33, 10)
        let subtitlePanelGap = max(spacing * 0.28, 10)
        let headerHeight = titleFont + titleSubtitleGap + subtitleFont + subtitlePanelGap + panelHeight + scoreboardGap
        return HeaderMetrics(
            spacing: spacing,
            tileSize: tileSize,
            basePanelWidth: panelWidth,
            panelHeight: panelHeight,
            scoreboardGap: scoreboardGap,
            scoreboardSpacing: scoreboardSpacing,
            minScoreboardSpacing: minScoreboardSpacing,
            panelHorizontalPadding: panelHorizontalPadding,
            titleFont: titleFont,
            subtitleFont: subtitleFont,
            titleSubtitleGap: titleSubtitleGap,
            subtitlePanelGap: subtitlePanelGap,
            headerHeight: headerHeight
        )
    }

    private func updatePanelPath(_ node: SKShapeNode, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) {
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        node.path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    }

    private func updateLayout() {
        guard let store = store else { return }
        let dimension = store.board.size
        guard dimension > 0 else { return }
        let dimensionCGFloat = CGFloat(dimension)

        horizontalContentMargin = max(size.width * 0.05, 32)
        topContentMargin = max(size.height * 0.05, 36)
        let bottomMargin = max(size.height * 0.05, 36)

        let maxBoardWidth = size.width - horizontalContentMargin * 2
        guard maxBoardWidth > 0 else { return }

        var boardSize = maxBoardWidth
        var metrics = computeHeaderMetrics(boardSize: boardSize, dimension: dimensionCGFloat)
        let availableHeight = size.height - topContentMargin - bottomMargin
        guard availableHeight > 0 else { return }

        for _ in 0..<6 {
            let totalHeight = metrics.headerHeight + boardSize
            if totalHeight > availableHeight || metrics.tileSize <= 0 {
                let ratio = max(0.55, min(0.95, availableHeight / max(totalHeight, 1)))
                boardSize = min(maxBoardWidth, boardSize * ratio)
                if boardSize <= 0 { return }
                metrics = computeHeaderMetrics(boardSize: boardSize, dimension: dimensionCGFloat)
            } else {
                break
            }
        }

        if metrics.tileSize <= 0 || boardSize <= 0 { return }

        headerMetrics = metrics
        layout = Layout(boardSize: boardSize, tileSize: metrics.tileSize, spacing: metrics.spacing, dimension: dimension)

        let boardTop = size.height / 2 - topContentMargin - metrics.headerHeight
        boardOffsetY = boardTop - boardSize / 2

        let rect = CGRect(
            origin: CGPoint(x: -boardSize / 2, y: -boardSize / 2),
            size: CGSize(width: boardSize, height: boardSize)
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
        guard let layout = layout, let metrics = headerMetrics else { return }

        panelSize = CGSize(width: metrics.basePanelWidth, height: metrics.panelHeight)

        layoutPanelLabels(title: scoreTitleLabel, value: scoreValueLabel, panelHeight: metrics.panelHeight)
        layoutPanelLabels(title: bestTitleLabel, value: bestValueLabel, panelHeight: metrics.panelHeight)

        let scoreWidth = max(metrics.basePanelWidth, max(scoreTitleLabel.frame.width, scoreValueLabel.frame.width) + metrics.panelHorizontalPadding)
        let bestWidth = max(metrics.basePanelWidth, max(bestTitleLabel.frame.width, bestValueLabel.frame.width) + metrics.panelHorizontalPadding)

        let restartTextWidth = max(restartLabel.frame.width, restartLabel.frame.height)
        let restartWidth = max(metrics.basePanelWidth, restartTextWidth + metrics.panelHorizontalPadding)

        updatePanelPath(scorePanel, width: scoreWidth, height: metrics.panelHeight, cornerRadius: 14)
        updatePanelPath(bestPanel, width: bestWidth, height: metrics.panelHeight, cornerRadius: 14)
        updatePanelPath(restartPanel, width: restartWidth, height: metrics.panelHeight, cornerRadius: 16)

        let boardTop = boardOffsetY + layout.boardSize / 2
        let scoreboardRowY = boardTop + metrics.scoreboardGap + metrics.panelHeight / 2

        let boardLeft = -layout.boardSize / 2
        let boardRight = layout.boardSize / 2

        var spacing = metrics.scoreboardSpacing
        let totalWidths = scoreWidth + bestWidth + restartWidth
        var totalRowWidth = totalWidths + spacing * 2
        if totalRowWidth > layout.boardSize {
            let availableSpacing = layout.boardSize - totalWidths
            let clampedSpacing = max(metrics.minScoreboardSpacing, availableSpacing / 2)
            spacing = clampedSpacing
            totalRowWidth = totalWidths + spacing * 2
        }

        let rowStart = boardLeft + max(0, (layout.boardSize - totalRowWidth) / 2)
        let scoreX = rowStart + scoreWidth / 2
        let bestX = scoreX + scoreWidth / 2 + spacing + bestWidth / 2
        let restartX = bestX + bestWidth / 2 + spacing + restartWidth / 2

        scorePanel.position = CGPoint(x: scoreX, y: scoreboardRowY)
        bestPanel.position = CGPoint(x: bestX, y: scoreboardRowY)
        restartPanel.position = CGPoint(x: restartX, y: scoreboardRowY)

        restartLabel.fontSize = metrics.panelHeight * 0.34
        restartLabel.position = .zero

        titleLabel.fontSize = metrics.titleFont
        subtitleLabel.fontSize = metrics.subtitleFont

        let subtitleY = scoreboardRowY + metrics.panelHeight / 2 + metrics.subtitlePanelGap + metrics.subtitleFont / 2
        let titleY = subtitleY + metrics.subtitleFont / 2 + metrics.titleSubtitleGap + metrics.titleFont / 2
        let headerLeftX = boardLeft

        titleLabel.position = CGPoint(x: headerLeftX, y: titleY)
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
        let continueWidth = overlayWidth * 0.46
        let continueHeight = overlayHeight * 0.22
        updatePanelPath(continueButton, width: continueWidth, height: continueHeight, cornerRadius: continueHeight * 0.5)
        continueLabel.fontSize = continueHeight * 0.45
        continueLabel.position = .zero
        continueButton.position = CGPoint(x: 0, y: -overlayHeight * 0.22)
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
        scoreValueLabel.text = "\(store.score)"
        bestValueLabel.text = "\(store.bestScore)"
        updateStatusOverlay(status: store.status, canContinue: store.canContinue)
    }

    private func updateStatusOverlay(status: GameStore.Status, canContinue: Bool) {
        if status == lastRenderedStatus && canContinue == lastRenderedCanContinue {
            return
        }
        lastRenderedStatus = status
        lastRenderedCanContinue = canContinue

        switch status {
        case .playing:
            continueButton.isHidden = true
            setContinueButtonHighlighted(false)
            hideStatusOverlay()
        case .won:
            statusTitleLabel.text = "You Win!"
            statusDetailLabel.text = canContinue ? "Keep going or start a new game." : "Tap restart to play again."
            statusBackground.fillColor = SKColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.92)
            continueButton.isHidden = !canContinue
            setContinueButtonHighlighted(false)
            presentStatusOverlay()
        case .lost:
            statusTitleLabel.text = "Game Over"
            statusDetailLabel.text = "Tap restart to try again."
            statusBackground.fillColor = SKColor(red: 0.54, green: 0.31, blue: 0.27, alpha: 0.92)
            continueButton.isHidden = true
            setContinueButtonHighlighted(false)
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
        store?.restart()
    }

    private func continueButtonContains(sceneLocation: CGPoint) -> Bool {
        guard continueButton.parent != nil else { return false }
        let overlayPoint = statusOverlay.convert(sceneLocation, from: self)
        return continueButton.contains(overlayPoint)
    }

    private func setContinueButtonHighlighted(_ highlighted: Bool) {
        let targetColor = highlighted ? continueButtonHighlightColor : continueButtonColor
        if continueButton.fillColor != targetColor {
            continueButton.fillColor = targetColor
        }
    }

    private func isContinueButtonActive() -> Bool {
        guard let store = store else { return false }
        return store.canContinue && !statusOverlay.isHidden
    }

    private func triggerContinue() {
        store?.continuePlaying()
        setContinueButtonHighlighted(false)
        continueTrackingTouch = false
        continueTouchInside = false
    }
}

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if isContinueButtonActive() && continueButtonContains(sceneLocation: location) {
            continueTrackingTouch = true
            continueTouchInside = true
            setContinueButtonHighlighted(true)
            touchStartLocation = nil
            return
        }
        if restartButtonContains(sceneLocation: location) {
            restartTrackingTouch = true
            restartTouchInside = true
            setRestartButtonHighlighted(true)
            touchStartLocation = nil
        } else {
            restartTrackingTouch = false
            restartTouchInside = false
            if store?.status == .playing {
                touchStartLocation = location
            } else {
                touchStartLocation = nil
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        if continueTrackingTouch {
            let inside = continueButtonContains(sceneLocation: location)
            if inside != continueTouchInside {
                continueTouchInside = inside
                setContinueButtonHighlighted(inside)
            }
            return
        }
        if restartTrackingTouch {
            let inside = restartButtonContains(sceneLocation: location)
            if inside != restartTouchInside {
                restartTouchInside = inside
                setRestartButtonHighlighted(inside)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else {
            resetTouchTracking()
            return
        }

        if continueTrackingTouch {
            let inside = continueButtonContains(sceneLocation: location)
            setContinueButtonHighlighted(false)
            continueTrackingTouch = false
            continueTouchInside = false
            if inside {
                triggerContinue()
            }
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
        setContinueButtonHighlighted(false)
        resetTouchTracking()
    }
}
#endif

#if os(macOS)
extension GameScene {

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        if isContinueButtonActive() && continueButtonContains(sceneLocation: location) {
            continueTrackingTouch = true
            continueTouchInside = true
            setContinueButtonHighlighted(true)
            touchStartLocation = nil
            return
        }
        if restartButtonContains(sceneLocation: location) {
            restartTrackingTouch = true
            restartTouchInside = true
            setRestartButtonHighlighted(true)
            touchStartLocation = nil
        } else {
            restartTrackingTouch = false
            restartTouchInside = false
            if store?.status == .playing {
                touchStartLocation = location
            } else {
                touchStartLocation = nil
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = event.location(in: self)
        if continueTrackingTouch {
            let inside = continueButtonContains(sceneLocation: location)
            if inside != continueTouchInside {
                continueTouchInside = inside
                setContinueButtonHighlighted(inside)
            }
            return
        }
        if restartTrackingTouch {
            let inside = restartButtonContains(sceneLocation: location)
            if inside != restartTouchInside {
                restartTouchInside = inside
                setRestartButtonHighlighted(inside)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        let location = event.location(in: self)
        if continueTrackingTouch {
            let inside = continueButtonContains(sceneLocation: location)
            setContinueButtonHighlighted(false)
            continueTrackingTouch = false
            continueTouchInside = false
            if inside {
                triggerContinue()
            }
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
        case 36:
            if isContinueButtonActive() {
                triggerContinue()
            } else {
                super.keyDown(with: event)
            }
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
        continueTrackingTouch = false
        continueTouchInside = false
        setContinueButtonHighlighted(false)
    }
}
