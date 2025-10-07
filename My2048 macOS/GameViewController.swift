//
//  GameViewController.swift
//  My2048 macOS
//
//  Created by Jiayi on 10/7/25.
//

import Cocoa
import SpriteKit

class GameViewController: NSViewController {

    private let store = GameStore()
    private var gameScene: GameScene?

    override func viewDidLoad() {
        super.viewDidLoad()

        let skView = self.view as! SKView
        let scene = GameScene.makeScene(size: skView.bounds.size, store: store)
        gameScene = scene
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if let window = view.window, let scene = gameScene {
            window.makeFirstResponder(scene)
        }
    }

}
