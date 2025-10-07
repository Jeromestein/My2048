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
    }

    private var layout: Layout?
    private let boardBackground = SKShapeNode()
    private let tileLayer = SKNode()
    private var tileSprites: [UUID: TileSprite] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private var touchStartLocation: CGPoint?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
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

    private func updateLayout() {
        guard let store = store else { return }
        let boardDimension = CGFloat(store.board.size)
        guard boardDimension > 0 else { return }

        let availableLength = min(size.width, size.height) * 0.88
        guard availableLength > 0 else { return }

        let spacing = max(availableLength * 0.04, 8)
        let tileSize = (availableLength - spacing * (boardDimension + 1)) / boardDimension
        guard tileSize > 0 else { return }

        layout = Layout(boardSize: availableLength, tileSize: tileSize, spacing: spacing)

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
        boardBackground.position = .zero

        updateGridBackground()
    }

    private func updateGridBackground() {
        guard let layout = layout, let store = store else { return }

        boardBackground.removeAllChildren()
        for row in 0..<store.board.size {
            for column in 0..<store.board.size {
                let placeholder = SKShapeNode(rectOf: CGSize(width: layout.tileSize, height: layout.tileSize), cornerRadius: 12)
                placeholder.fillColor = SKColor(red: 0.80, green: 0.75, blue: 0.71, alpha: 1.0)
                placeholder.strokeColor = .clear
                placeholder.position = positionFor(row: row, column: column, layout: layout)
                boardBackground.addChild(placeholder)
            }
        }
    }

    private func syncBoard(animated: Bool) {
        guard let store = store, let layout = layout else { return }

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

    private func positionFor(row: Int, column: Int, layout: Layout) -> CGPoint {
        guard let dimension = store?.board.size else { return .zero }
        let origin = -layout.boardSize / 2 + layout.spacing + layout.tileSize / 2
        let x = origin + CGFloat(column) * (layout.tileSize + layout.spacing)
        let y = origin + CGFloat(dimension - 1 - row) * (layout.tileSize + layout.spacing)
        return CGPoint(x: x, y: y)
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
        return value <= 4 ? SKColor(red: 0.47, green: 0.43, blue: 0.40, alpha: 1.0) : .white
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
}

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartLocation = touches.first?.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = touchStartLocation, let location = touches.first?.location(in: self) else {
            touchStartLocation = nil
            return
        }
        let delta = CGPoint(x: location.x - start.x, y: location.y - start.y)
        handleSwipe(delta: delta)
        touchStartLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartLocation = nil
    }
}
#endif

#if os(macOS)
extension GameScene {

    override func mouseDown(with event: NSEvent) {
        touchStartLocation = event.location(in: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = touchStartLocation else { return }
        let delta = CGPoint(x: event.location(in: self).x - start.x, y: event.location(in: self).y - start.y)
        handleSwipe(delta: delta)
        touchStartLocation = nil
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: store?.move(.left)
        case 124: store?.move(.right)
        case 125: store?.move(.down)
        case 126: store?.move(.up)
        default: super.keyDown(with: event)
        }
    }
}
#endif

private extension GameScene {
    func handleSwipe(delta: CGPoint) {
        guard let store = store else { return }
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
}
